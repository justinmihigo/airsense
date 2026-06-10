"""
AirSense ML API — FastAPI server exposing AQI prediction, classification,
and recommendations on port 5000.

Endpoints:
  GET  /health
  POST /recommend          — rule-based recommendations (always available)
  POST /predict/aqi        — numeric AQI (formula; regression model if trained)
  POST /classify/category  — AQI category label (formula; classifier if trained)
  POST /train              — train and save all models (slow, background-safe)
"""

from __future__ import annotations

import sys
from pathlib import Path

# Allow imports from ml/src without installing the package
sys.path.insert(0, str(Path(__file__).parent))

from contextlib import asynccontextmanager
from typing import Optional

import joblib
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from src.data.preprocessor import aqi_category, overall_aqi, aqi_from_pm25, aqi_from_pm10
from src.recommendations.engine import recommend
from src.models.forecasting import SarimaForecaster  # required for joblib deserialization

MODELS_DIR = Path(__file__).parent / "models"
DATA_PATH = Path(__file__).parent / "Air-Quality-Dataset.csv"

# ---------------------------------------------------------------------------
# Model registry — loaded lazily at startup if .joblib files exist
# ---------------------------------------------------------------------------

_models: dict[str, object] = {}
_feature_names: dict[str, list[str]] = {}  # model_stem -> feature column list


def _load_models() -> None:
    if not MODELS_DIR.exists():
        return
    for path in MODELS_DIR.glob("*.joblib"):
        _models[path.stem] = joblib.load(path)
    feat_path = MODELS_DIR / "feature_names.joblib"
    if feat_path.exists():
        _feature_names.update(joblib.load(feat_path))
    if _models:
        print(f"[startup] Loaded {len(_models)} model(s): {list(_models)}")
    else:
        print("[startup] No trained models found in models/. Use POST /train to train.")


