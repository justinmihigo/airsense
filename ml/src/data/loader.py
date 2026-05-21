"""
Dataset loaders for AirSense ML module.

Primary dataset: Air-Quality-Dataset.csv (semicolon-separated, European decimal commas)
External datasets: UCI Beijing Multi-Site, OpenAQ Kigali
"""

from __future__ import annotations

import io
import zipfile
from pathlib import Path

import pandas as pd
import requests

RAW_DIR = Path(__file__).parent.parent.parent / "data" / "raw"

BEIJING_URL = (
    "https://archive.ics.uci.edu/static/public/501/"
    "beijing+multi+site+air+quality+data.zip"
)

OPENAQ_V3 = "https://api.openaq.org/v3"


# ---------------------------------------------------------------------------
# Primary dataset
# ---------------------------------------------------------------------------

def load_primary(path: str | Path | None = None) -> pd.DataFrame:
    """Load the local Air-Quality-Dataset.csv.

    Handles semicolon separator and European decimal commas.
    Renames problematic column 'PM2,5' → 'PM25'.
    Parses TIME to UTC-aware datetime and sorts ascending.
    """
    if path is None:
        path = RAW_DIR / "Air-Quality-Dataset.csv"
    path = Path(path)

    df = pd.read_csv(path, sep=";", decimal=",", encoding="utf-8")

    # Normalise column names
    df.columns = [c.strip() for c in df.columns]
    col_map = {
        "PM2,5": "PM25",
        "PM2.5": "PM25",
        "CO2 CATEGORY": "CO2_CAT",
        "PM2,5 CATEGORY": "PM25_CAT",
        "PM10 CATEGORY": "PM10_CAT",
        "TEMPERATURE": "TEMPERATURE",
        "HUMIDITY": "HUMIDITY",
    }
    df.rename(columns=col_map, inplace=True)

    # Parse TIME
    if "TIME" in df.columns:
        df["TIME"] = pd.to_datetime(df["TIME"], utc=True, errors="coerce")
        df.sort_values("TIME", inplace=True)
        df.reset_index(drop=True, inplace=True)

    # Cast numeric columns
    for col in ["CO2", "PM25", "PM10", "TEMPERATURE", "HUMIDITY"]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    return df


# ---------------------------------------------------------------------------
# UCI Beijing Multi-Site Air Quality dataset
# ---------------------------------------------------------------------------

def load_beijing(data_dir: str | Path | None = None, force: bool = False) -> pd.DataFrame:
    """Download (once) and load the UCI Beijing Multi-Site dataset.

    Returns a DataFrame with columns: TIME, PM25, PM10, TEMPERATURE, HUMIDITY, CO2
    (CO2 is absent — filled with NaN to keep a consistent schema).
    """
    if data_dir is None:
        data_dir = RAW_DIR / "beijing"
    data_dir = Path(data_dir)
    data_dir.mkdir(parents=True, exist_ok=True)

    zip_path = data_dir / "beijing_airquality.zip"
    if not zip_path.exists() or force:
        print("Downloading UCI Beijing dataset (~7 MB)…")
        resp = requests.get(BEIJING_URL, timeout=120)
        resp.raise_for_status()
        zip_path.write_bytes(resp.content)
        print("Download complete.")

    frames: list[pd.DataFrame] = []
    with zipfile.ZipFile(zip_path) as zf:
        csv_names = [n for n in zf.namelist() if n.endswith(".csv")]
        for name in csv_names:
            raw = zf.read(name)
            try:
                sub = pd.read_csv(io.BytesIO(raw), encoding="utf-8")
            except Exception:
                continue
            frames.append(sub)

    if not frames:
        raise RuntimeError("No CSV files found inside Beijing zip.")

    df = pd.concat(frames, ignore_index=True)

    # Normalise column names to our schema
    rename = {}
    for c in df.columns:
        cl = c.strip().upper()
        if "PM2" in cl and "5" in cl:
            rename[c] = "PM25"
        elif cl == "PM10":
            rename[c] = "PM10"
        elif cl in ("TEMP", "TEMPERATURE"):
            rename[c] = "TEMPERATURE"
        elif "DEWP" in cl:
            pass  # skip
        elif cl in ("HUMI", "HUMIDITY", "RH"):
            rename[c] = "HUMIDITY"
    df.rename(columns=rename, inplace=True)

    # Build a TIME column from year/month/day/hour if present
    time_cols = {"year", "month", "day", "hour"} & set(df.columns)
    if len(time_cols) == 4:
        df["TIME"] = pd.to_datetime(
            df[["year", "month", "day", "hour"]].rename(
                columns={"year": "year", "month": "month", "day": "day", "hour": "hour"}
            ),
            errors="coerce",
        ).dt.tz_localize("UTC")

    # Add missing CO2 column (not measured in Beijing dataset)
    if "CO2" not in df.columns:
        df["CO2"] = float("nan")

    keep = [c for c in ["TIME", "CO2", "PM25", "PM10", "TEMPERATURE", "HUMIDITY"] if c in df.columns]
    df = df[keep].copy()

    for col in ["CO2", "PM25", "PM10", "TEMPERATURE", "HUMIDITY"]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    df.sort_values("TIME", inplace=True)
    df.reset_index(drop=True, inplace=True)
    return df


