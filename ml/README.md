# AirSense ML Module

Machine learning pipeline for indoor air quality prediction, classification, forecasting, and health recommendations.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [How the ML Pipeline Works](#how-the-ml-pipeline-works)
   - [Step 1 — Training (notebooks → .joblib files)](#step-1--training)
   - [Step 2 — Loading models at startup](#step-2--loading-models-at-startup)
   - [Step 3 — AQI Prediction at inference](#step-3--aqi-prediction-at-inference)
   - [Step 4 — AQI Classification at inference](#step-4--aqi-classification-at-inference)
   - [Step 5 — Recommendations (rule engine)](#step-5--recommendations-rule-engine)
   - [Step 6 — Forecasting (SARIMA)](#step-6--forecasting-sarima)
3. [Feature Engineering Explained](#feature-engineering-explained)
4. [Manual Testing Guide](#manual-testing-guide)
   - [Option A — curl](#option-a--curl)
   - [Option B — Python script](#option-b--python-script)
   - [Option C — Jupyter notebook cells](#option-c--jupyter-notebook-cells)
   - [Option D — Frontend UI](#option-d--frontend-ui)
5. [Project Structure](#project-structure)
6. [Models Reference](#models-reference)
7. [AQI Standards](#aqi-standards)

---

## Quick Start

```bash
cd ml/
python3 -m venv .venv
source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# Start the ML API
python api.py                  # → http://localhost:5000
```

To train (or re-train) models, open the notebooks in order:

```bash
jupyter notebook notebooks/
# Run: 01 → 02 → 03 → 04
```

---

## How the ML Pipeline Works

The pipeline has three independent concerns: **regression** (predict a numeric AQI score), **classification** (predict an AQI category label), and **forecasting** (predict future PM2.5 values). Recommendations sit on top of these and do not require trained models — they use rule-based thresholds and work from day one.

```
Sensor reading (pm25, pm10, co2, temp, humidity, occupancy)
        │
        ├──► Feature vector builder (_build_simple_features)
        │           │
        │           ├──► xgboost_reg.joblib  ──►  AQI score (float)
        │           ├──► xgboost_clf.joblib  ──►  AQI category label
        │           └──► (fallback: EPA formula if no model loaded)
        │
        ├──► Recommendations engine (engine.py)
        │           │
        │           └──► AQI → level → health / activity / ventilation advice
        │
        └──► sarima_pm25.joblib
                    │
                    └──► next N steps PM2.5 forecast + 95% CI
```

---

### Step 1 — Training

Training happens entirely inside the Jupyter notebooks. Each notebook saves `.joblib` files to `ml/models/`.

| Notebook | What it trains | Output files |
|---|---|---|
| `01_EDA_and_Preprocessing.ipynb` | Nothing — data exploration only | — |
| `02_Model_Comparison.ipynb` | 8 regression + 4 classification models | `*_reg.joblib`, `*_clf.joblib`, `feature_names.joblib` |
| `03_Forecasting.ipynb` | SARIMA | `sarima_pm25.joblib` |
| `04_Recommendations.ipynb` | Nothing — rule engine only | — |

After running notebook 02 and 03, the `models/` directory contains:

```
models/
├── feature_names.joblib               ← maps model name → list of feature columns
├── linear_regression_reg.joblib
├── ridge_regression_reg.joblib
├── lasso_regression_reg.joblib
├── polynomial_regression_deg2_reg.joblib
├── polynomial_regression_deg3_reg.joblib
├── random_forest_reg.joblib
├── svr_rbf_reg.joblib
├── xgboost_reg.joblib                 ← preferred for AQI regression
├── logistic_regression_clf.joblib
├── random_forest_clf.joblib
├── svc_rbf_clf.joblib
├── xgboost_clf.joblib                 ← preferred for AQI classification
└── sarima_pm25.joblib                 ← SarimaForecaster object
```

What gets serialised with `joblib.dump()`:

- **scikit-learn models**: the fitted estimator or `GridSearchCV` wrapper. Calling `.predict(X)` on the loaded object runs inference immediately.
- **XGBoost models**: the fitted `XGBRegressor` / `XGBClassifier`. Same `.predict(X)` interface.
- **SARIMA**: the entire `SarimaForecaster` instance including the fitted statsmodels `_result` object.
- **`feature_names.joblib`**: a plain Python `dict[str, list[str]]` mapping each model filename stem to the ordered list of feature column names used during training. This is critical — the inference code uses it to build vectors in the exact same column order as training.

---

### Step 2 — Loading models at startup

When you start `python api.py`, the `lifespan` context manager runs `_load_models()`:

```python
# api.py — simplified
for path in MODELS_DIR.glob("*.joblib"):
    _models[path.stem] = joblib.load(path)
```

This fills the global `_models` dict, e.g.:

```python
_models = {
    "xgboost_reg":       <XGBRegressor ...>,
    "xgboost_clf":       <XGBClassifier ...>,
    "sarima_pm25":       <SarimaForecaster ...>,
    "random_forest_reg": <GridSearchCV best_estimator_=RandomForestRegressor ...>,
    # ... all 13 models
}
```

The startup log tells you what loaded:

```
[startup] Loaded 13 model(s): ['xgboost_reg', 'xgboost_clf', 'sarima_pm25', ...]
```

If `models/` is empty or missing, the API still starts — it falls back to the EPA formula for AQI and returns a `503` error for the forecast endpoint.

---

### Step 3 — AQI Prediction at inference

**Endpoint:** `POST /predict/aqi`

**3a. Try the ML model first**

The API calls `_pick_regression_model()` which returns the best available model by preference:

```
xgboost_reg  →  random_forest_reg  →  ridge_regression_reg  →  linear_regression_reg  →  any *_reg
```

If a model is found, `_build_simple_features(reading, model_key)` constructs a 1D feature vector that matches exactly the columns the model was trained on (retrieved from `feature_names.joblib`). The vector is passed to the model:

```python
arr = np.array([features])        # shape (1, n_features)
pred = float(model.predict(arr)[0])
# → AQI as a float, e.g. 47.3
```

**3b. EPA formula fallback**

If no trained model is loaded, the AQI is computed analytically using the EPA 2024 piecewise linear formula:

```
AQI = (I_hi - I_lo) / (C_hi - C_lo) × (C - C_lo) + I_lo
```

Applied separately for PM2.5 and PM10. The higher of the two is the final AQI (`max(aqi_pm25, aqi_pm10)`).

**Response:**

```json
{
  "aqi": 47.3,
  "category": "Good",
  "source": "model:xgboost_reg"
}
```

The `source` field tells you whether a trained model or the formula was used. If you see `"source": "formula"`, the models are not loaded — check the startup log.

---

### Step 4 — AQI Classification at inference

**Endpoint:** `POST /classify/category`

Same flow as regression but uses a classifier. The model outputs an integer index (0–5) which is mapped back to a category label:

```python
pred_idx = int(model.predict(arr)[0])   # → e.g. 1
label = AQI_CATEGORIES[pred_idx][2]     # → "Moderate"
```

Category index mapping:

| Index | Label |
|---|---|
| 0 | Good |
| 1 | Moderate |
| 2 | Unhealthy for Sensitive Groups |
| 3 | Unhealthy |
| 4 | Very Unhealthy |
| 5 | Hazardous |

---

### Step 5 — Recommendations (rule engine)

**Endpoint:** `POST /recommend`

This endpoint does **not** call any trained model. It is entirely rule-based using WHO 2021 and EPA 2024 thresholds. It always works, even with no `.joblib` files present.

The flow inside `src/recommendations/engine.py`:

```
1. Compute AQI from pm25/pm10 if not already known   (EPA piecewise formula)
2. Determine level + hex color from AQI value         (AQI_LEVELS lookup table)
3. pm25  → _pm25_advice(pm25)   → health, activity, ventilation lists
4. pm10  → _pm10_advice(pm10)   → appended to health
5. co2   → _co2_advice(co2)     → appended to health + ventilation
6. temp+humidity → _temp_humidity_advice() → appended to health
7. occupancy → co2_per_person check        → appended to health + ventilation
8. Fill default "all clear" text if any list is still empty
```

Key thresholds used:

| Sensor | Threshold | What triggers |
|---|---|---|
| PM2.5 | > 15 µg/m³ (WHO 24h) | Health warning for sensitive groups |
| PM2.5 | > 35.5 µg/m³ (EPA USG) | Sensor alert + activity restriction |
| PM2.5 | > 55.5 µg/m³ | Everyone affected — air purifier max |
| CO2 | > 800 ppm | Mild cognitive impairment warning |
| CO2 | > 1000 ppm | ASHRAE limit — open windows advice |
| CO2 | > 2000 ppm | Critical — evacuate advice |
| CO2 / occupancy | > 250 ppm/person | Increase fresh air supply |
| Temperature | > 32°C AND Humidity > 70% | Heat-stress warning |
| Humidity | > 80% | Mold/dust-mite risk |

**Response shape:**

```json
{
  "aqi": 82.4,
  "level": "Moderate",
  "color": "#FFFF00",
  "health_advice": ["PM2.5 (12.3 µg/m³) exceeds WHO guideline..."],
  "activity_advice": ["Sensitive groups should reduce outdoor exertion."],
  "ventilation_advice": ["Consider running HEPA air purifier."],
  "sensor_alerts": []
}
```

---

### Step 6 — Forecasting (SARIMA)

**Endpoint:** `GET /forecast?steps=48`

The SARIMA model is loaded from `sarima_pm25.joblib`. This file contains a `SarimaForecaster` instance with a fitted `statsmodels.SARIMAX` result stored as `self._result`.

When you call `GET /forecast?steps=48`:

```python
forecaster = _models["sarima_pm25"]     # SarimaForecaster
fc_df = forecaster.predict(steps=48)    # calls statsmodels internally
```

Inside `SarimaForecaster.predict()`:

```python
fc = self._result.get_forecast(steps=steps)
summary = fc.summary_frame(alpha=0.05)  # 95% confidence interval
return pd.DataFrame({
    "mean":      summary["mean"].values,
    "lower_ci":  summary["mean_ci_lower"].values,
    "upper_ci":  summary["mean_ci_upper"].values,
})
```

Each row is one future time step. The model was trained on PM2.5 readings at ~20-second intervals, so:
- Step 1 ≈ 20 seconds from now
- Step 48 ≈ 16 minutes from now
- Step 180 ≈ 1 hour from now

The ARIMA `(p, d, q)` order was selected automatically during training by testing all combinations of p∈{0,1,2}, d∈{0,1}, q∈{0,1,2} and picking the one with the lowest AIC score.

**Response:**

```json
{
  "target": "PM25",
  "steps": 48,
  "unit": "µg/m³",
  "forecast": [
    { "mean": 12.4, "lower_ci": 10.1, "upper_ci": 14.7 },
    { "mean": 12.5, "lower_ci": 9.8,  "upper_ci": 15.2 },
    ...
  ]
}
```

---

## Feature Engineering Explained

When a sensor reading arrives at inference time, the model expects the same feature columns it was trained on. The `_build_simple_features()` function in `api.py` constructs this vector from a single snapshot.

**Base sensor features:**

| Feature | Maps to |
|---|---|
| `CO2` | gas_ppm input |
| `PM25` | pm25 input |
| `PM10` | pm10 input |
| `TEMPERATURE` | temperature input |
| `HUMIDITY` | humidity input |
| `OCCUPANCY` | occupancy input (defaults to 0) |

**Time features** (derived from current UTC time at request time):

| Feature | Description |
|---|---|
| `hour` | 0–23 |
| `day_of_week` | 0 = Monday, 6 = Sunday |
| `month` | 1–12 |
| `is_weekend` | 1 if Sat/Sun, else 0 |
| `hour_sin`, `hour_cos` | Cyclic encoding — hour 23 and hour 0 are close |
| `dow_sin`, `dow_cos` | Cyclic encoding of day of week |

**Lag features** — what the sensor read at t-1, t-2, t-6, t-12, t-24:

We only have a single snapshot at inference time, not a history buffer. The approximation used is **steady state**: the sensor reading now is assumed to be the same as it was at every past step. This is an approximation that works reasonably well for slowly varying indoor air quality.

```
PM25_lag1  = pm25  (current value)
PM25_lag2  = pm25
PM25_lag6  = pm25
PM25_lag12 = pm25
PM25_lag24 = pm25
```

Same for PM10, CO2, TEMPERATURE, HUMIDITY, OCCUPANCY. Total: 6 sensors × 5 lags = **30 lag features**.

**Rolling features** — mean and std over 6, 24, 72-step windows:

Same steady-state approximation: rolling mean equals the current value, rolling std equals 0 (no variation assumed).

```
PM25_roll6_mean  = pm25
PM25_roll6_std   = 0.0
PM25_roll24_mean = pm25
PM25_roll24_std  = 0.0
PM25_roll72_mean = pm25
PM25_roll72_std  = 0.0
```

Total: 6 sensors × 3 windows × 2 stats = **36 rolling features**.

**Total: ~80 features** (6 base + 8 time + 30 lag + 36 rolling)

The exact ordered list is stored in `models/feature_names.joblib` and read back at inference time so the vector always matches training order.

---

## Manual Testing Guide

Make sure the ML API is running:

```bash
cd ml/
source .venv/bin/activate
python api.py
# Expected: [startup] Loaded 13 model(s): ['xgboost_reg', 'sarima_pm25', ...]
```

---

### Option A — curl

**Health check — see which models are loaded:**

```bash
curl http://localhost:5000/health
```

```json
{
  "status": "ok",
  "models_loaded": ["xgboost_reg", "xgboost_clf", "sarima_pm25", ...],
  "dataset_present": true
}
```

**AQI prediction (numeric score):**

```bash
curl -X POST http://localhost:5000/predict/aqi \
  -H "Content-Type: application/json" \
  -d '{"pm25": 22.5, "pm10": 35.0, "co2": 850, "temperature": 24.0, "humidity": 65.0}'
```

```json
{"aqi": 74.2, "category": "Moderate", "source": "model:xgboost_reg"}
```

**AQI category (label only):**

```bash
curl -X POST http://localhost:5000/classify/category \
  -H "Content-Type: application/json" \
  -d '{"pm25": 22.5, "pm10": 35.0, "co2": 850}'
```

```json
{"category": "Moderate", "source": "model:xgboost_clf"}
```

**Recommendations — crowded room with high CO2:**

```bash
curl -X POST http://localhost:5000/recommend \
  -H "Content-Type: application/json" \
  -d '{
    "pm25": 22.5,
    "pm10": 35.0,
    "co2": 1100,
    "temperature": 28.0,
    "humidity": 72.0,
    "occupancy": 5
  }'
```

```json
{
  "aqi": 74.2,
  "level": "Moderate",
  "color": "#FFFF00",
  "health_advice": [
    "PM2.5 (22.5 µg/m³) exceeds WHO guideline...",
    "CO2 High (1100 ppm): Above ASHRAE comfort limit..."
  ],
  "activity_advice": ["Sensitive groups should reduce prolonged outdoor exertion."],
  "ventilation_advice": [
    "Open windows or increase ventilation rate.",
    "5 people in room: monitor CO2 levels..."
  ],
  "sensor_alerts": ["CO2 alert: 1100 ppm"]
}
```

**Recommendations — clean air scenario:**

```bash
curl -X POST http://localhost:5000/recommend \
  -H "Content-Type: application/json" \
  -d '{"pm25": 3.0, "pm10": 10.0, "co2": 420, "temperature": 22.0, "humidity": 50.0}'
```

Should return `level: "Good"` with all-clear advice and no sensor alerts.

**PM2.5 forecast — next 24 steps (~8 minutes):**

```bash
curl "http://localhost:5000/forecast?steps=24"
```

```json
{
  "target": "PM25",
  "steps": 24,
  "unit": "µg/m³",
  "forecast": [
    {"mean": 12.4, "lower_ci": 9.8,  "upper_ci": 15.0},
    {"mean": 12.5, "lower_ci": 9.6,  "upper_ci": 15.4},
    ...
  ]
}
```

**Test the EPA formula fallback** (temporarily hide the trained models):

```bash
mkdir -p models/_backup
mv models/xgboost_reg.joblib models/_backup/
mv models/random_forest_reg.joblib models/_backup/

# Restart the API, then:
curl -X POST http://localhost:5000/predict/aqi \
  -H "Content-Type: application/json" \
  -d '{"pm25": 22.5, "pm10": 35.0}'
# → "source": "formula"  (EPA computation, no ML model used)

# Restore:
mv models/_backup/*.joblib models/
```

---

### Option B — Python script

Save as `ml/test_manual.py` and run it with the venv active:

```python
"""Manual test script for the AirSense ML API."""
import requests

BASE = "http://localhost:5000"

SCENARIOS = [
    {
        "name": "Clean indoor air",
        "body": {"pm25": 3.0, "pm10": 10.0, "co2": 420,
                 "temperature": 22.0, "humidity": 50.0, "occupancy": 1},
    },
    {
        "name": "Moderate — crowded room",
        "body": {"pm25": 22.5, "pm10": 35.0, "co2": 1100,
                 "temperature": 26.0, "humidity": 65.0, "occupancy": 8},
    },
    {
        "name": "Unhealthy — high PM2.5",
        "body": {"pm25": 65.0, "pm10": 90.0, "co2": 800,
                 "temperature": 30.0, "humidity": 75.0, "occupancy": 2},
    },
]

# Health check
h = requests.get(f"{BASE}/health").json()
print(f"Models loaded: {h['models_loaded']}\n")

for s in SCENARIOS:
    print(f"{'='*55}")
    print(f"Scenario: {s['name']}")
    body = s["body"]

    aqi  = requests.post(f"{BASE}/predict/aqi",        json=body).json()
    clf  = requests.post(f"{BASE}/classify/category",  json=body).json()
    rec  = requests.post(f"{BASE}/recommend",          json=body).json()

    print(f"  AQI (model) : {aqi['aqi']:.1f}  [{aqi['category']}]  via {aqi['source']}")
    print(f"  Category    : {clf['category']}  via {clf['source']}")
    print(f"  AQI (rules) : {rec['aqi']:.1f}  level={rec['level']}")
    print(f"  Health      : {rec['health_advice'][0][:75]}...")
    print(f"  Ventilation : {rec['ventilation_advice'][0][:75]}...")
    if rec["sensor_alerts"]:
        print(f"  ALERTS      : {rec['sensor_alerts']}")

# Forecast
print(f"\n{'='*55}")
print("PM2.5 Forecast (next 12 steps):")
r = requests.get(f"{BASE}/forecast", params={"steps": 12})
if r.status_code == 200:
    for i, pt in enumerate(r.json()["forecast"], 1):
        bar = "█" * max(1, int(pt["mean"] / 2))
        print(f"  Step {i:2d}: {pt['mean']:5.1f} µg/m³  CI [{pt['lower_ci']:.1f}–{pt['upper_ci']:.1f}]  {bar}")
else:
    print(f"  {r.status_code}: {r.json()['detail']}")
```

```bash
cd ml/
source .venv/bin/activate
python test_manual.py
```

---

### Option C — Jupyter notebook cells

Open any notebook (or a new one) and run these cells directly without HTTP:

```python
# Cell 1 — import the rule engine directly
import sys; sys.path.insert(0, "..")   # only needed if running from notebooks/

from src.recommendations.engine import recommend

rec = recommend(
    pm25=22.5,
    pm10=35.0,
    co2=1100,
    temperature=26.0,
    humidity=65.0,
    occupancy=5,
)
print(f"AQI={rec.aqi:.1f}  Level={rec.level}  Color={rec.color}")
for a in rec.health_advice:
    print(f"  Health: {a}")
for a in rec.ventilation_advice:
    print(f"  Ventil: {a}")
```

```python
# Cell 2 — run the SARIMA forecaster directly
import joblib
forecaster = joblib.load("../models/sarima_pm25.joblib")
fc_df = forecaster.predict(steps=24)
print(fc_df.to_string())
```

```python
# Cell 3 — run XGBoost regression directly (no API needed)
import math, numpy as np, joblib
from datetime import datetime, timezone

model = joblib.load("../models/xgboost_reg.joblib")
feature_names = joblib.load("../models/feature_names.joblib")

pm25, pm10, co2, temp, hum, occ = 22.5, 35.0, 1100.0, 26.0, 65.0, 5.0
now = datetime.now(timezone.utc)
hour, dow, month = now.hour, now.weekday(), now.month

d: dict = {
    "CO2": co2, "PM25": pm25, "PM10": pm10,
    "TEMPERATURE": temp, "HUMIDITY": hum, "OCCUPANCY": occ,
    "hour": float(hour), "day_of_week": float(dow), "month": float(month),
    "is_weekend": 1.0 if dow >= 5 else 0.0,
    "hour_sin": math.sin(2 * math.pi * hour / 24),
    "hour_cos": math.cos(2 * math.pi * hour / 24),
    "dow_sin": math.sin(2 * math.pi * dow / 7),
    "dow_cos": math.cos(2 * math.pi * dow / 7),
}
for col, val in [("PM25", pm25), ("PM10", pm10), ("CO2", co2),
                 ("TEMPERATURE", temp), ("HUMIDITY", hum), ("OCCUPANCY", occ)]:
    for lag in [1, 2, 6, 12, 24]:
        d[f"{col}_lag{lag}"] = val
    for w in [6, 24, 72]:
        d[f"{col}_roll{w}_mean"] = val
        d[f"{col}_roll{w}_std"] = 0.0

cols = feature_names["xgboost_reg"]
X = np.array([[d.get(c, 0.0) for c in cols]])
print(f"XGBoost predicted AQI = {float(model.predict(X)[0]):.2f}")
print(f"Feature vector length  = {len(cols)}")
```

---

### Option D — Frontend UI

Start all three services:

```bash
# Terminal 1 — ML API
cd ml/ && source .venv/bin/activate && python api.py

# Terminal 2 — Backend (proxies ML calls with auth)
cd backend/ && source .venv/bin/activate && uvicorn app.main:app --reload

# Terminal 3 — Frontend
cd frontend/ && npm run dev
```

Navigate to `http://localhost:5173` → log in → open **Analytics**.

- The **AI Insights** panel auto-fetches on page load using the latest InfluxDB values.
- Adjust the **People in room** counter and click **Get Insights** to see occupancy-aware ventilation recommendations.
- The **PM2.5 Forecast** chart shows 48 steps with the amber CI band.
- The **source chip** (e.g. `Model: xgboost reg`) tells you whether the ML model or the EPA formula was used.
- If the ML API is offline the panel shows a yellow warning with the start command.

---

## Project Structure

```
ml/
├── data/
│   └── raw/                        # Air-Quality-Dataset.csv + downloaded datasets
├── models/                         # saved .joblib files after training
│   ├── feature_names.joblib        # dict: model_stem → feature column list
│   ├── xgboost_reg.joblib
│   ├── xgboost_clf.joblib
│   ├── sarima_pm25.joblib
│   └── ...
├── notebooks/
│   ├── 01_EDA_and_Preprocessing.ipynb
│   ├── 02_Model_Comparison.ipynb   ← trains regression + classification
│   ├── 03_Forecasting.ipynb        ← trains SARIMA
│   └── 04_Recommendations.ipynb   ← demonstrates rule engine
├── reports/
│   └── model_comparison_report.md  # auto-generated by POST /report
├── src/
│   ├── data/
│   │   ├── loader.py               # load_primary(), load_beijing(), load_openaq()
│   │   └── preprocessor.py        # AQI formula, feature engineering, splits
│   ├── evaluation/
│   │   ├── metrics.py
│   │   └── reporter.py
│   ├── models/
│   │   ├── regression.py           # 8 regression model trainers
│   │   ├── classification.py       # 4 classification model trainers
│   │   └── forecasting.py         # SarimaForecaster, ProphetForecaster
│   └── recommendations/
│       └── engine.py               # recommend(), batch_recommend()
├── api.py                          # FastAPI app on port 5000
└── requirements.txt
```

---

## Models Reference

### Regression (target: AQI numeric, 0–500)

| File | Algorithm | Tuning strategy |
|---|---|---|
| `linear_regression_reg.joblib` | OLS Linear | — |
| `ridge_regression_reg.joblib` | Ridge L2 | GridSearchCV α ∈ {0.01…100} |
| `lasso_regression_reg.joblib` | Lasso L1 | GridSearchCV α ∈ {0.001…10} |
| `polynomial_regression_deg2_reg.joblib` | Poly(2) + Ridge | degree=2 |
| `polynomial_regression_deg3_reg.joblib` | Poly(3) + Ridge | degree=3 |
| `random_forest_reg.joblib` | Random Forest | GridSearchCV depth/estimators |
| `svr_rbf_reg.joblib` | SVR RBF kernel | GridSearchCV C/ε |
| `xgboost_reg.joblib` | XGBoost | 300 trees, lr=0.05, subsample=0.8 |

Cross-validation uses `TimeSeriesSplit(n_splits=5)` to prevent data leakage (time-series data must not be shuffled).

### Classification (target: AQI category, 0–5)

| File | Algorithm | Tuning strategy |
|---|---|---|
| `logistic_regression_clf.joblib` | Logistic Regression | GridSearchCV C |
| `random_forest_clf.joblib` | Random Forest (balanced) | GridSearchCV depth/estimators |
| `svc_rbf_clf.joblib` | SVC RBF | GridSearchCV C/kernel |
| `xgboost_clf.joblib` | XGBoost | multi:softprob, 300 trees |

### Forecasting

| File | Algorithm | Training notes |
|---|---|---|
| `sarima_pm25.joblib` | SARIMA (auto AIC order search) | Trained on PM2.5 time series, ~20s intervals |

---

## AQI Standards

**EPA 2024 PM2.5 breakpoints** (used for AQI computation):

| C_lo µg/m³ | C_hi µg/m³ | AQI_lo | AQI_hi | Category |
|---|---|---|---|---|
| 0.0 | 9.0 | 0 | 50 | Good |
| 9.1 | 35.4 | 51 | 100 | Moderate |
| 35.5 | 55.4 | 101 | 150 | Unhealthy for Sensitive Groups |
| 55.5 | 125.4 | 151 | 200 | Unhealthy |
| 125.5 | 225.4 | 201 | 300 | Very Unhealthy |
| 225.5 | 500.0 | 301 | 500 | Hazardous |

**WHO 2021 guidelines** (used for recommendation thresholds):

| Pollutant | Annual guideline | 24-hour guideline |
|---|---|---|
| PM2.5 | 5 µg/m³ | 15 µg/m³ |
| PM10 | 15 µg/m³ | 45 µg/m³ |

**ASHRAE 62.1:** CO2 indoor comfort limit = **1000 ppm**. Values above this trigger ventilation advice.
