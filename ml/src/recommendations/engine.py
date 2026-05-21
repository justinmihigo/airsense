"""
AirSense Recommendations Engine.

Combines WHO 2021 + EPA 2024 threshold rules with optional ML-derived context.
Returns structured recommendations for health, activity, and ventilation.
"""

from __future__ import annotations

from dataclasses import dataclass, field

# ---------------------------------------------------------------------------
# WHO 2021 + EPA 2024 thresholds (24-hour averages)
# ---------------------------------------------------------------------------

THRESHOLDS = {
    "PM25": {
        "who_good":      5.0,   # WHO annual guideline
        "who_24h":      15.0,   # WHO 24-hour guideline
        "epa_moderate":  9.1,   # EPA Good/Moderate boundary
        "epa_usg":      35.5,   # Unhealthy for Sensitive Groups
        "epa_unhealthy": 55.5,
        "epa_very":     125.5,
        "epa_hazardous": 225.5,
    },
    "PM10": {
        "who_24h":  45.0,
        "epa_moderate": 55.0,
        "epa_usg":     155.0,
        "epa_unhealthy": 255.0,
        "epa_very":    355.0,
        "epa_hazardous": 425.0,
    },
    "CO2": {
        "normal":        600,   # typical outdoor CO2 ~420 ppm; indoor ok up to 600
        "elevated":      800,   # concentration causing mild cognitive impairment
        "high":         1000,   # ASHRAE comfort limit
        "very_high":    1500,   # headaches, fatigue
        "dangerous":    2000,
    },
    "TEMPERATURE": {
        "cold":    16.0,
        "comfort_lo": 18.0,
        "comfort_hi": 26.0,
        "warm":    28.0,
        "hot":     32.0,
    },
    "HUMIDITY": {
        "dry":         30.0,
        "comfort_lo":  40.0,
        "comfort_hi":  60.0,
        "humid":       70.0,
        "very_humid":  80.0,
    },
}

AQI_LEVELS = [
    (0,   50,  "Good",                           "#00E400", "green"),
    (51,  100, "Moderate",                        "#FFFF00", "yellow"),
    (101, 150, "Unhealthy for Sensitive Groups",  "#FF7E00", "orange"),
    (151, 200, "Unhealthy",                       "#FF0000", "red"),
    (201, 300, "Very Unhealthy",                  "#8F3F97", "purple"),
    (301, 500, "Hazardous",                       "#7E0023", "maroon"),
]


@dataclass
class Recommendation:
    aqi: float | None
    level: str
    color: str
    health_advice: list[str] = field(default_factory=list)
    activity_advice: list[str] = field(default_factory=list)
    ventilation_advice: list[str] = field(default_factory=list)
    sensor_alerts: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "aqi": self.aqi,
            "level": self.level,
            "color": self.color,
            "health_advice": self.health_advice,
            "activity_advice": self.activity_advice,
            "ventilation_advice": self.ventilation_advice,
            "sensor_alerts": self.sensor_alerts,
        }


def _aqi_level(aqi: float) -> tuple[str, str]:
    for lo, hi, label, color, _ in AQI_LEVELS:
        if lo <= aqi <= hi:
            return label, color
    return "Hazardous", "#7E0023"