@asynccontextmanager
async def lifespan(app: FastAPI):
    _load_models()
    yield


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(
    title="AirSense ML API",
    version="1.0.0",
    description="AQI prediction, classification, and health recommendations.",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

class SensorReading(BaseModel):
    pm25: Optional[float] = Field(None, description="PM2.5 concentration (µg/m³)")
    pm10: Optional[float] = Field(None, description="PM10 concentration (µg/m³)")
    co2: Optional[float] = Field(None, description="CO2 concentration (ppm)")
    temperature: Optional[float] = Field(None, description="Temperature (°C)")
    humidity: Optional[float] = Field(None, description="Relative humidity (%)")
    occupancy: Optional[int] = Field(None, ge=0, description="Number of people in the room")


class AQIPrediction(BaseModel):
    aqi: float
    category: str
    source: str  # "formula" or "model:<name>"


class CategoryPrediction(BaseModel):
    category: str
    source: str


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/health")
def health():
    return {
        "status": "ok",
        "models_loaded": list(_models.keys()),
        "dataset_present": DATA_PATH.exists(),
    }


@app.post("/recommend")
def get_recommendations(reading: SensorReading):
    rec = recommend(
        pm25=reading.pm25,
        pm10=reading.pm10,
        co2=reading.co2,
        temperature=reading.temperature,
        humidity=reading.humidity,
        occupancy=reading.occupancy,
    )
    return rec.to_dict()


@app.post("/predict/aqi", response_model=AQIPrediction)
def predict_aqi(reading: SensorReading):
    # Try to use a trained regression model (XGBoost preferred)
    model_key = _pick_regression_model()
    if model_key:
        features = _build_simple_features(reading, model_key)
        if features is not None:
            import numpy as np
            arr = np.array([features])
            model = _models[model_key]
            pred = float(model.predict(arr)[0])
            return AQIPrediction(
                aqi=round(pred, 2),
                category=aqi_category(pred),
                source=f"model:{model_key}",
            )

    # Fallback: EPA piecewise formula
    aqi = _formula_aqi(reading)
    if aqi is None:
        raise HTTPException(
            status_code=422,
            detail="Provide at least pm25 or pm10 for AQI calculation.",
        )
    return AQIPrediction(
        aqi=round(aqi, 2),
        category=aqi_category(aqi),
        source="formula",
    )


@app.post("/classify/category", response_model=CategoryPrediction)
def classify_category(reading: SensorReading):
    model_key = _pick_classification_model()
    if model_key:
        features = _build_simple_features(reading, model_key)
        if features is not None:
            import numpy as np
            arr = np.array([features])
            model = _models[model_key]
            pred_idx = int(model.predict(arr)[0])
            from src.data.preprocessor import AQI_CATEGORIES
            label = AQI_CATEGORIES[pred_idx][2] if pred_idx < len(AQI_CATEGORIES) else "Unknown"
            return CategoryPrediction(category=label, source=f"model:{model_key}")

    aqi = _formula_aqi(reading)
    if aqi is None:
        raise HTTPException(
            status_code=422,
            detail="Provide at least pm25 or pm10 for category classification.",
        )
    return CategoryPrediction(category=aqi_category(aqi), source="formula")


class ForecastRequest(BaseModel):
    history: Optional[list[float]] = Field(
        None,
        description="Recent PM2.5 readings (oldest→newest). If provided, SARIMA is refit on this window so the forecast continues from current values.",
    )
    steps: int = Field(24, ge=1, le=1000)


MAX_HISTORY_POINTS = 500


def _forecast_from_history(history: list[float], steps: int) -> dict:
    """Refit a SARIMA on the supplied history and forecast `steps` ahead.

    Falls back to a naive last-value forecast with widening CIs if the fit fails
    (e.g. near-constant series).
    """
    import numpy as np
    import pandas as pd

    # Downsample if oversized — keeps the fit fast and behaves like uniform spacing.
    if len(history) > MAX_HISTORY_POINTS:
        stride = len(history) // MAX_HISTORY_POINTS
        history = history[::stride][-MAX_HISTORY_POINTS:]

    series = pd.Series([float(v) for v in history if v is not None])
    last = float(series.iloc[-1])

    # Prefer the saved model's order; otherwise a small, fast default.
    saved: SarimaForecaster | None = _models.get("sarima_pm25")
    order = getattr(saved, "order", None) or (1, 1, 1)
    seasonal_order = getattr(saved, "seasonal_order", None) or (0, 0, 0, 0)

    try:
        fc = SarimaForecaster(order=order, seasonal_order=seasonal_order)
        fc.fit(series, auto_order=False)
        fc_df = fc.predict(steps=steps)
        forecast_points = fc_df.to_dict(orient="records")
        source = f"sarima_refit:order={order}"
    except Exception as e:
        # Naive fallback: hold-last with linearly widening CI band from series std.
        std = float(series.std() or max(abs(last) * 0.05, 0.5))
        forecast_points = []
        for i in range(1, steps + 1):
            width = 1.96 * std * (1 + i / max(steps, 1))
            forecast_points.append({
                "mean": last,
                "lower_ci": max(0.0, last - width),
                "upper_ci": last + width,
            })
        source = f"naive_holdlast:{type(e).__name__}"

    return {
        "target": "PM25",
        "steps": steps,
        "unit": "µg/m³",
        "forecast": forecast_points,
        "history_used": len(series),
        "last_observed": last,
        "source": source,
    }


@app.post("/forecast")
def forecast_pm25_post(req: ForecastRequest):
    """Forecast PM2.5 using a SARIMA refit on the supplied recent history.

    The pre-trained model bundled with the API was fit on the static
    Air-Quality-Dataset and therefore predicts values from that distribution,
    not the live sensor's. Supplying `history` from InfluxDB lets the model
    continue from current observed values.
    """
    if req.history and len(req.history) >= 10:
        return _forecast_from_history(req.history, req.steps)

    forecaster: SarimaForecaster | None = _models.get("sarima_pm25")
    if forecaster is None:
        raise HTTPException(
            status_code=503,
            detail="No history supplied and no SARIMA model loaded. Pass `history` or run POST /train.",
        )
    fc_df = forecaster.predict(steps=req.steps)
    return {
        "target": "PM25",
        "steps": req.steps,
        "unit": "µg/m³",
        "forecast": fc_df.to_dict(orient="records"),
        "history_used": 0,
        "last_observed": None,
        "source": "sarima_pretrained",
    }


@app.get("/forecast")
def forecast_pm25(steps: int = 24):
    """Legacy GET — uses the pre-trained model. Prefer POST with `history`."""
    return forecast_pm25_post(ForecastRequest(history=None, steps=steps))


# ---------------------------------------------------------------------------
# Per-pollutant prediction, sensitivity analysis, feature importance
# ---------------------------------------------------------------------------

POLLUTANT_UNITS = {
    "PM25": "µg/m³", "PM10": "µg/m³", "CO2": "ppm",
    "TEMPERATURE": "°C", "HUMIDITY": "%",
}

# UI-friendly names map onto the model's column names (uppercase).
UI_TO_COL = {
    "pm25": "PM25", "pm10": "PM10", "co2": "CO2",
    "temperature": "TEMPERATURE", "humidity": "HUMIDITY", "occupancy": "OCCUPANCY",
}


class SensitivityRequest(BaseModel):
    reading: SensorReading
    vary: str = Field("occupancy", description="Variable to sweep: occupancy|pm25|pm10|co2|temperature|humidity")
    grid: Optional[list[float]] = Field(
        None,
        description="Values to test. Defaults to a reasonable range for the chosen variable.",
    )


DEFAULT_GRIDS: dict[str, list[float]] = {
    "occupancy":   [0, 1, 2, 3, 5, 8, 12, 20],
    "pm25":        [5, 12, 20, 35, 55, 90, 150, 250],
    "pm10":        [10, 30, 60, 100, 154, 254, 354, 500],
    "co2":         [400, 600, 800, 1000, 1500, 2000, 3000],
    "temperature": [15, 18, 20, 22, 24, 27, 30, 35],
    "humidity":    [20, 30, 40, 50, 60, 70, 80, 90],
}


@app.post("/predict/pollutants")
def predict_pollutants(reading: SensorReading):
    """Predict each pollutant's NEXT reading from the current sensor state.

    Returns a dict like {"pm25": {"value": 31.4, "unit": "µg/m³", "delta": +2.1}, ...}
    for every pollutant we have a trained next-step model for.
    """
    out: dict[str, dict] = {}
    current_vals = {
        "PM25": reading.pm25, "PM10": reading.pm10, "CO2": reading.co2,
        "TEMPERATURE": reading.temperature, "HUMIDITY": reading.humidity,
    }
    for pollutant in ["PM25", "PM10", "CO2", "TEMPERATURE", "HUMIDITY"]:
        key = f"{pollutant.lower()}_next_xgboost_reg"
        model = _models.get(key)
        if model is None:
            continue
        features = _build_simple_features(reading, key)
        if features is None:
            continue
        import numpy as np
        pred = float(model.predict(np.array([features]))[0])
        cur = current_vals.get(pollutant)
        out[pollutant.lower()] = {
            "value": round(pred, 2),
            "unit": POLLUTANT_UNITS.get(pollutant, ""),
            "delta": round(pred - cur, 2) if cur is not None else None,
            "current": cur,
        }
    if not out:
        raise HTTPException(
            status_code=503,
            detail="No per-pollutant models loaded. Run POST /train first.",
        )
    return {"predictions": out, "horizon": "next step"}


@app.post("/sensitivity")
def sensitivity(req: SensitivityRequest):
    """Sweep one variable and show how predicted AQI changes.

    Holds every other field at the supplied reading and varies `vary` across `grid`.
    Useful for "what happens if occupancy doubles?" type questions.
    """
    if req.vary not in UI_TO_COL:
        raise HTTPException(
            status_code=422,
            detail=f"vary must be one of: {list(UI_TO_COL)}",
        )

    model_key = _pick_regression_model()
    grid = req.grid if req.grid is not None else DEFAULT_GRIDS.get(req.vary, [])
    if not grid:
        raise HTTPException(status_code=422, detail="No grid supplied and no default available.")

    points: list[dict] = []
    base = req.reading.model_dump()

    for v in grid:
        modified = SensorReading(**{**base, req.vary: v})

        # Try the model first; fall back to formula so the sweep always works.
        aqi_val = None
        source = "formula"
        if model_key:
            features = _build_simple_features(modified, model_key)
            if features is not None:
                import numpy as np
                aqi_val = float(_models[model_key].predict(np.array([features]))[0])
                source = f"model:{model_key}"
        if aqi_val is None:
            aqi_val = _formula_aqi(modified)
        if aqi_val is None:
            continue

        points.append({
            "x": float(v),
            "aqi": round(float(aqi_val), 2),
            "category": aqi_category(aqi_val),
        })

    if not points:
        raise HTTPException(
            status_code=422,
            detail="Could not compute AQI for any grid point (need at least pm25 or pm10 in the reading).",
        )

    # Baseline = same reading, unchanged — gives the user a "where am I now" anchor.
    baseline_aqi = None
    if model_key:
        features = _build_simple_features(req.reading, model_key)
        if features is not None:
            import numpy as np
            baseline_aqi = float(_models[model_key].predict(np.array([features]))[0])
    if baseline_aqi is None:
        baseline_aqi = _formula_aqi(req.reading)

    return {
        "vary": req.vary,
        "source": source,
        "points": points,
        "baseline": {
            "value": base.get(req.vary),
            "aqi": round(baseline_aqi, 2) if baseline_aqi is not None else None,
        },
    }


@app.get("/feature_importance")
def feature_importance(model_key: str = "xgboost_reg", top: int = 15):
    """Return the most influential features for a tree-based model.

    Defaults to xgboost_reg. Pass model_key=random_forest_reg, xgboost_clf, etc.
    """
    model = _models.get(model_key)
    if model is None:
        raise HTTPException(
            status_code=404,
            detail=f"Model '{model_key}' not loaded. Loaded: {list(_models)}",
        )
    feat_cols = _feature_names.get(model_key)
    if not feat_cols:
        raise HTTPException(
            status_code=503,
            detail=f"No feature names saved for '{model_key}'. Re-run POST /train.",
        )

    # GridSearchCV wraps the real estimator under `best_estimator_`.
    est = getattr(model, "best_estimator_", model)

    import numpy as np
    if hasattr(est, "feature_importances_"):
        importances = np.array(est.feature_importances_, dtype=float)
        kind = "tree_gain"
    elif hasattr(est, "coef_"):
        coef = np.asarray(est.coef_, dtype=float)
        if coef.ndim > 1:
            coef = np.abs(coef).mean(axis=0)
        importances = np.abs(coef)
        kind = "abs_coef"
    else:
        raise HTTPException(
            status_code=422,
            detail=f"Model type {type(est).__name__} does not expose feature importances.",
        )

    pairs = sorted(
        zip(feat_cols, importances.tolist()),
        key=lambda kv: kv[1],
        reverse=True,
    )[:top]
    return {
        "model": model_key,
        "kind": kind,
        "top": [{"feature": f, "importance": round(v, 6)} for f, v in pairs],
    }


# ---------------------------------------------------------------------------


@app.post("/train")
def train_models():
    """Train all regression and classification models and save them to models/."""
    if not DATA_PATH.exists():
        raise HTTPException(
            status_code=404,
            detail=f"Dataset not found at {DATA_PATH}. Place Air-Quality-Dataset.csv in the ml/ folder.",
        )

    from src.data.loader import load_primary
    from src.data.preprocessor import full_pipeline
    from src.models.regression import train_all as train_reg
    from src.models.classification import train_all as train_clf

    df_raw = load_primary(DATA_PATH)
    df = full_pipeline(df_raw)

    reg_features = [c for c in df.columns if c not in
                    ("TIME", "AQI", "AQI_PM25", "AQI_PM10", "AQI_LABEL",
                     "AQI_IDX", "CO2_CAT", "PM25_CAT", "PM10_CAT",
                     "CO2_CAT_ENC", "PM25_CAT_ENC", "PM10_CAT_ENC", "AQI_LABEL_ENC")]
    clf_features = reg_features

    X_reg = df[reg_features].values
    y_reg = df["AQI"].values

    X_clf = df[clf_features].values
    y_clf = df["AQI_IDX"].values

    reg_models = train_reg(X_reg, y_reg, save=True)
    clf_models = train_clf(X_clf, y_clf, save=True)

    # Persist feature column list so inference can build the right vector
    feat_map: dict[str, list[str]] = {}
    for name in reg_models:
        stem = name.lower().replace(" ", "_").replace("(", "").replace(")", "").replace("=", "") + "_reg"
        feat_map[stem] = reg_features
    for name in clf_models:
        stem = name.lower().replace(" ", "_").replace("(", "").replace(")", "") + "_clf"
        feat_map[stem] = clf_features

    # -----------------------------------------------------------------------
    # Next-step per-pollutant models — predict each pollutant's NEXT reading.
    # XGBoost only; one model per pollutant is plenty for the UI.
    # -----------------------------------------------------------------------
    from src.models.regression import train_xgboost
    pollutant_models: dict[str, str] = {}
    for pollutant in ["PM25", "PM10", "CO2", "TEMPERATURE", "HUMIDITY"]:
        if pollutant not in df.columns:
            continue
        shifted = df[pollutant].shift(-1)
        valid = shifted.notna()
        y_next = shifted[valid].values
        X_next = df.loc[valid, reg_features].values
        model = train_xgboost(X_next, y_next)
        stem = f"{pollutant.lower()}_next_xgboost_reg"
        joblib.dump(model, MODELS_DIR / f"{stem}.joblib")
        feat_map[stem] = reg_features
        pollutant_models[pollutant.lower()] = stem

    joblib.dump(feat_map, MODELS_DIR / "feature_names.joblib")

    _load_models()  # refresh registry

    return {
        "status": "trained",
        "regression_models": list(reg_models.keys()),
        "classification_models": list(clf_models.keys()),
        "pollutant_models": pollutant_models,
        "models_dir": str(MODELS_DIR),
        "feature_count": len(reg_features),
    }


@app.post("/report")
def generate_report():
    """Run evaluation and write a Markdown report to reports/model_comparison_report.md."""
    if not DATA_PATH.exists():
        raise HTTPException(status_code=404, detail=f"Dataset not found at {DATA_PATH}.")

    reg_keys = [k for k in _models if k.endswith("_reg")]
    clf_keys = [k for k in _models if k.endswith("_clf")]
    if not reg_keys and not clf_keys:
        raise HTTPException(status_code=503, detail="No models loaded. Call POST /train first.")

    from src.data.loader import load_primary
    from src.data.preprocessor import full_pipeline, split
    from src.evaluation.metrics import regression_metrics, classification_metrics
    from src.evaluation.reporter import save_report

    df = full_pipeline(load_primary(DATA_PATH))
    _, _, test_df = split(df, test_size=0.2, val_size=0.1)

    y_reg_true = test_df["AQI"].values
    y_clf_true = test_df["AQI_IDX"].values

    reg_results: dict[str, dict] = {}
    for key in reg_keys:
        feat_cols = _feature_names.get(key)
        if feat_cols is None:
            continue
        y_pred = _models[key].predict(test_df[feat_cols].values)
        reg_results[key] = _serialize_metrics(regression_metrics(y_reg_true, y_pred))

    clf_results: dict[str, dict] = {}
    for key in clf_keys:
        feat_cols = _feature_names.get(key)
        if feat_cols is None:
            continue
        X = test_df[feat_cols].values
        model = _models[key]
        y_pred = model.predict(X)
        y_prob = None
        if hasattr(model, "predict_proba"):
            try:
                y_prob = model.predict_proba(X)
            except Exception:
                pass
        clf_results[key] = _serialize_metrics(
            classification_metrics(y_clf_true, y_pred, y_prob=y_prob)
        )

    report_path = save_report(reg_results, clf_results)
    return {"status": "ok", "report": str(report_path), "test_samples": len(test_df)}


@app.post("/evaluate")
def evaluate_models():
    """Evaluate all loaded models against the held-out test split (last 20%)."""
    if not DATA_PATH.exists():
        raise HTTPException(
            status_code=404,
            detail=f"Dataset not found at {DATA_PATH}.",
        )

    reg_keys = [k for k in _models if k.endswith("_reg")]
    clf_keys = [k for k in _models if k.endswith("_clf")]
    if not reg_keys and not clf_keys:
        raise HTTPException(
            status_code=503,
            detail="No models loaded. Call POST /train first.",
        )

    from src.data.loader import load_primary
    from src.data.preprocessor import full_pipeline, split
    from src.evaluation.metrics import regression_metrics, classification_metrics

    df = full_pipeline(load_primary(DATA_PATH))
    _, _, test_df = split(df, test_size=0.2, val_size=0.1)

    y_reg_true = test_df["AQI"].values
    y_clf_true = test_df["AQI_IDX"].values

    reg_results: dict[str, dict] = {}
    for key in reg_keys:
        feat_cols = _feature_names.get(key)
        if feat_cols is None:
            continue
        y_pred = _models[key].predict(test_df[feat_cols].values)
        reg_results[key] = _serialize_metrics(regression_metrics(y_reg_true, y_pred))

    clf_results: dict[str, dict] = {}
    for key in clf_keys:
        feat_cols = _feature_names.get(key)
        if feat_cols is None:
            continue
        X = test_df[feat_cols].values
        model = _models[key]
        y_pred = model.predict(X)
        y_prob = None
        if hasattr(model, "predict_proba"):
            try:
                y_prob = model.predict_proba(X)
            except Exception:
                pass
        clf_results[key] = _serialize_metrics(
            classification_metrics(y_clf_true, y_pred, y_prob=y_prob)
        )

    return {
        "test_samples": len(test_df),
        "regression": reg_results,
        "classification": clf_results,
        "best_regression": _best_by(reg_results, "RMSE", lower_is_better=True),
        "best_classification": _best_by(clf_results, "F1", lower_is_better=False),
    }


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _serialize_metrics(metrics: dict) -> dict:
    import numpy as np
    out = {}
    for k, v in metrics.items():
        if isinstance(v, np.ndarray):
            out[k] = v.tolist()
        elif isinstance(v, np.integer):
            out[k] = int(v)
        elif isinstance(v, np.floating):
            out[k] = float(v)
        else:
            out[k] = v
    return out


def _best_by(results: dict, metric: str, lower_is_better: bool) -> dict | None:
    if not results:
        return None
    candidates = {n: m[metric] for n, m in results.items() if m.get(metric) is not None}
    if not candidates:
        return None
    best = min(candidates, key=candidates.__getitem__) if lower_is_better \
           else max(candidates, key=candidates.__getitem__)
    return {"model": best, metric: candidates[best]}


def _formula_aqi(reading: SensorReading) -> float | None:
    if reading.pm25 is not None and reading.pm10 is not None:
        return overall_aqi(reading.pm25, reading.pm10)
    if reading.pm25 is not None:
        return aqi_from_pm25(reading.pm25)
    if reading.pm10 is not None:
        return aqi_from_pm10(reading.pm10)
    return None


def _build_simple_features(reading: SensorReading, model_key: str) -> list[float] | None:
    """Build a full feature vector matching the model's training columns.

    For lag and rolling features we don't have a history window, so we use
    the current sensor value as a steady-state approximation. Time features
    are derived from the current UTC timestamp.
    """
    import math
    import numpy as np
    from datetime import datetime, timezone

    feature_cols = _feature_names.get(model_key)
    if not feature_cols:
        # No metadata saved yet — fall back to formula
        return None

    pm25 = reading.pm25 or 0.0
    pm10 = reading.pm10 or 0.0
    co2 = reading.co2 or 0.0
    temp = reading.temperature or 20.0
    hum = reading.humidity or 50.0
    occupancy = float(reading.occupancy) if reading.occupancy is not None else 0.0

    now = datetime.now(timezone.utc)
    hour = now.hour
    dow = now.weekday()
    month = now.month

    # Steady-state approximations for derived features
    defaults: dict[str, float] = {
        "CO2": co2, "PM25": pm25, "PM10": pm10,
        "TEMPERATURE": temp, "HUMIDITY": hum, "OCCUPANCY": occupancy,
        "hour": float(hour), "day_of_week": float(dow), "month": float(month),
        "is_weekend": 1.0 if dow >= 5 else 0.0,
        "hour_sin": math.sin(2 * math.pi * hour / 24),
        "hour_cos": math.cos(2 * math.pi * hour / 24),
        "dow_sin": math.sin(2 * math.pi * dow / 7),
        "dow_cos": math.cos(2 * math.pi * dow / 7),
    }

    # Lag features — assume steady state (current value ≈ past value)
    for col, val in [("PM25", pm25), ("PM10", pm10), ("CO2", co2),
                     ("TEMPERATURE", temp), ("HUMIDITY", hum), ("OCCUPANCY", occupancy)]:
        for lag in [1, 2, 6, 12, 24]:
            defaults[f"{col}_lag{lag}"] = val

    # Rolling features — assume steady state (mean == current, std == 0)
    for col, val in [("PM25", pm25), ("PM10", pm10), ("CO2", co2),
                     ("TEMPERATURE", temp), ("HUMIDITY", hum), ("OCCUPANCY", occupancy)]:
        for w in [6, 24, 72]:
            defaults[f"{col}_roll{w}_mean"] = val
            defaults[f"{col}_roll{w}_std"] = 0.0

    return [defaults.get(col, 0.0) for col in feature_cols]


def _pick_regression_model() -> str | None:
    preference = ["xgboost_reg", "random_forest_reg", "ridge_regression_reg", "linear_regression_reg"]
    for key in preference:
        if key in _models:
            return key
    # Any regression model
    for key in _models:
        if key.endswith("_reg"):
            return key
    return None


def _pick_classification_model() -> str | None:
    preference = ["xgboost_clf", "random_forest_clf", "logistic_regression_clf"]
    for key in preference:
        if key in _models:
            return key
    for key in _models:
        if key.endswith("_clf"):
            return key
    return None


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    uvicorn.run("api:app", host="0.0.0.0", port=5000, reload=True)
