"""
Evaluation metrics for regression, classification, and time-series forecasting.

Formulas
--------
Regression:
  MAE  = (1/n) Σ |y_i - ŷ_i|
  MSE  = (1/n) Σ (y_i - ŷ_i)²
  RMSE = √MSE
  R²   = 1 - Σ(y_i - ŷ_i)² / Σ(y_i - ȳ)²
  MAPE = (100/n) Σ |y_i - ŷ_i| / max(|y_i|, ε)

Classification:
  Accuracy  = (TP + TN) / N
  Precision = TP / (TP + FP)          [macro-averaged]
  Recall    = TP / (TP + FN)          [macro-averaged]
  F1        = 2·Precision·Recall / (Precision + Recall)  [macro]
  ROC-AUC   = area under ROC curve (OvR for multiclass)

Time-series:
  SMAPE = (200/n) Σ |y_i - ŷ_i| / (|y_i| + |ŷ_i| + ε)
  MASE  = MAE / (1/(n-1) Σ |y_i - y_{i-1}|)   [naive benchmark]
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    f1_score,
    mean_absolute_error,
    mean_squared_error,
    precision_score,
    r2_score,
    recall_score,
    roc_auc_score,
)


def regression_metrics(y_true: np.ndarray, y_pred: np.ndarray) -> dict[str, float]:
    y_true = np.asarray(y_true, dtype=float)
    y_pred = np.asarray(y_pred, dtype=float)
    eps = 1e-8

    mae = mean_absolute_error(y_true, y_pred)
    mse = mean_squared_error(y_true, y_pred)
    rmse = float(np.sqrt(mse))
    r2 = r2_score(y_true, y_pred)
    mape = float(np.mean(np.abs(y_true - y_pred) / np.maximum(np.abs(y_true), eps)) * 100)

    return {"MAE": mae, "MSE": mse, "RMSE": rmse, "R2": r2, "MAPE": mape}


def classification_metrics(
    y_true: np.ndarray,
    y_pred: np.ndarray,
    y_prob: np.ndarray | None = None,
    average: str = "macro",
) -> dict:
    y_true = np.asarray(y_true)
    y_pred = np.asarray(y_pred)

    acc = accuracy_score(y_true, y_pred)
    prec = precision_score(y_true, y_pred, average=average, zero_division=0)
    rec = recall_score(y_true, y_pred, average=average, zero_division=0)
    f1 = f1_score(y_true, y_pred, average=average, zero_division=0)
    cm = confusion_matrix(y_true, y_pred)

    roc_auc = None
    if y_prob is not None:
        try:
            classes = np.unique(y_true)
            multi = "ovr" if len(classes) > 2 else "raise"
            roc_auc = roc_auc_score(
                y_true, y_prob, multi_class=multi, average=average, labels=classes
            )
        except Exception:
            pass

    return {
        "Accuracy": acc,
        "Precision": prec,
        "Recall": rec,
        "F1": f1,
        "ROC_AUC": roc_auc,
        "Confusion_Matrix": cm,
    }


def smape(y_true: np.ndarray, y_pred: np.ndarray) -> float:
    """Symmetric Mean Absolute Percentage Error (0-100 %)."""
    y_true = np.asarray(y_true, dtype=float)
    y_pred = np.asarray(y_pred, dtype=float)
    eps = 1e-8
    return float(
        200 * np.mean(np.abs(y_true - y_pred) / (np.abs(y_true) + np.abs(y_pred) + eps))
    )


def mase(y_true: np.ndarray, y_pred: np.ndarray) -> float:
    """Mean Absolute Scaled Error benchmarked against naive (t-1) forecast."""
    y_true = np.asarray(y_true, dtype=float)
    y_pred = np.asarray(y_pred, dtype=float)
    naive_mae = np.mean(np.abs(np.diff(y_true)))
    if naive_mae < 1e-8:
        return float("nan")
    return float(mean_absolute_error(y_true, y_pred) / naive_mae)


def forecasting_metrics(y_true: np.ndarray, y_pred: np.ndarray) -> dict[str, float]:
    return {
        "MAE": mean_absolute_error(y_true, y_pred),
        "RMSE": float(np.sqrt(mean_squared_error(y_true, y_pred))),
        "SMAPE": smape(y_true, y_pred),
        "MASE": mase(y_true, y_pred),
    }