def _pm25_advice(pm25: float) -> tuple[list[str], list[str], list[str]]:
    t = THRESHOLDS["PM25"]
    health, activity, ventilation = [], [], []

    if pm25 < t["who_24h"]:
        health.append("PM2.5 is within WHO 24-hour guideline (< 15 µg/m³). Air quality is acceptable.")
        activity.append("All outdoor activities are safe.")
    elif pm25 < t["epa_usg"]:
        health.append(f"PM2.5 ({pm25:.1f} µg/m³) exceeds WHO guideline. Sensitive individuals may experience symptoms.")
        activity.append("Sensitive groups (asthma, heart disease, elderly, children) should reduce prolonged outdoor exertion.")
        ventilation.append("Consider running air purifier with HEPA filter.")
    elif pm25 < t["epa_unhealthy"]:
        health.append(f"PM2.5 ({pm25:.1f} µg/m³) is in the Unhealthy for Sensitive Groups range.")
        activity.append("Sensitive groups should avoid prolonged outdoor activity. Others should reduce strenuous activity.")
        ventilation.append("Keep windows closed. Run HEPA air purifier.")
    elif pm25 < t["epa_very"]:
        health.append(f"ALERT: PM2.5 ({pm25:.1f} µg/m³) is Unhealthy. Everyone may experience health effects.")
        activity.append("Avoid all outdoor physical activity. Stay indoors with air purifier running.")
        ventilation.append("Seal gaps around windows/doors. Air purifier on maximum setting.")
    else:
        health.append(f"EMERGENCY: PM2.5 ({pm25:.1f} µg/m³) is Very Unhealthy or Hazardous.")
        activity.append("Stay indoors. Avoid ALL outdoor activity. Wear N95/P100 mask if must go outside.")
        ventilation.append("Run air purifier continuously. Evacuate if no purifier available.")

    return health, activity, ventilation


def _pm10_advice(pm10: float) -> list[str]:
    t = THRESHOLDS["PM10"]
    if pm10 > t["epa_very"]:
        return [f"PM10 ({pm10:.1f} µg/m³) is Very Unhealthy — coarse particles can irritate airways severely."]
    elif pm10 > t["epa_usg"]:
        return [f"PM10 ({pm10:.1f} µg/m³) exceeds EPA moderate limit — keep windows closed."]
    elif pm10 > t["who_24h"]:
        return [f"PM10 ({pm10:.1f} µg/m³) exceeds WHO 24-hour guideline of 45 µg/m³."]
    return []


def _co2_advice(co2: float) -> tuple[list[str], list[str]]:
    t = THRESHOLDS["CO2"]
    health, ventilation = [], []
    if co2 > t["dangerous"]:
        health.append(f"CO2 CRITICAL ({co2:.0f} ppm): Risk of headaches, dizziness, impaired cognitive function.")
        ventilation.append("IMMEDIATE ACTION: Open all windows and doors. Evacuate if possible.")
    elif co2 > t["very_high"]:
        health.append(f"CO2 Very High ({co2:.0f} ppm): Headaches and fatigue likely.")
        ventilation.append("Open windows immediately. Increase mechanical ventilation.")
    elif co2 > t["high"]:
        health.append(f"CO2 High ({co2:.0f} ppm): Above ASHRAE comfort limit. Some occupants may feel drowsy.")
        ventilation.append("Open windows or increase ventilation rate.")
    elif co2 > t["elevated"]:
        ventilation.append(f"CO2 slightly elevated ({co2:.0f} ppm). Improve ventilation by opening a window.")
    return health, ventilation


def _temp_humidity_advice(temp: float, humidity: float) -> list[str]:
    t_t = THRESHOLDS["TEMPERATURE"]
    t_h = THRESHOLDS["HUMIDITY"]
    advice = []
    if temp > t_t["hot"] and humidity > t_h["humid"]:
        advice.append(f"Heat + humidity combination ({temp:.1f}°C, {humidity:.0f}%RH): High heat-stress risk. Stay hydrated, use fans/AC.")
    elif temp > t_t["warm"]:
        advice.append(f"Temperature elevated ({temp:.1f}°C). Ensure adequate hydration and ventilation.")
    elif temp < t_t["cold"]:
        advice.append(f"Temperature low ({temp:.1f}°C). Risk of respiratory irritation. Keep indoor temp ≥ 18°C.")
    if humidity > t_h["very_humid"]:
        advice.append(f"High humidity ({humidity:.0f}%RH): Promotes mold and dust mite growth. Use dehumidifier.")
    elif humidity < t_h["dry"]:
        advice.append(f"Low humidity ({humidity:.0f}%RH): Can dry mucous membranes. Use humidifier.")
    return advice


