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
        activity.append(
            "Stay indoors and avoid ALL outdoor activity. If a HEPA purifier is unavailable, "
            "relocate to a building with filtered air. Wear an N95/P100 mask for any time outside."
        )
        ventilation.append(
            "Seal gaps around windows and doors. Run HEPA air purifier on maximum setting continuously."
        )

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
        ventilation.append("IMMEDIATE ACTION: Open all windows and doors. If symptoms present, evacuate and seek fresh air. Prolonged exposure at this level is dangerous.")
        # ventilation.append("IMMEDIATE ACTION: Open all windows and doors. Evacuate if possible.")
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

    if occupancy is not None and occupancy >= 1:
        # Each person adds ~200 ppm CO2/hr to a typical room. Advice tiers
        # start from a single occupant so a "Basis: latest, 1 person" request
        # still gets occupancy-aware guidance rather than nothing.
        if occupancy >= 6:
            ventilation.append(
                f"{occupancy} people present: CO2 will rise quickly. Ensure active ventilation."
            )
        elif occupancy >= 3:
            ventilation.append(
                f"{occupancy} people in room: monitor CO2 levels and open a window if > 800 ppm."
            )
        elif occupancy == 2:
            ventilation.append(
                "Two occupants: modest CO2 buildup expected over the next hour — cracking a "
                "window or running a fan on low is usually enough."
            )
        else:  # occupancy == 1
            ventilation.append(
                "Single occupant: CO2 contribution is minimal. Standard background "
                "ventilation is sufficient unless the room is very small or unventilated."
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


# ---------------------------------------------------------------------------
# Building-level insights (home / school / office)
#
# Operates on a *window* of readings rather than a single point. Surfaces the
# kind of conditions that point to the BUILDING (envelope, ventilation,
# moisture, daily cycles) rather than the current air-quality snapshot.
# ---------------------------------------------------------------------------

BUILDING_PROFILES: dict[str, dict] = {
    "home": {
        "label": "Home",
        "pm25_baseline_limit": 12.0,           # WHO daily target
        "co2_limit": 1000,                      # ASHRAE comfort cap
        "co2_overlimit_fraction": 0.20,         # 20% of window above the cap is enough to flag
        "humidity_high_fraction_limit": 0.30,
        "humidity_low_fraction_limit": 0.30,
        "temperature_target": (18.0, 26.0),
        "ach_min": 0.35,                        # residential code minimum
    },
    "school": {
        "label": "School / Classroom",
        # Children are more sensitive — stricter PM2.5 baseline and CO2 budget,
        # and ASHRAE 62.1 recommends ≤1100 ppm CO2 in classrooms.
        "pm25_baseline_limit": 9.0,
        "co2_limit": 1100,
        "co2_overlimit_fraction": 0.10,
        "humidity_high_fraction_limit": 0.25,
        "humidity_low_fraction_limit": 0.30,
        "temperature_target": (20.0, 24.0),
        "ach_min": 0.50,                        # classrooms need higher fresh-air rates
    },
    "office": {
        "label": "Office",
        "pm25_baseline_limit": 12.0,
        "co2_limit": 1000,
        "co2_overlimit_fraction": 0.15,
        "humidity_high_fraction_limit": 0.30,
        "humidity_low_fraction_limit": 0.30,
        "temperature_target": (20.0, 26.0),
        "ach_min": 0.40,
    },
}


def _clean(values) -> list[float]:
    return [float(v) for v in (values or []) if v is not None]


def _percentile(values: list[float], pct: float) -> float | None:
    arr = sorted(values)
    if not arr:
        return None
    idx = max(0, min(len(arr) - 1, int(len(arr) * pct / 100)))
    return arr[idx]


def _fraction_above(values: list[float], threshold: float) -> float:
    if not values:
        return 0.0
    return sum(1 for v in values if v > threshold) / len(values)


def _fraction_below(values: list[float], threshold: float) -> float:
    if not values:
        return 0.0
    return sum(1 for v in values if v < threshold) / len(values)


def _temperature_swing(values: list[float]) -> float | None:
    if not values:
        return None
    return max(values) - min(values)


def _linear_slope(values: list[float]) -> float | None:
    """Slope of the simple least-squares fit per sample. Used to detect
    drift in a pollutant over the window (e.g. PM2.5 climbing over hours).
    """
    n = len(values)
    if n < 4:
        return None
    mean_x = (n - 1) / 2.0
    mean_y = sum(values) / n
    num = sum((i - mean_x) * (v - mean_y) for i, v in enumerate(values))
    den = sum((i - mean_x) ** 2 for i in range(n))
    if den == 0:
        return None
    return num / den


def _spike_count(values: list[float], multiplier: float = 2.0) -> int:
    """Count readings sitting at multiplier × the baseline (10th percentile).
    A pure pollution event lifts the whole window; a few spikes against a
    clean baseline are more likely caused by disturbed dust (vacuuming,
    door slam, sweeping).
    """
    baseline = _percentile(values, 10)
    if baseline is None or baseline <= 0:
        return 0
    threshold = baseline * multiplier
    return sum(1 for v in values if v > threshold)


def _estimate_ach_from_decay(
    co2: list[float],
    minutes_per_sample: float,
    outdoor_co2: float = 420.0,
    min_decay_samples: int = 12,
) -> float | None:
    """Estimate air-changes-per-hour from the longest CO2 decay segment.

    Uses the standard exponential-decay model:
        C(t) = C_outdoor + (C_0 - C_outdoor) * exp(-ACH * t)
    → ACH = ln((C_0 - C_out) / (C_t - C_out)) / Δt_hours

    Returns None if no clean decay segment of `min_decay_samples` is found.
    """
    import math
    arr = co2
    if len(arr) < min_decay_samples or minutes_per_sample <= 0:
        return None

    # Longest strictly-decreasing run
    best_start, best_end = 0, 0
    cur_start = 0
    for i in range(1, len(arr)):
        if arr[i] < arr[i - 1]:
            if i - cur_start > best_end - best_start:
                best_start, best_end = cur_start, i
        else:
            cur_start = i
    if best_end - best_start < min_decay_samples:
        return None

    c0 = arr[best_start]
    ct = arr[best_end]
    if c0 <= outdoor_co2 or ct <= outdoor_co2 or c0 <= ct:
        return None

    dt_hours = (best_end - best_start) * minutes_per_sample / 60.0
    if dt_hours <= 0:
        return None

    try:
        ach = math.log((c0 - outdoor_co2) / (ct - outdoor_co2)) / dt_hours
    except (ValueError, ZeroDivisionError):
        return None

    # Sanity-cap: anything outside [0.05, 20] is almost certainly noise
    if not (0.05 <= ach <= 20):
        return None
    return round(ach, 3)


@dataclass
class BuildingInsights:
    building_type: str
    label: str
    metrics: dict
    advice: list[str] = field(default_factory=list)
    cleaning_advice: list[str] = field(default_factory=list)
    severity: str = "info"  # info | warning | critical

    def to_dict(self) -> dict:
        return {
            "building_type": self.building_type,
            "label": self.label,
            "metrics": self.metrics,
            "advice": self.advice,
            "cleaning_advice": self.cleaning_advice,
            "severity": self.severity,
        }


def _window_metrics(window: dict, minutes_per_sample: float) -> dict:
    pm25 = _clean(window.get("pm25"))
    pm10 = _clean(window.get("pm10"))
    co2 = _clean(window.get("co2"))
    temp = _clean(window.get("temperature"))
    hum = _clean(window.get("humidity"))

    # PM2.5 trend in µg/m³ per hour — positive = baseline drifting up over the window
    pm25_slope_per_sample = _linear_slope(pm25)
    if pm25_slope_per_sample is not None and minutes_per_sample > 0:
        pm25_trend_per_hour = pm25_slope_per_sample * (60.0 / minutes_per_sample)
    else:
        pm25_trend_per_hour = None

    pm10_median = _percentile(pm10, 50)
    pm25_median = _percentile(pm25, 50)
    pm10_pm25_ratio = (pm10_median / pm25_median) if (pm10_median and pm25_median) else None

    return {
        "samples": len(co2 or pm25 or hum or temp),
        "minutes_per_sample": minutes_per_sample,
        "baseline_pm25": _percentile(pm25, 10),   # cleanest 10% — the "floor"
        "median_pm25": pm25_median,
        "baseline_pm10": _percentile(pm10, 10),
        "median_co2": _percentile(co2, 50),
        "peak_co2": max(co2) if co2 else None,
        "humid_hours_fraction": round(_fraction_above(hum, 60.0), 3) if hum else None,
        "dry_hours_fraction": round(_fraction_below(hum, 30.0), 3) if hum else None,
        "pm25_trend_per_hour": round(pm25_trend_per_hour, 3) if pm25_trend_per_hour is not None else None,
        "pm25_spike_count": _spike_count(pm25),
        "pm10_pm25_ratio": round(pm10_pm25_ratio, 2) if pm10_pm25_ratio is not None else None,
        "temperature_swing": round(_temperature_swing(temp), 2) if temp else None,
        "co2_overlimit_fraction_1000": round(_fraction_above(co2, 1000), 3) if co2 else None,
        "co2_overlimit_fraction_1100": round(_fraction_above(co2, 1100), 3) if co2 else None,
        "ach_estimate": _estimate_ach_from_decay(co2, minutes_per_sample) if co2 else None,
    }


def _bump(current: str, new: str) -> str:
    rank = {"info": 0, "warning": 1, "critical": 2}
    return new if rank[new] > rank[current] else current


def _cleaning_advice(
    metrics: dict,
    building_type: str,
    profile: dict,
) -> list[str]:
    """Map sensor patterns onto concrete cleaning actions.

    Signals we read:
      - PM2.5 trend > 0      → dust accumulating; vacuum / wet-dust
      - PM2.5 spike count    → activity disturbing settled dust; HEPA + carpets
      - PM10/PM2.5 ratio     → coarse particle dominance; surface dust
      - humidity > 60% lots  → mold risk on surfaces; clean + dehumidify
      - baseline_pm25 high   → filter swap / outdoor source / kitchen residue
    """
    out: list[str] = []
    is_school = building_type == "school"
    label_lower = profile["label"].lower()

    trend = metrics.get("pm25_trend_per_hour")
    spikes = metrics.get("pm25_spike_count") or 0
    ratio = metrics.get("pm10_pm25_ratio")
    humid_fraction = metrics.get("humid_hours_fraction") or 0.0
    baseline = metrics.get("baseline_pm25")
    samples = metrics.get("samples") or 0

    # 1. Rising baseline = dust loading up over the window
    if trend is not None and trend > 0.3:
        if is_school:
            out.append(
                f"PM2.5 baseline is drifting up at ~{trend:.2f} µg/m³ per hour during "
                "the period. Schedule HEPA-vacuum of classroom carpets and a damp-mop "
                "of hard floors at end-of-day — particle load is accumulating between cleanings."
            )
        else:
            out.append(
                f"PM2.5 baseline is climbing at ~{trend:.2f} µg/m³ per hour. "
                "Dust and fine particles are settling on surfaces — run a HEPA vacuum on "
                "soft furnishings and wet-dust horizontal surfaces (shelves, lampshades, "
                "TV stand) within the next day."
            )

    # 2. Many spikes against a clean baseline → disturbed settled dust
    if samples >= 20 and spikes >= max(3, samples // 25):
        if is_school:
            out.append(
                f"Detected {spikes} PM2.5 spikes well above the clean-air baseline — "
                "consistent with floor traffic re-suspending settled dust. Coordinate "
                "with custodial staff to wet-mop hard floors before the school day "
                "and HEPA-vacuum carpets at least 2× weekly."
            )
        else:
            out.append(
                f"{spikes} PM2.5 spikes detected against an otherwise clean baseline. "
                "Likely cause: vacuuming, sweeping, or pets disturbing settled dust. "
                "Use a HEPA-filter vacuum (sealed-bag, not bagless) and wet-dust instead "
                "of feather dusters which just redistribute particles."
            )

    # 3. Coarse-particle dominance → surface dust, not combustion/smoke
    if ratio is not None and ratio > 3.0:
        out.append(
            f"PM10/PM2.5 ratio is {ratio:.1f} — coarse particles dominate, which usually "
            "means settled dust, sand or pollen rather than smoke. Focus cleaning on "
            "horizontal surfaces, blinds, and entry mats. " +
            ("Adding walk-off mats at school entries cuts tracked-in dust by 30–50%."
             if is_school else "")
        )

    # 4. Persistent high humidity = mold / dust-mite risk → clean + dehumidify
    if humid_fraction > 0.40:
        pct = int(humid_fraction * 100)
        if is_school:
            out.append(
                f"Humidity was above 60% for {pct}% of the period — inspect classroom "
                "corners, window sills and behind furniture for mold spots. Wash washable "
                "soft furnishings (curtains, cushion covers) and dry surfaces after wet-mopping."
            )
        else:
            out.append(
                f"Humidity sustained above 60% for {pct}% of the period creates mold "
                "and dust-mite breeding conditions. Wash bedding weekly in hot water (60°C+), "
                "wipe down bathroom and kitchen surfaces with mild detergent, and inspect "
                "behind furniture against exterior walls."
            )

    # 5. Elevated baseline even at quietest times → filter / kitchen / outdoor leak
    if baseline is not None and baseline > profile["pm25_baseline_limit"]:
        if is_school:
            out.append(
                "Quiet-time PM2.5 floor is above the children's-health target. Swap or "
                "wash any HVAC return-air filters and verify the supply-air filter rating "
                "(MERV 13 or higher recommended for classrooms)."
            )
        else:
            out.append(
                "Quiet-time PM2.5 stays elevated. Clean the range-hood filter (degrease "
                "monthly), replace HVAC / purifier filters, and check that exhaust vents "
                "in bathrooms and kitchen aren't blocked by lint or dust."
            )

    # 6. School-specific — disinfectant timing & high-traffic note
    if is_school:
        if not out:
            out.append(
                "Cleaning schedule appears adequate for current loading. Continue "
                "end-of-day HEPA vacuum + wet-mop and inspect entry-mats weekly."
            )
        else:
            out.append(
                "Schedule disinfectant fogging and chemical-heavy cleaning AFTER "
                "students leave, then ventilate the room for 30+ minutes before next-day occupancy."
            )

    return out


def building_recommend(
    window: dict,
    building_type: str = "home",
    occupancy: int | None = None,
    minutes_per_sample: float = 5.0,
) -> BuildingInsights:
    """Inspect a recent window of readings and surface BUILDING-level findings.

    `window` shape: {"pm25": [...], "pm10": [...], "co2": [...],
                     "temperature": [...], "humidity": [...]}
    Lists are chronological (oldest→newest). Missing keys are skipped.
    `minutes_per_sample`: caller-supplied (frontend knows the lookback span).
    """
    profile = BUILDING_PROFILES.get(building_type) or BUILDING_PROFILES["home"]
    metrics = _window_metrics(window, minutes_per_sample)

    advice: list[str] = []
    severity = "info"
    label = profile["label"]

    # PM2.5 baseline — the "what's left when the room is quiet"
    baseline = metrics["baseline_pm25"]
    if baseline is not None and baseline > profile["pm25_baseline_limit"]:
        severity = _bump(severity, "warning")
        if building_type == "school":
            advice.append(
                f"Baseline PM2.5 in this classroom is {baseline:.1f} µg/m³ even at the "
                f"quietest 10% of the period — above the {profile['pm25_baseline_limit']:.0f} "
                "µg/m³ target for children. Consider a HEPA purifier sized for the room and "
                "verify outdoor air-handling filters."
            )
        else:
            advice.append(
                f"Baseline PM2.5 is {baseline:.1f} µg/m³ even at the quietest times — "
                "suggests outdoor infiltration or an unvented combustion source "
                "(cooking, candles). Check window seals and use a range hood when cooking."
            )

    # CO2 — sustained over the building-specific cap = ventilation deficit
    co2_overlimit_key = "co2_overlimit_fraction_1100" if building_type == "school" \
        else "co2_overlimit_fraction_1000"
    over_fraction = metrics.get(co2_overlimit_key) or 0.0
    if over_fraction > profile["co2_overlimit_fraction"]:
        severity = _bump(severity, "warning" if over_fraction < 0.5 else "critical")
        pct = int(over_fraction * 100)
        if building_type == "school":
            advice.append(
                f"CO2 was above the ASHRAE classroom guideline of {profile['co2_limit']} ppm "
                f"for {pct}% of the period. Sustained levels above this cap correlate with "
                "drowsiness and measurable drops in test performance — open windows during "
                "breaks, or schedule HVAC service if the room is mechanically ventilated."
            )
        else:
            advice.append(
                f"CO2 was above {profile['co2_limit']} ppm for {pct}% of the period. "
                "That's an indicator that fresh-air supply is undersized for typical occupancy. "
                "Cracking a window for 10 minutes every couple of hours, or adding a small "
                "ventilation fan, usually fixes it."
            )

    # ACH from CO2 decay — direct measure of how well the room breathes
    ach = metrics["ach_estimate"]
    if ach is not None and ach < profile["ach_min"]:
        severity = _bump(severity, "warning")
        advice.append(
            f"Estimated air-changes-per-hour ≈ {ach:.2f} (target ≥ {profile['ach_min']:.2f} "
            f"for {label.lower()}). The room takes a long time to clear CO2 after people "
            "leave — likely under-ventilated."
        )

    # Humidity hours — mold and respiratory risk
    humid_fraction = metrics["humid_hours_fraction"] or 0.0
    if humid_fraction > profile["humidity_high_fraction_limit"]:
        severity = _bump(severity, "warning")
        pct = int(humid_fraction * 100)
        advice.append(
            f"Indoor humidity was above 60% for {pct}% of the period. Sustained "
            "high humidity promotes mold and dust-mite growth — improve ventilation "
            "or run a dehumidifier. " +
            ("Schools should also inspect for condensation on cold walls/windows."
             if building_type == "school" else "")
        )

    dry_fraction = metrics["dry_hours_fraction"] or 0.0
    if dry_fraction > profile["humidity_low_fraction_limit"]:
        pct = int(dry_fraction * 100)
        advice.append(
            f"Indoor humidity was below 30% for {pct}% of the period. Dry air "
            "irritates airways and increases viral transmission — consider a humidifier "
            "or reduce heating overshoot."
        )

    # Temperature comfort band
    t_lo, t_hi = profile["temperature_target"]
    median_t = _percentile(_clean(window.get("temperature")), 50)
    swing = metrics["temperature_swing"]
    if median_t is not None and (median_t < t_lo or median_t > t_hi):
        side = "below" if median_t < t_lo else "above"
        advice.append(
            f"Median temperature {median_t:.1f}°C is {side} the comfort band "
            f"{t_lo:.0f}–{t_hi:.0f}°C for {label.lower()}. "
            + ("Cold classrooms are linked to slower cognitive performance."
               if building_type == "school" and median_t < t_lo
               else "Adjust HVAC setpoint or check insulation.")
        )
    if swing is not None and swing > 7:
        advice.append(
            f"Temperature swung by {swing:.1f}°C across the period — suggests poor "
            "thermal mass or insulation. Sustained swings make HVAC work harder and "
            "create draft complaints."
        )

    # Occupancy + CO2 cross-check
    if occupancy is not None and occupancy > 0 and metrics["median_co2"] is not None:
        co2_per_person = metrics["median_co2"] / max(occupancy, 1)
        if co2_per_person > 250:
            advice.append(
                f"CO2 per person is {co2_per_person:.0f} ppm — fresh-air supply is "
                "lagging behind occupancy."
            )

    if not advice:
        advice.append(
            f"No structural issues detected from the window. The {label.lower()} "
            "is performing within targets for ventilation, humidity, and PM2.5 baseline."
        )

    cleaning = _cleaning_advice(metrics, building_type, profile)
    if not cleaning:
        cleaning.append(
            "Cleaning loading looks normal. Routine vacuuming, wet-dusting and bedding "
            "wash schedules are sufficient — no signal of accumulating dust or moisture."
        )

    return BuildingInsights(
        building_type=building_type,
        label=label,
        metrics=metrics,
        advice=advice,
        cleaning_advice=cleaning,
        severity=severity,
    )
