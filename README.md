# AirSense — Indoor Air Quality Monitoring System

AirSense is a full-stack IoT platform for real-time indoor air quality monitoring, AI-powered health recommendations, and time-series forecasting. It ingests live sensor data over MQTT, stores historical readings in InfluxDB, and exposes a React dashboard with ML-driven insights.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Hardware Layer                          │
│   ESP32 / Arduino sensor node                                   │
│   Sensors: MQ135 (CO₂), PMS5003 (PM1/2.5/10), DHT22 (T/H)     │
│   Publishes to MQTT topic  →  sensors/indoor/airquality         │
└───────────────┬─────────────────────────────────────────────────┘
                │ MQTT (WSS :443)                │ InfluxDB Line Protocol
                ▼                                ▼
┌──────────────────────────┐       ┌─────────────────────────────┐
│   Mosquitto MQTT Broker  │       │   InfluxDB (time-series DB) │
│   mosquitto.airsense.    │       │   influxdb.airsense.dpdns.  │
│   dpdns.org              │       │   org  ·  bucket: Kigali    │
└──────────────────────────┘       └─────────────────────────────┘
                │                                │
                │  React frontend subscribes      │  useInfluxData hook
                │  via mqtt npm package           │  queries 7-day history
                ▼                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    React + Vite Frontend  (:5173)               │
│  Dashboard · Analytics · Devices · Notifications · Profile      │
└─────────────────────────┬───────────────────────────────────────┘
                          │ REST (JWT Bearer)
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                  FastAPI Backend  (:8000)                       │
│  /api/auth  /api/users  /api/devices  /api/notifications        │
│  /api/ml  (proxy → ML API)                                      │
│  MongoDB (users · devices · notifications)                      │
└─────────────────────────┬───────────────────────────────────────┘
                          │ HTTP (internal)
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ML FastAPI API  (:5000)                      │
│  /recommend  /predict/aqi  /classify/category  /forecast        │
│  13 trained models: XGBoost · Random Forest · SARIMA · …       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Features

### Real-time Monitoring
- Live sensor readings streamed over MQTT (PM1.0, PM2.5, PM10, CO₂, temperature, humidity)
- 7-day historical charts from InfluxDB (6 metrics, auto-refresh every 60s)
- Google Maps pin that moves with live GPS coordinates from the sensor payload

### AI Insights (ML Pipeline)
- **AQI Prediction** — XGBoost regression model (falls back to EPA 2024 formula)
- **AQI Classification** — 6-class label (Good → Hazardous) via XGBoost classifier
- **Health recommendations** — WHO 2021 + EPA threshold rule engine (always available, no model required)
- **PM2.5 Forecasting** — SARIMA 48-step forecast with 95% confidence interval band
- **Occupancy-aware advice** — adjusts CO₂/ventilation recommendations based on number of people in the room

### Device Management
- Auto-registers devices the first time MQTT data is received (device ID + GPS coordinates)
- Admin can manually add, edit, and delete devices
- Device status tracking and per-device sensor readings

### Notifications
- System-generated alerts when sensor thresholds are exceeded
- Admin broadcast panel — push a notification to all users
- Per-notification mark-read, mark-all-read, filter by level (info / warning / critical)

### Auth & Users
- JWT authentication (access token stored in localStorage)
- Role-based access: `admin` vs `user`
- User profile management

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | React 19, Vite 6, TypeScript 5, Tailwind CSS v4 |
| Charts | @nivo/line, @nivo/bar (0.99) |
| Maps | Google Maps JS API — AdvancedMarkerElement |
| MQTT client | mqtt npm package (v5, over WSS) |
| Backend | Python 3.11+, FastAPI, Motor (async MongoDB) |
| Auth | JWT via python-jose, bcrypt |
| ML API | FastAPI + scikit-learn, XGBoost, statsmodels |
| Time-series DB | InfluxDB v2 (cloud-hosted) |
| Document DB | MongoDB Atlas |
| Message broker | Mosquitto MQTT |
| Container | Docker + Docker Compose |