# ---------------------------------------------------------------------------
# OpenAQ — real Kigali data
# ---------------------------------------------------------------------------

def load_openaq(
    city: str = "Kigali",
    country: str = "RW",
    days: int = 90,
    limit_per_page: int = 1000,
    max_pages: int = 20,
) -> pd.DataFrame:
    """Fetch recent air quality measurements from OpenAQ v3 for Kigali.

    Returns a DataFrame with columns: TIME, parameter, value, unit, location.
    Only fetches PM2.5, PM10, CO (closest proxy to CO2/gas PPM available publicly).
    """
    from datetime import datetime, timedelta, timezone

    date_to = datetime.now(timezone.utc)
    date_from = date_to - timedelta(days=days)

    params_wanted = ["pm25", "pm10", "co", "humidity", "temperature"]
    records: list[dict] = []

    # First, look up location IDs for the city/country
    loc_resp = requests.get(
        f"{OPENAQ_V3}/locations",
        params={"city": city, "country": country, "limit": 100},
        timeout=30,
    )
    if loc_resp.status_code != 200:
        print(f"OpenAQ locations lookup failed: {loc_resp.status_code}")
        return pd.DataFrame()

    locations = loc_resp.json().get("results", [])
    location_ids = [loc["id"] for loc in locations]
    print(f"Found {len(location_ids)} OpenAQ locations in {city}.")

    if not location_ids:
        return pd.DataFrame()

    for loc_id in location_ids[:5]:  # cap at 5 stations
        for page in range(1, max_pages + 1):
            resp = requests.get(
                f"{OPENAQ_V3}/measurements",
                params={
                    "locations_id": loc_id,
                    "date_from": date_from.isoformat(),
                    "date_to": date_to.isoformat(),
                    "limit": limit_per_page,
                    "page": page,
                    "parameters_name": ",".join(params_wanted),
                },
                timeout=30,
            )
            if resp.status_code != 200:
                break
            results = resp.json().get("results", [])
            if not results:
                break
            for r in results:
                records.append(
                    {
                        "TIME": pd.to_datetime(r.get("date", {}).get("utc"), utc=True, errors="coerce"),
                        "parameter": r.get("parameter"),
                        "value": r.get("value"),
                        "unit": r.get("unit"),
                        "location": r.get("location"),
                    }
                )
            if len(results) < limit_per_page:
                break

    if not records:
        print("No OpenAQ records returned.")
        return pd.DataFrame()

    df = pd.DataFrame(records)
    df.sort_values("TIME", inplace=True)
    df.reset_index(drop=True, inplace=True)
    print(f"Fetched {len(df)} OpenAQ measurements for {city}.")
    return df


def pivot_openaq(df: pd.DataFrame) -> pd.DataFrame:
    """Pivot OpenAQ long-format DataFrame to wide, aligned with our sensor schema."""
    if df.empty:
        return df

    param_map = {"pm25": "PM25", "pm10": "PM10", "co": "CO2", "humidity": "HUMIDITY", "temperature": "TEMPERATURE"}
    df = df.copy()
    df["parameter"] = df["parameter"].map(param_map)
    df = df.dropna(subset=["parameter"])

    # Round timestamps to the nearest minute for pivoting
    df["TIME"] = df["TIME"].dt.round("1min")
    wide = df.pivot_table(index="TIME", columns="parameter", values="value", aggfunc="mean")
    wide.reset_index(inplace=True)
    wide.columns.name = None
    return wide
