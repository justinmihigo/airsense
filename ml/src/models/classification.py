"""
Classification models for AQI category and binary alert prediction.

Models:
  - LogisticRegression
  - RandomForestClassifier
  - SVC (probability=True for ROC-AUC)
  - XGBClassifier (Gradient Boosting)
"""

from __future__ import annotations

from pathlib import Path

import joblib
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import GridSearchCV, TimeSeriesSplit
from sklearn.svm import SVC
from xgboost import XGBClassifier

MODELS_DIR = Path(__file__).parent.parent.parent / "models"
CV = TimeSeriesSplit(n_splits=5)


def train_logistic(X_train, y_train) -> GridSearchCV:
    grid = GridSearchCV(
        LogisticRegression(solver="lbfgs", max_iter=1000),
        param_grid={"C": [0.01, 0.1, 1, 10]},
        cv=CV,
        scoring="f1_macro",
        n_jobs=-1,
    )
    grid.fit(X_train, y_train)
    return grid


def train_random_forest(X_train, y_train) -> GridSearchCV:
    grid = GridSearchCV(
        RandomForestClassifier(random_state=42, class_weight="balanced"),
        param_grid={
            "n_estimators": [100, 300],
            "max_depth": [None, 10, 20],
        },
        cv=CV,
        scoring="f1_macro",
        n_jobs=-1,
    )
    grid.fit(X_train, y_train)
    return grid


def train_svc(X_train, y_train) -> GridSearchCV:
    grid = GridSearchCV(
        SVC(probability=True, class_weight="balanced"),
        param_grid={
            "C": [0.1, 1, 10],
            "kernel": ["rbf", "linear"],
        },
        cv=CV,
        scoring="f1_macro",
        n_jobs=-1,
    )
    grid.fit(X_train, y_train)
    return grid


def train_xgboost(X_train, y_train) -> XGBClassifier:
    n_classes = len(np.unique(y_train))
    model = XGBClassifier(
        n_estimators=300,
        max_depth=6,
        learning_rate=0.05,
        subsample=0.8,
        colsample_bytree=0.8,
        random_state=42,
        n_jobs=-1,
        verbosity=0,
        use_label_encoder=False,
        objective="multi:softprob" if n_classes > 2 else "binary:logistic",
        num_class=n_classes if n_classes > 2 else None,
        eval_metric="mlogloss" if n_classes > 2 else "logloss",
    )
    model.fit(X_train, y_train)
    return model


def train_all(X_train, y_train, save: bool = True) -> dict[str, object]:
    models = {
        "Logistic Regression": train_logistic(X_train, y_train),
        "Random Forest": train_random_forest(X_train, y_train),
        "SVC (RBF)": train_svc(X_train, y_train),
        "XGBoost": train_xgboost(X_train, y_train),
    }

    if save:
        MODELS_DIR.mkdir(parents=True, exist_ok=True)
        for name, model in models.items():
            fname = name.lower().replace(" ", "_").replace("(", "").replace(")", "") + "_clf.joblib"
            joblib.dump(model, MODELS_DIR / fname)

    return models