---

## Project Structure

```
airsense/
├── frontend/              # React + Vite SPA
│   ├── src/
│   │   ├── hooks/         # useAuth, useInfluxData, useMQTT
│   │   ├── lib/           # api.ts (axios instance with JWT)
│   │   └── pages/         # Dashboard, Analytics, Devices, Notifications, Profile
│   └── .env               # VITE_* env vars (see env_files.zip)
│
├── backend/               # FastAPI REST API
│   ├── app/
│   │   ├── api/routes/    # auth, users, devices, notifications, ml
│   │   ├── models/        # Pydantic schemas
│   │   ├── db/            # MongoDB connection (Motor)
│   │   └── core/          # JWT, config, settings
│   └── .env               # DB URL, JWT secret, allowed origins
│
├── ml/                    # ML pipeline + FastAPI inference API
│   ├── api.py             # FastAPI app on :5000
│   ├── models/            # Trained .joblib files (13 models)
│   ├── notebooks/         # 01 EDA → 02 Models → 03 Forecast → 04 Recommendations
│   └── src/               # data, models, evaluation, recommendations
│
├── docker-compose.yml     # backend + frontend + mongodb
├── env_files.zip          # all .env files zipped (extract at project root)
└── README.md
```

---

## Prerequisites

- **Node.js** ≥ 18
- **Python** ≥ 3.11
- **MongoDB** (local or Atlas — connection string in `backend/.env`)
- **InfluxDB v2** bucket with write access
- **Mosquitto** MQTT broker (or any MQTT broker over WSS)
- **Google Maps API key** with Maps JavaScript API enabled

---

## Setup

### 1. Clone and extract environment files

```bash
git clone https://github.com/justinmihigo/airsense.git
cd airsense

# Extract all .env files to their correct locations
unzip env_files.zip
```

