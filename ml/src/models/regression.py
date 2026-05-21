"""
Regression models for AQI / pollutant concentration prediction.

Models:
  - LinearRegression
  - Ridge (GridSearchCV over alpha)
  - Lasso (GridSearchCV over alpha)
  - Polynomial + Ridge (degree 2 and 3)
  - RandomForestRegressor
  - SVR (RBF kernel)
  - XGBRegressor (Gradient Boosting)
"""

from __future__ import annotations

from pathlib import Path

import joblib
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.linear_model import Lasso, LinearRegression, Ridge
from sklearn.model_selection import GridSearchCV, TimeSeriesSplit
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import PolynomialFeatures
from sklearn.svm import SVR
from xgboost import XGBRegressor

MODELS_DIR = Path(__file__).parent.parent.parent / "models"

# TimeSeriesSplit avoids data leakage in cross-validation
CV = TimeSeriesSplit(n_splits=5)


def train_linear(X_train, y_train) -> LinearRegression:
    model = LinearRegression()
    model.fit(X_train, y_train)
    return model


def train_ridge(X_train, y_train) -> GridSearchCV:
    grid = GridSearchCV(
        Ridge(),
        param_grid={"alpha": [0.01, 0.1, 1, 10, 100]},
        cv=CV,
        scoring="neg_root_mean_squared_error",
        n_jobs=-1,
    )
    grid.fit(X_train, y_train)
    return grid


def train_lasso(X_train, y_train) -> GridSearchCV:
    grid = GridSearchCV(
        Lasso(max_iter=5000),
        param_grid={"alpha": [0.001, 0.01, 0.1, 1, 10]},
        cv=CV,
        scoring="neg_root_mean_squared_error",
        n_jobs=-1,
    )
    grid.fit(X_train, y_train)
    return grid


def train_polynomial(X_train, y_train, degree: int = 2) -> Pipeline:
    pipe = Pipeline(
        [
            ("poly", PolynomialFeatures(degree=degree, include_bias=False)),
            ("ridge", Ridge(alpha=1.0)),
        ]
    )
    pipe.fit(X_train, y_train)
    return pipe


def train_random_forest(X_train, y_train) -> GridSearchCV:
    grid = GridSearchCV(
        RandomForestRegressor(random_state=42),
        param_grid={
            "n_estimators": [100, 300],
            "max_depth": [None, 10, 20],
            "min_samples_leaf": [1, 5],
        },
        cv=CV,
        scoring="neg_root_mean_squared_error",
        n_jobs=-1,
    )
    grid.fit(X_train, y_train)
    return grid


def train_svr(X_train, y_train) -> GridSearchCV:
    grid = GridSearchCV(
        SVR(kernel="rbf"),
        param_grid={
            "C": [0.1, 1, 10],
            "epsilon": [0.1, 0.5],
            "gamma": ["scale"],
        },
        cv=CV,
        scoring="neg_root_mean_squared_error",
        n_jobs=-1,
    )
    grid.fit(X_train, y_train)
    return grid


def train_xgboost(X_train, y_train) -> XGBRegressor:
    model = XGBRegressor(
        n_estimators=300,
        max_depth=6,
        learning_rate=0.05,
        subsample=0.8,
        colsample_bytree=0.8,
        random_state=42,
        n_jobs=-1,
        verbosity=0,
    )
    model.fit(X_train, y_train)
    return model


def train_all(
    X_train, y_train, save: bool = True
) -> dict[str, object]:
    """Train all regression models and optionally persist them."""
    models = {
        "Linear Regression": train_linear(X_train, y_train),
        "Ridge Regression": train_ridge(X_train, y_train),
        "Lasso Regression": train_lasso(X_train, y_train),
        "Polynomial Regression (deg=2)": train_polynomial(X_train, y_train, degree=2),
        "Polynomial Regression (deg=3)": train_polynomial(X_train, y_train, degree=3),
        "Random Forest": train_random_forest(X_train, y_train),
        "SVR (RBF)": train_svr(X_train, y_train),
        "XGBoost": train_xgboost(X_train, y_train),
    }

    if save:
        MODELS_DIR.mkdir(parents=True, exist_ok=True)
        for name, model in models.items():
            fname = name.lower().replace(" ", "_").replace("(", "").replace(")", "").replace("=", "") + "_reg.joblib"
            joblib.dump(model, MODELS_DIR / fname)

    return models


def feature_importance(model, feature_names: list[str]) -> dict[str, float]:
    """Extract feature importances from tree-based models."""
    est = getattr(model, "best_estimator_", model)
    if hasattr(est, "feature_importances_"):
        return dict(zip(feature_names, est.feature_importances_))
    if hasattr(est, "coef_"):
        return dict(zip(feature_names, np.abs(est.coef_)))
    return {}