def recommend(
    pm25: float | None = None,
    pm10: float | None = None,
    co2: float | None = None,
    temperature: float | None = None,
    humidity: float | None = None,
    aqi: float | None = None,
    occupancy: int | None = None,
) -> Recommendation:
    """
    Generate structured recommendations from current sensor readings.

    Parameters follow the AirSense sensor schema:
      - pm25 (µg/m³), pm10 (µg/m³), co2 (ppm), temperature (°C), humidity (%)
      - aqi: pre-computed AQI (if None, computed from pm25/pm10)
      - occupancy: number of people in the room (affects CO2/ventilation thresholds)
    """
    import math

    # Compute AQI if not provided
    if aqi is None:
        from src.data.preprocessor import overall_aqi
        if pm25 is not None and pm10 is not None:
            aqi = overall_aqi(pm25, pm10)
        elif pm25 is not None:
            from src.data.preprocessor import aqi_from_pm25
            aqi = aqi_from_pm25(pm25)
        elif pm10 is not None:
            from src.data.preprocessor import aqi_from_pm10
            aqi = aqi_from_pm10(pm10)

    if aqi is not None and not math.isnan(aqi):
        level, color = _aqi_level(aqi)
    else:
        level, color = "Unknown", "#888888"

    health: list[str] = []
    activity: list[str] = []
    ventilation: list[str] = []
    alerts: list[str] = []

    if pm25 is not None:
        h, a, v = _pm25_advice(pm25)
        health += h
        activity += a
        ventilation += v
        if pm25 > THRESHOLDS["PM25"]["epa_usg"]:
            alerts.append(f"PM2.5 alert: {pm25:.1f} µg/m³")

    if pm10 is not None:
        pm10_h = _pm10_advice(pm10)
        health += pm10_h
        if pm10 > THRESHOLDS["PM10"]["epa_usg"]:
            alerts.append(f"PM10 alert: {pm10:.1f} µg/m³")

    if co2 is not None:
        h, v = _co2_advice(co2)
        health += h
        ventilation += v
        if co2 > THRESHOLDS["CO2"]["high"]:
            alerts.append(f"CO2 alert: {co2:.0f} ppm")

    if temperature is not None and humidity is not None:
        env_advice = _temp_humidity_advice(temperature, humidity)
        health += env_advice
    elif temperature is not None:
        env_advice = _temp_humidity_advice(temperature, humidity or 50.0)
        health += env_advice

    if occupancy is not None and occupancy > 0:
        # Each person exhales ~200 ppm CO2/hr into a typical room; flag proactively
        if occupancy >= 6:
            ventilation.append(
                f"{occupancy} people present: CO2 will rise quickly. Ensure active ventilation."
            )
        elif occupancy >= 3:
            ventilation.append(
                f"{occupancy} people in room: monitor CO2 levels and open a window if > 800 ppm."
            )
        if co2 is not None:
            co2_per_person = co2 / max(occupancy, 1)
            if co2_per_person > 250:
                health.append(
                    f"CO2 per-person ratio is high ({co2_per_person:.0f} ppm/person). Increase fresh air supply."
                )

    if not health:
        health.append("Air quality is good. No health concerns at this time.")
    if not activity:
        activity.append("All activities are safe. Enjoy outdoor exercise!")
    if not ventilation:
        ventilation.append("Normal ventilation is sufficient.")

    return Recommendation(
        aqi=aqi,
        level=level,
        color=color,
        health_advice=health,
        activity_advice=activity,
        ventilation_advice=ventilation,
        sensor_alerts=alerts,
    )


def batch_recommend(df) -> list[dict]:
    """Apply recommend() row-by-row to a DataFrame."""
    results = []
    for _, row in df.iterrows():
        rec = recommend(
            pm25=row.get("PM25"),
            pm10=row.get("PM10"),
            co2=row.get("CO2"),
            temperature=row.get("TEMPERATURE"),
            humidity=row.get("HUMIDITY"),
            aqi=row.get("AQI"),
            occupancy=row.get("OCCUPANCY"),
        )
        results.append(rec.to_dict())
    return results