Edit each `.env` file with your own credentials before starting (see [Environment Variables](#environment-variables)).

### 2. Backend

```bash
cd backend/
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt

uvicorn app.main:app --reload    # → http://localhost:8000
```

### 3. ML API

```bash
cd ml/
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# macOS only (XGBoost dependency)
brew install libomp

python api.py                    # → http://localhost:5000
```

> Models are pre-trained and committed to `ml/models/`. To re-train, run notebooks 02 and 03 in order.

### 4. Frontend

```bash
cd frontend/
npm install
npm run dev                      # → http://localhost:5173
```

---

## Docker (backend + frontend + MongoDB)

```bash
docker compose up --build
```

| Service | Port |
|---|---|
| Backend API | 8000 |
| Frontend | 3000 |
| MongoDB | 27017 |

> The ML API is not in the compose file — run it separately with `python api.py`.

---

## Environment Variables

### `frontend/.env`

| Variable | Description |
|---|---|
| `VITE_API_URL` | Backend base URL (default `http://localhost:8000`) |
| `VITE_ML_API_URL` | ML API base URL (default `http://localhost:5000`) |
| `VITE_INFLUX_URL` | InfluxDB host URL |
| `VITE_INFLUX_BUCKET` | InfluxDB bucket name |
| `VITE_INFLUX_ORG` | InfluxDB organisation |
| `VITE_INFLUX_TOKEN` | InfluxDB read token |
| `VITE_INFLUX_MEASUREMENT` | Measurement name (default `airquality`) |
| `VITE_MQTT_URL` | MQTT broker WebSocket URL (e.g. `wss://…:443`) |
| `VITE_MQTT_TOPIC` | MQTT topic (e.g. `sensors/indoor/airquality`) |
| `VITE_GOOGLE_MAPS_KEY` | Google Maps JavaScript API key |

### `backend/.env`

| Variable | Description |
|---|---|
| `MONGODB_URL` | MongoDB connection string |
| `DATABASE_NAME` | Database name (default `airsense`) |
| `SECRET_KEY` | JWT signing secret (change before deploying) |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Token TTL (default 1440 = 24h) |
| `ALLOWED_ORIGINS` | CORS origins, comma-separated |
| `ML_API_URL` | Internal ML API URL (default `http://localhost:5000`) |

---

## API Reference

All endpoints except `/api/auth/*` require `Authorization: Bearer <token>`.

### Auth
| Method | Path | Description |
|---|---|---|
| POST | `/api/auth/login` | Login, returns JWT access token |
| POST | `/api/auth/register` | Register new user |

### Devices
| Method | Path | Auth |
|---|---|---|
| GET | `/api/devices` | All users (admin sees all, user sees own) |
| POST | `/api/devices` | Admin only |
| POST | `/api/devices/auto-register` | Any authenticated user (called from MQTT hook) |
| PATCH | `/api/devices/{id}` | Owner |
| DELETE | `/api/devices/{id}` | Admin only |

### Notifications
| Method | Path | Auth |
|---|---|---|
| GET | `/api/notifications` | Returns own notifications |
| POST | `/api/notifications` | Admin only (supports `broadcast: true`) |
| PATCH | `/api/notifications/{id}/read` | Any authenticated user |

### ML (proxied to ML API on :5000)
| Method | Path | Description |
|---|---|---|
| GET | `/api/ml/health` | Model load status |
| POST | `/api/ml/recommend` | Health/activity/ventilation advice |
| POST | `/api/ml/predict/aqi` | Numeric AQI score + category |
| POST | `/api/ml/classify/category` | AQI category label only |
| GET | `/api/ml/forecast?steps=48` | PM2.5 SARIMA forecast |

### ML request body (shared across `/recommend`, `/predict/aqi`, `/classify/category`)

```json
{
  "pm25": 22.5,
  "pm10": 35.0,
  "co2": 850,
  "temperature": 24.0,
  "humidity": 65.0,
  "occupancy": 3
}
```

---

## ML Pipeline

See [ml/README.md](ml/README.md) for a full explanation of how models are trained, how the feature vector is built at inference time, and how to manually test each endpoint.

### Trained models (`ml/models/`)

| Type | Models |
|---|---|
| Regression (AQI score) | Linear, Ridge, Lasso, Polynomial ×2, Random Forest, SVR, **XGBoost** |
| Classification (AQI category) | Logistic, Random Forest, SVC, **XGBoost** |
| Forecasting (PM2.5) | **SARIMA** (auto AIC order selection) |

XGBoost is preferred at inference time for both regression and classification. If no trained models are loaded, the API falls back to the EPA 2024 piecewise AQI formula.

### Re-training

```bash
cd ml/
source .venv/bin/activate
jupyter notebook notebooks/

# Run in order:
# 02_Model_Comparison.ipynb   → saves *_reg.joblib, *_clf.joblib, feature_names.joblib
# 03_Forecasting.ipynb        → saves sarima_pm25.joblib
```

---

## Assigning Admin Role

Admin role must be set directly in MongoDB (there is no self-serve admin promotion):

```js
// mongosh or MongoDB Compass shell
use airsense
db.users.updateOne(
  { email: "your@email.com" },
  { $set: { role: "admin" } }
)
```

---

## MQTT Payload Format

The sensor node publishes JSON to the configured topic:

```json
{
  "device": "sensor-01",
  "pm1_0": 5.2,
  "pm2_5": 12.4,
  "pm10": 18.7,
  "gas_ppm": 720,
  "temperature": 24.1,
  "humidity": 61.3,
  "latitude": -1.94407,
  "longitude": 30.06144,
  "timestamp": "2026-05-21T08:30:00Z"
}
```

The frontend auto-registers the device in the backend on the first message received from an unknown `device` ID.

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes
4. Push and open a Pull Request

---

## License

MIT License — see [LICENSE](LICENSE) for details.
