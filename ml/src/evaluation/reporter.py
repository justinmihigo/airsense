"""
Report builder — aggregates per-model metrics into comparison DataFrames
and writes a Markdown summary to reports/model_comparison_report.md.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

REPORTS_DIR = Path(__file__).parent.parent.parent / "reports"


def build_regression_df(results: dict[str, dict]) -> pd.DataFrame:
    """Build a sorted comparison table from {model_name: metrics_dict}."""
    rows = []
    for name, m in results.items():
        rows.append(
            {
                "Model": name,
                "MAE": round(m.get("MAE", float("nan")), 4),
                "RMSE": round(m.get("RMSE", float("nan")), 4),
                "R²": round(m.get("R2", float("nan")), 4),
                "MAPE (%)": round(m.get("MAPE", float("nan")), 2),
            }
        )
    df = pd.DataFrame(rows).sort_values("RMSE").reset_index(drop=True)
    df.index += 1
    return df


def build_classification_df(results: dict[str, dict]) -> pd.DataFrame:
    rows = []
    for name, m in results.items():
        rows.append(
            {
                "Model": name,
                "Accuracy": round(m.get("Accuracy", float("nan")), 4),
                "Precision": round(m.get("Precision", float("nan")), 4),
                "Recall": round(m.get("Recall", float("nan")), 4),
                "F1": round(m.get("F1", float("nan")), 4),
                "ROC-AUC": round(m.get("ROC_AUC") or float("nan"), 4),
            }
        )
    df = pd.DataFrame(rows).sort_values("F1", ascending=False).reset_index(drop=True)
    df.index += 1
    return df


def build_forecasting_df(results: dict[str, dict]) -> pd.DataFrame:
    rows = []
    for name, m in results.items():
        rows.append(
            {
                "Model": name,
                "MAE": round(m.get("MAE", float("nan")), 4),
                "RMSE": round(m.get("RMSE", float("nan")), 4),
                "SMAPE (%)": round(m.get("SMAPE", float("nan")), 2),
                "MASE": round(m.get("MASE", float("nan")), 4),
            }
        )
    df = pd.DataFrame(rows).sort_values("MASE").reset_index(drop=True)
    df.index += 1
    return df


def _df_to_md(df: pd.DataFrame) -> str:
    return df.to_markdown(index=True)


def save_report(
    reg_results: dict[str, dict],
    clf_results: dict[str, dict],
    forecast_results: dict[str, dict] | None = None,
    target_name: str = "AQI",
    output_path: Path | None = None,
) -> Path:
    """Write a Markdown report comparing all models."""
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    if output_path is None:
        output_path = REPORTS_DIR / "model_comparison_report.md"

    reg_df = build_regression_df(reg_results)
    clf_df = build_classification_df(clf_results)

    best_reg = reg_df.iloc[0]["Model"]
    best_clf = clf_df.iloc[0]["Model"]

    lines = [
        "# AirSense ML — Model Comparison Report",
        "",
        f"**Target (Regression):** {target_name}  ",
        "**Target (Classification):** AQI Category (6-class) + Status (binary)",
        "",
        "---",
        "",
        "## 1. Regression Results",
        "",
        "| Metric | Formula |",
        "|--------|---------|",
        "| MAE    | (1/n) Σ \\|y - ŷ\\|  |",
        "| RMSE   | √[(1/n) Σ (y - ŷ)²] |",
        "| R²     | 1 − SS_res / SS_tot  |",
        "| MAPE   | (100/n) Σ \\|y − ŷ\\| / max(\\|y\\|, ε) |",
        "",
        _df_to_md(reg_df),
        "",
        f"> **Best regressor:** {best_reg} (lowest RMSE)",
        "",
        "---",
        "",
        "## 2. Classification Results",
        "",
        "| Metric    | Formula |",
        "|-----------|---------|",
        "| Accuracy  | (TP+TN) / N |",
        "| Precision | TP / (TP+FP) [macro] |",
        "| Recall    | TP / (TP+FN) [macro] |",
        "| F1        | 2·P·R / (P+R) [macro] |",
        "| ROC-AUC   | Area under ROC curve (OvR) |",
        "",
        _df_to_md(clf_df),
        "",
        f"> **Best classifier:** {best_clf} (highest F1)",
        "",
        "---",
        "",
    ]

    if forecast_results:
        fc_df = build_forecasting_df(forecast_results)
        best_fc = fc_df.iloc[0]["Model"]
        lines += [
            "## 3. Forecasting Results",
            "",
            "| Metric  | Formula |",
            "|---------|---------|",
            "| SMAPE   | (200/n) Σ \\|y−ŷ\\| / (\\|y\\|+\\|ŷ\\|+ε) |",
            "| MASE    | MAE / (naive MAE) |",
            "",
            _df_to_md(fc_df),
            "",
            f"> **Best forecaster:** {best_fc} (lowest MASE)",
            "",
            "---",
            "",
        ]

    lines += [
        "## Summary",
        "",
        f"- **Regression winner:** {best_reg}",
        f"- **Classification winner:** {best_clf}",
    ]
    if forecast_results:
        fc_df = build_forecasting_df(forecast_results)
        lines.append(f"- **Forecasting winner:** {fc_df.iloc[0]['Model']}")

    lines += [
        "",
        "_Report auto-generated by `src/evaluation/reporter.py`_",
    ]

    output_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"Report saved to {output_path}")
    return output_path
