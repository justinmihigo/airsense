"""
Time-series forecasting for AQI and PM2.5.

Models:
  - SARIMA  (statsmodels, auto-order selection via AIC grid)
  - Prophet (Facebook/Meta Prophet with daily seasonality)

Both return predictions with confidence intervals.
"""

from __future__ import annotations

import warnings
from itertools import product

import numpy as np
import pandas as pd

with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    from statsmodels.tsa.statespace.sarimax import SARIMAX


def _auto_arima_aic(
    series: pd.Series,
    p_range=range(0, 3),
    d_range=range(0, 2),
    q_range=range(0, 3),
    seasonal: bool = False,
    m: int = 24,
) -> tuple[int, int, int]:
    """Minimal AIC-based order search for ARIMA(p,d,q)."""
    best_aic = np.inf
    best_order = (1, 1, 1)
    for p, d, q in product(p_range, d_range, q_range):
        try:
            model = SARIMAX(series, order=(p, d, q), trend="n")
            res = model.fit(disp=False)
            if res.aic < best_aic:
                best_aic = res.aic
                best_order = (p, d, q)
        except Exception:
            continue
    return best_order


class SarimaForecaster:
    """Wrapper around statsmodels SARIMAX for one-step and multi-step forecasting."""

    def __init__(self, order: tuple | None = None, seasonal_order: tuple = (0, 0, 0, 0)):
        self.order = order
        self.seasonal_order = seasonal_order
        self._result = None
        self._series = None

    def fit(self, series: pd.Series, auto_order: bool = True) -> "SarimaForecaster":
        self._series = series
        if auto_order or self.order is None:
            print("  Running ARIMA order search (this may take a minute)…")
            self.order = _auto_arima_aic(series)
            print(f"  Best ARIMA order: {self.order}")

        model = SARIMAX(
            series,
            order=self.order,
            seasonal_order=self.seasonal_order,
            trend="n",
        )
        self._result = model.fit(disp=False)
        return self

    def predict(self, steps: int) -> pd.DataFrame:
        """Return forecast DataFrame with columns [mean, lower_ci, upper_ci]."""
        fc = self._result.get_forecast(steps=steps)
        summary = fc.summary_frame(alpha=0.05)
        return pd.DataFrame(
            {
                "mean": summary["mean"].values,
                "lower_ci": summary["mean_ci_lower"].values,
                "upper_ci": summary["mean_ci_upper"].values,
            }
        )

    def predict_with_new_series(self, series: pd.Series, steps: int) -> pd.DataFrame:
        """Forecast using the saved coefficients but anchored to a NEW series.

        Calls `result.apply(new_series, refit=False)` so the trained AR/MA/σ²
        are kept and only the latent state is updated to match the live data.
        This is the textbook "pre-trained time-series model on new data" pattern
        — far better than re-estimating coefficients from a short live window.
        """
        if self._result is None:
            raise RuntimeError("SarimaForecaster has not been fit yet.")
        result = self._result.apply(series, refit=False)
        fc = result.get_forecast(steps=steps)
        summary = fc.summary_frame(alpha=0.05)
        return pd.DataFrame(
            {
                "mean": summary["mean"].values,
                "lower_ci": summary["mean_ci_lower"].values,
                "upper_ci": summary["mean_ci_upper"].values,
            }
        )

    def evaluate(self, y_test: np.ndarray) -> dict[str, float]:
        from src.evaluation.metrics import forecasting_metrics
        steps = len(y_test)
        fc = self.predict(steps)
        return forecasting_metrics(y_test, fc["mean"].values)


class ProphetForecaster:
    """Wrapper around Facebook Prophet for air quality forecasting."""

    def __init__(self, yearly_seasonality: bool = False, weekly_seasonality: bool = True):
        self.yearly_seasonality = yearly_seasonality
        self.weekly_seasonality = weekly_seasonality
        self._model = None

    def fit(self, df: pd.DataFrame, ds_col: str = "TIME", y_col: str = "PM25") -> "ProphetForecaster":
        """Fit Prophet. df must have a datetime column and a numeric target column."""
        try:
            from prophet import Prophet
        except ImportError:
            raise ImportError("Install prophet: pip install prophet")

        train = df[[ds_col, y_col]].rename(columns={ds_col: "ds", y_col: "y"}).copy()
        train["ds"] = pd.to_datetime(train["ds"]).dt.tz_localize(None)  # Prophet needs tz-naive
        train = train.dropna()

        self._model = Prophet(
            yearly_seasonality=self.yearly_seasonality,
            weekly_seasonality=self.weekly_seasonality,
            daily_seasonality=True,
            interval_width=0.95,
        )
        self._model.fit(train)
        self._train = train
        return self

    def predict(self, periods: int, freq: str = "20s") -> pd.DataFrame:
        """Return future forecast DataFrame with [ds, yhat, yhat_lower, yhat_upper]."""
        future = self._model.make_future_dataframe(periods=periods, freq=freq)
        fc = self._model.predict(future)
        return fc[["ds", "yhat", "yhat_lower", "yhat_upper"]].tail(periods).reset_index(drop=True)

    def evaluate(self, y_test: np.ndarray, periods: int | None = None) -> dict[str, float]:
        from src.evaluation.metrics import forecasting_metrics
        if periods is None:
            periods = len(y_test)
        fc = self.predict(periods)
        return forecasting_metrics(y_test, fc["yhat"].values[: len(y_test)])
