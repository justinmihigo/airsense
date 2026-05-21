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


@app.get("/forecast")
def forecast_pm25(steps: int = 24):
    """Return a multi-step PM2.5 forecast using the saved SARIMA model.

    - steps: number of future observations to forecast (default 24)
    - Each observation corresponds to one reading interval (~20 seconds in the dataset)
    """
    forecaster: SarimaForecaster | None = _models.get("sarima_pm25")
    if forecaster is None:
        raise HTTPException(
            status_code=503,
            detail="SARIMA model not loaded. Run the forecasting notebook or POST /train first.",
        )
    if steps < 1 or steps > 1000:
        raise HTTPException(status_code=422, detail="steps must be between 1 and 1000.")

    fc_df = forecaster.predict(steps=steps)
    return {
        "target": "PM25",
        "steps": steps,
        "unit": "µg/m³",
        "forecast": fc_df.to_dict(orient="records"),
    }


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
    joblib.dump(feat_map, MODELS_DIR / "feature_names.joblib")

    _load_models()  # refresh registry

    return {
        "status": "trained",
        "regression_models": list(reg_models.keys()),
        "classification_models": list(clf_models.keys()),
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
