"""
Data preprocessing for AirSense ML.

Pipeline:
  load → clean → aqi_compute → feature_engineer → split → scale
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from sklearn.preprocessing import LabelEncoder, StandardScaler

# ---------------------------------------------------------------------------
# AQI breakpoints — EPA 2024 (PM2.5 revised to 9 µg/m³ annual standard)
# Piecewise linear: AQI = (I_hi - I_lo)/(C_hi - C_lo) * (C - C_lo) + I_lo
# ---------------------------------------------------------------------------

PM25_BREAKPOINTS = [
    (0.0,   9.0,   0,  50),
    (9.1,  35.4,  51, 100),
    (35.5, 55.4, 101, 150),
    (55.5, 125.4, 151, 200),
    (125.5, 225.4, 201, 300),
    (225.5, 325.4, 301, 400),
    (325.5, 500.0, 401, 500),
]

PM10_BREAKPOINTS = [
    (0,   54,   0,  50),
    (55,  154,  51, 100),
    (155, 254, 101, 150),
    (255, 354, 151, 200),
    (355, 424, 201, 300),
    (425, 504, 301, 400),
    (505, 604, 401, 500),
]

AQI_CATEGORIES = [
    (0,   50,  "Good",                  "#00E400"),
    (51,  100, "Moderate",              "#FFFF00"),
    (101, 150, "Unhealthy for Sensitive Groups", "#FF7E00"),
    (151, 200, "Unhealthy",             "#FF0000"),
    (201, 300, "Very Unhealthy",        "#8F3F97"),
    (301, 500, "Hazardous",             "#7E0023"),
]

SENSOR_COLS = ["CO2", "PM25", "PM10", "TEMPERATURE", "HUMIDITY"]
OCCUPANCY_COL = "OCCUPANCY"  # optional — number of people in the room


def _piecewise_aqi(c: float, breakpoints: list[tuple]) -> float:
    if np.isnan(c):
        return np.nan
    for c_lo, c_hi, i_lo, i_hi in breakpoints:
        if c_lo <= c <= c_hi:
            return (i_hi - i_lo) / (c_hi - c_lo) * (c - c_lo) + i_lo
    # Above highest breakpoint
    return 500.0


def aqi_from_pm25(c: float) -> float:
    return _piecewise_aqi(c, PM25_BREAKPOINTS)


def aqi_from_pm10(c: float) -> float:
    return _piecewise_aqi(c, PM10_BREAKPOINTS)


def overall_aqi(pm25: float, pm10: float) -> float:
    return max(aqi_from_pm25(pm25), aqi_from_pm10(pm10))


def aqi_category(aqi: float) -> str:
    if np.isnan(aqi):
        return "Unknown"
    for lo, hi, label, _ in AQI_CATEGORIES:
        if lo <= aqi <= hi:
            return label
    return "Hazardous"


def aqi_category_index(aqi: float) -> int:
    """Return 0-based integer label for the 6 AQI categories."""
    labels = [c[2] for c in AQI_CATEGORIES]
    cat = aqi_category(aqi)
    try:
        return labels.index(cat)
    except ValueError:
        return 5  # Hazardous


# ---------------------------------------------------------------------------
# Main preprocessing pipeline
# ---------------------------------------------------------------------------

def clean(df: pd.DataFrame) -> pd.DataFrame:
    """Basic cleaning: type coercion, interpolation, drop long NaN runs."""
    df = df.copy()

    for col in SENSOR_COLS:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")
            # Clip obviously bad sensor values (negative readings)
            df[col] = df[col].clip(lower=0)

    # Linear interpolation (time-aware) — safe for short gaps
    df[SENSOR_COLS] = df[[c for c in SENSOR_COLS if c in df.columns]].interpolate(
        method="linear", limit=6
    )

    # Drop rows where ALL sensor columns are still NaN
    df.dropna(
        subset=[c for c in SENSOR_COLS if c in df.columns], how="all", inplace=True
    )
    df.reset_index(drop=True, inplace=True)
    return df


def add_aqi(df: pd.DataFrame) -> pd.DataFrame:
    """Compute EPA AQI from PM25 and PM10, add AQI_PM25, AQI_PM10, AQI, AQI_LABEL columns."""
    df = df.copy()
    if "PM25" in df.columns:
        df["AQI_PM25"] = df["PM25"].apply(aqi_from_pm25)
    if "PM10" in df.columns:
        df["AQI_PM10"] = df["PM10"].apply(aqi_from_pm10)

    if "AQI_PM25" in df.columns and "AQI_PM10" in df.columns:
        df["AQI"] = df[["AQI_PM25", "AQI_PM10"]].max(axis=1)
    elif "AQI_PM25" in df.columns:
        df["AQI"] = df["AQI_PM25"]
    elif "AQI_PM10" in df.columns:
        df["AQI"] = df["AQI_PM10"]

    if "AQI" in df.columns:
        df["AQI_LABEL"] = df["AQI"].apply(aqi_category)
        df["AQI_IDX"] = df["AQI"].apply(aqi_category_index)

    return df


def add_time_features(df: pd.DataFrame, time_col: str = "TIME") -> pd.DataFrame:
    """Extract temporal features from the TIME column, including cyclic hour encoding."""
    df = df.copy()
    if time_col not in df.columns:
        return df

    t = df[time_col]
    df["hour"] = t.dt.hour
    df["day_of_week"] = t.dt.dayofweek  # 0=Monday
    df["month"] = t.dt.month
    df["is_weekend"] = (df["day_of_week"] >= 5).astype(int)
    # Cyclic encoding so hour 23 and hour 0 are close
    df["hour_sin"] = np.sin(2 * np.pi * df["hour"] / 24)
    df["hour_cos"] = np.cos(2 * np.pi * df["hour"] / 24)
    df["dow_sin"] = np.sin(2 * np.pi * df["day_of_week"] / 7)
    df["dow_cos"] = np.cos(2 * np.pi * df["day_of_week"] / 7)
    return df


def add_lag_features(df: pd.DataFrame, lags: list[int] | None = None) -> pd.DataFrame:
    """Add t-n lag features for core sensor columns and occupancy if present."""
    if lags is None:
        lags = [1, 2, 6, 12, 24]
    df = df.copy()
    lag_cols = ["PM25", "PM10", "CO2", "TEMPERATURE", "HUMIDITY", "OCCUPANCY"]
    for col in lag_cols:
        if col not in df.columns:
            continue
        for lag in lags:
            df[f"{col}_lag{lag}"] = df[col].shift(lag)
    return df


def add_rolling_features(
    df: pd.DataFrame, windows: list[int] | None = None
) -> pd.DataFrame:
    """Add rolling mean and std for core sensor columns and occupancy if present."""
    if windows is None:
        windows = [6, 24, 72]
    df = df.copy()
    roll_cols = ["PM25", "PM10", "CO2", "TEMPERATURE", "HUMIDITY", "OCCUPANCY"]
    for col in roll_cols:
        if col not in df.columns:
            continue
        for w in windows:
            df[f"{col}_roll{w}_mean"] = df[col].rolling(w, min_periods=1).mean()
            df[f"{col}_roll{w}_std"] = df[col].rolling(w, min_periods=1).std()
    return df


def encode_labels(df: pd.DataFrame) -> tuple[pd.DataFrame, dict[str, LabelEncoder]]:
    """Encode categorical target columns. Returns (df, encoders_dict)."""
    df = df.copy()
    encoders: dict[str, LabelEncoder] = {}
    for col in ["CO2_CAT", "PM25_CAT", "PM10_CAT", "AQI_LABEL"]:
        if col in df.columns:
            le = LabelEncoder()
            df[col + "_ENC"] = le.fit_transform(df[col].astype(str))
            encoders[col] = le
    return df, encoders


def split(
    df: pd.DataFrame,
    test_size: float = 0.2,
    val_size: float = 0.1,
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Chronological train/val/test split — NO shuffling to prevent data leakage."""
    n = len(df)
    n_test = int(n * test_size)
    n_val = int(n * val_size)
    n_train = n - n_val - n_test

    train = df.iloc[:n_train].copy()
    val = df.iloc[n_train : n_train + n_val].copy()
    test = df.iloc[n_train + n_val :].copy()
    return train, val, test


def scale_features(
    train: pd.DataFrame,
    val: pd.DataFrame,
    test: pd.DataFrame,
    feature_cols: list[str],
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, StandardScaler]:
    """Fit StandardScaler on train only, then transform all splits."""
    scaler = StandardScaler()
    train = train.copy()
    val = val.copy()
    test = test.copy()

    train[feature_cols] = scaler.fit_transform(train[feature_cols])
    val[feature_cols] = scaler.transform(val[feature_cols])
    test[feature_cols] = scaler.transform(test[feature_cols])
    return train, val, test, scaler


def full_pipeline(
    df: pd.DataFrame,
    add_lags: bool = True,
    add_rolling: bool = True,
) -> pd.DataFrame:
    """Run the full preprocessing pipeline on a raw DataFrame."""
    df = clean(df)
    df = add_aqi(df)
    df = add_time_features(df)
    if add_lags:
        df = add_lag_features(df)
    if add_rolling:
        df = add_rolling_features(df)
    df, _ = encode_labels(df)
    df.dropna(inplace=True)
    df.reset_index(drop=True, inplace=True)
    return df
