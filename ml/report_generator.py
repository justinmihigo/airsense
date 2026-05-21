"""
Generates the AirSense project report as a PDF for academic / supervisor review.

Run from the ml/ directory:
    .venv/bin/python report_generator.py

Output: ../AirSense_Project_Report.pdf
"""

from __future__ import annotations

import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from fpdf import FPDF
from fpdf.enums import XPos, YPos
from fpdf.fonts import FontFace

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

HERE = os.path.dirname(os.path.abspath(__file__))
FIG_DIR = os.path.join(HERE, "reports", "figures")
OUT_PDF = os.path.join(HERE, "..", "AirSense_Project_Report.pdf")
FONT_DIR = os.path.join(
    os.path.dirname(matplotlib.__file__), "mpl-data", "fonts", "ttf"
)
os.makedirs(FIG_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Brand colours
# ---------------------------------------------------------------------------

GREEN = (34, 197, 94)
DARK_GREEN = (22, 101, 52)
HEADING = (31, 41, 55)
BODY = (55, 65, 81)
LIGHT = (243, 244, 246)
WHITE = (255, 255, 255)

# ---------------------------------------------------------------------------
# Model results (from reports/model_comparison_report.md)
# ---------------------------------------------------------------------------

REGRESSION = [
    # rank, model, MAE, RMSE, R2, MAPE
    (1, "Polynomial Regression (deg 3)", 0.2412, 0.3595, 0.9999, 0.67),
    (2, "XGBoost", 0.0972, 0.3702, 0.9999, 0.14),
    (3, "Polynomial Regression (deg 2)", 1.9065, 2.9255, 0.9911, 4.96),
    (4, "Random Forest", 0.4386, 4.1346, 0.9823, 0.28),
    (5, "Ridge Regression", 6.2612, 10.8908, 0.8773, 14.52),
    (6, "Linear Regression", 6.7183, 11.1676, 0.8710, 15.41),
    (7, "Lasso Regression", 7.9468, 12.7341, 0.8322, 18.41),
    (8, "SVR (RBF kernel)", 11.2331, 15.1364, 0.7630, 27.90),
]

CLASSIFICATION = [
    # rank, model, Acc, Prec, Rec, F1, ROC-AUC
    (1, "Random Forest", 1.0000, 1.0000, 1.0000, 1.0000, 1.0000),
    (2, "XGBoost", 1.0000, 1.0000, 1.0000, 1.0000, 1.0000),
    (3, "SVC (RBF kernel)", 0.9976, 0.9722, 0.9996, 0.9846, 1.0000),
    (4, "Logistic Regression", 0.9960, 0.9855, 0.9458, 0.9638, 0.9998),
]


# ---------------------------------------------------------------------------
# Charts
# ---------------------------------------------------------------------------

def make_charts() -> tuple[str, str]:
    plt.rcParams.update({
        "font.size": 10,
        "axes.edgecolor": "#d1d5db",
        "axes.labelcolor": "#374151",
        "text.color": "#374151",
        "xtick.color": "#6b7280",
        "ytick.color": "#374151",
    })

    # --- Regression RMSE ---
    reg = sorted(REGRESSION, key=lambda r: r[3], reverse=True)
    names = [r[1] for r in reg]
    rmse = [r[3] for r in reg]
    colors = ["#22C55E" if v <= 0.4 else "#9ca3af" for v in rmse]

    fig, ax = plt.subplots(figsize=(8.4, 3.6))
    bars = ax.barh(names, rmse, color=colors, height=0.62)
    ax.set_xlabel("RMSE  (AQI units) — lower is better")
    ax.set_title("Regression Model Comparison — Root Mean Square Error",
                 fontsize=11, fontweight="bold", color="#1f2937", pad=10)
    ax.grid(axis="x", color="#f3f4f6", linewidth=0.8)
    ax.set_axisbelow(True)
    for spine in ("top", "right"):
        ax.spines[spine].set_visible(False)
    for bar, v in zip(bars, rmse):
        ax.text(v + 0.25, bar.get_y() + bar.get_height() / 2,
                f"{v:.2f}", va="center", fontsize=8.5, color="#374151")
    fig.tight_layout()
    reg_path = os.path.join(FIG_DIR, "regression_rmse.png")
    fig.savefig(reg_path, dpi=150)
    plt.close(fig)

    # --- Classification F1 ---
    clf = sorted(CLASSIFICATION, key=lambda r: r[5])
    cnames = [r[1] for r in clf]
    f1 = [r[5] for r in clf]
    ccolors = ["#22C55E" if v >= 0.999 else "#9ca3af" for v in f1]

    fig, ax = plt.subplots(figsize=(8.4, 2.7))
    bars = ax.barh(cnames, f1, color=ccolors, height=0.55)
    ax.set_xlim(0.90, 1.02)
    ax.set_xlabel("F1 Score (macro) — higher is better")
    ax.set_title("Classification Model Comparison — F1 Score",
                 fontsize=11, fontweight="bold", color="#1f2937", pad=10)
    ax.grid(axis="x", color="#f3f4f6", linewidth=0.8)
    ax.set_axisbelow(True)
    for spine in ("top", "right"):
        ax.spines[spine].set_visible(False)
    for bar, v in zip(bars, f1):
        ax.text(v + 0.002, bar.get_y() + bar.get_height() / 2,
                f"{v:.4f}", va="center", fontsize=8.5, color="#374151")
    fig.tight_layout()
    clf_path = os.path.join(FIG_DIR, "classification_f1.png")
    fig.savefig(clf_path, dpi=150)
    plt.close(fig)

    return reg_path, clf_path


# ---------------------------------------------------------------------------
# PDF document
# ---------------------------------------------------------------------------

class Report(FPDF):
    def __init__(self) -> None:
        super().__init__(orientation="P", unit="mm", format="A4")
        self.set_margins(20, 20, 20)
        self.set_auto_page_break(True, margin=20)
        self.add_font("DejaVu", "", os.path.join(FONT_DIR, "DejaVuSans.ttf"))
        self.add_font("DejaVu", "B", os.path.join(FONT_DIR, "DejaVuSans-Bold.ttf"))
        self.add_font("DejaVu", "I", os.path.join(FONT_DIR, "DejaVuSans-Oblique.ttf"))

    # -- auto header / footer (skipped on the cover) --
    def header(self) -> None:
        if self.page_no() == 1:
            return
        self.set_font("DejaVu", "", 8)
        self.set_text_color(*GREEN)
        self.cell(0, 6, "AirSense  —  Indoor Air Quality Monitoring System",
                  new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_draw_color(229, 231, 235)
        self.set_line_width(0.3)
        self.line(self.l_margin, 26, self.w - self.r_margin, 26)
        self.ln(6)

    def footer(self) -> None:
        if self.page_no() == 1:
            return
        self.set_y(-15)
        self.set_font("DejaVu", "", 8)
        self.set_text_color(156, 163, 175)
        self.cell(0, 8, f"Page {self.page_no() - 1}", align="C")

    # -- content helpers --
    def body(self, text: str) -> None:
        self.set_font("DejaVu", "", 10.5)
        self.set_text_color(*BODY)
        self.multi_cell(self.epw, 5.7, text, align="J",
                        new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.ln(2.4)

    def bullets(self, items: list[str]) -> None:
        for it in items:
            if self.get_y() > self.h - 30:
                self.add_page()
            self.set_font("DejaVu", "B", 10.5)
            self.set_text_color(*GREEN)
            self.cell(6, 5.7, "•")
            self.set_font("DejaVu", "", 10.5)
            self.set_text_color(*BODY)
            self.multi_cell(self.epw - 6, 5.7, it, align="J",
                            new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            self.ln(1.2)
        self.ln(1.4)

    def lead_bullets(self, items: list[tuple[str, str]]) -> None:
        """Bullets with a bold lead phrase followed by explanatory text."""
        for lead, rest in items:
            if self.get_y() > self.h - 32:
                self.add_page()
            self.set_font("DejaVu", "B", 10.5)
            self.set_text_color(*GREEN)
            self.cell(6, 5.7, "•")
            self.set_font("DejaVu", "B", 10.5)
            self.set_text_color(*HEADING)
            self.multi_cell(self.epw - 6, 5.7, lead,
                            new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            self.set_x(self.l_margin + 6)
            self.set_font("DejaVu", "", 10.5)
            self.set_text_color(*BODY)
            self.multi_cell(self.epw - 6, 5.7, rest, align="J",
                            new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            self.ln(2.2)

    def section(self, num: int, title: str) -> None:
        if self.get_y() > self.h - 48:
            self.add_page()
        self.ln(3)
        self.set_font("DejaVu", "B", 14)
        self.set_text_color(*DARK_GREEN)
        self.cell(0, 9, f"{num}.  {title}",
                  new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_draw_color(*GREEN)
        self.set_line_width(0.7)
        y = self.get_y() + 0.6
        self.line(self.l_margin, y, self.l_margin + 38, y)
        self.ln(4.5)

    def subsection(self, title: str) -> None:
        if self.get_y() > self.h - 36:
            self.add_page()
        self.ln(1.4)
        self.set_font("DejaVu", "B", 11)
        self.set_text_color(*HEADING)
        self.cell(0, 7, title, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.ln(1.4)

    def formula(self, text: str, caption: str = "") -> None:
        if self.get_y() > self.h - 28:
            self.add_page()
        self.set_font("DejaVu", "", 10)
        self.set_text_color(17, 24, 39)
        self.set_fill_color(*LIGHT)
        self.multi_cell(self.epw, 7.4, "    " + text, fill=True,
                        new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        if caption:
            self.set_font("DejaVu", "I", 8.6)
            self.set_text_color(107, 114, 128)
            self.multi_cell(self.epw, 4.6, "    " + caption,
                            new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.ln(2.6)

    def quote(self, text: str) -> None:
        """A highlighted callout box."""
        if self.get_y() > self.h - 40:
            self.add_page()
        self.set_font("DejaVu", "I", 10.5)
        self.set_text_color(*DARK_GREEN)
        self.set_fill_color(240, 253, 244)
        x0, y0 = self.get_x(), self.get_y()
        self.multi_cell(self.epw, 6, text, fill=True, align="L",
                        new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_draw_color(*GREEN)
        self.set_line_width(1.4)
        self.line(x0 + 0.7, y0, x0 + 0.7, self.get_y())
        self.ln(3.5)


def build_pdf(reg_chart: str, clf_chart: str) -> None:
    pdf = Report()

    # ===================== COVER =====================
    pdf.add_page()
    pdf.set_fill_color(*GREEN)
    pdf.rect(0, 0, pdf.w, 78, "F")
    pdf.set_xy(20, 24)
    pdf.set_font("DejaVu", "B", 34)
    pdf.set_text_color(*WHITE)
    pdf.cell(0, 16, "AirSense", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.set_x(20)
    pdf.set_font("DejaVu", "", 13)
    pdf.cell(0, 9, "Indoor Air Quality Monitoring System for Shared Spaces",
             new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_xy(20, 104)
    pdf.set_font("DejaVu", "B", 21)
    pdf.set_text_color(*HEADING)
    pdf.multi_cell(pdf.epw, 10,
                   "Project Report: Design, Machine Learning Pipeline, "
                   "and Comparative Model Evaluation",
                   new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.ln(4)
    pdf.set_x(20)
    pdf.set_font("DejaVu", "", 11)
    pdf.set_text_color(*BODY)
    pdf.multi_cell(pdf.epw, 6,
                   "An IoT-based system that measures, predicts, and "
                   "interprets indoor air quality — with a focus on "
                   "classrooms and other crowded indoor environments.",
                   new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    # metadata block
    pdf.set_xy(20, 168)
    pdf.set_draw_color(*GREEN)
    pdf.set_line_width(0.6)
    pdf.line(20, 166, pdf.w - 20, 166)
    meta = [
        ("Prepared for", "Project Supervisor"),
        ("Prepared by", "Justin Mihigo"),
        ("Document type", "Academic Project Report"),
        ("Date", "May 2026"),
    ]
    for label, value in meta:
        pdf.set_x(20)
        pdf.set_font("DejaVu", "B", 10.5)
        pdf.set_text_color(*DARK_GREEN)
        pdf.cell(45, 8, label)
        pdf.set_font("DejaVu", "", 10.5)
        pdf.set_text_color(*BODY)
        pdf.cell(0, 8, value, new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_xy(20, pdf.h - 28)
    pdf.set_font("DejaVu", "I", 9)
    pdf.set_text_color(156, 163, 175)
    pdf.cell(0, 6, "Sensors: CO2  •  PM1.0  •  PM2.5  •  PM10  •  "
                   "Temperature  •  Humidity")

    # ===================== BODY =====================
    pdf.add_page()

    # --- 1. Background ---
    pdf.section(1, "Background")
    pdf.body(
        "Indoor air quality (IAQ) has emerged as a critical determinant of "
        "human health, comfort, and productivity. Research indicates that "
        "people spend approximately 90% of their time indoors, where "
        "concentrations of pollutants can be two to five times higher than "
        "outdoors. In shared environments such as classrooms, lecture halls, "
        "offices, and public facilities, the combination of high occupant "
        "density and limited ventilation causes carbon dioxide (CO2) and "
        "particulate matter (PM2.5, PM10) to accumulate rapidly."
    )
    pdf.body(
        "AirSense is an Internet-of-Things (IoT) based indoor air quality "
        "monitoring system developed to address this gap. The system "
        "integrates low-cost environmental sensors, real-time data "
        "streaming over the MQTT protocol, time-series data storage in "
        "InfluxDB, and a machine learning pipeline. It continuously measures "
        "CO2, particulate matter (PM1.0, PM2.5, PM10), temperature, and "
        "relative humidity; computes the Air Quality Index (AQI) according "
        "to the United States Environmental Protection Agency (EPA) 2024 "
        "standards; and delivers predictive insights and health "
        "recommendations through an interactive web dashboard."
    )

    # --- 2. Problem Statement ---
    pdf.section(2, "Problem We Are Solving")
    pdf.body(
        "Despite the well-documented health impacts of poor indoor air, the "
        "majority of shared spaces — and schools in particular — operate "
        "without any form of air quality measurement. This gives rise to "
        "several interlinked problems:"
    )
    pdf.bullets([
        "Air pollution is invisible. Occupants and facility managers have "
        "no way of knowing when CO2 or particulate levels have reached "
        "harmful thresholds.",
        "Without data, there is no trigger for simple corrective action "
        "such as opening windows or adjusting occupancy.",
        "Commercial air quality monitoring solutions are expensive, "
        "proprietary, and rarely adapted to local conditions or budgets.",
        "Existing systems typically report raw numbers only; they do not "
        "forecast short-term trends or translate measurements into "
        "actionable guidance.",
        "Vulnerable populations — especially children — are exposed daily "
        "to conditions that measurably impair health and learning, with no "
        "mechanism for detection or intervention.",
    ])
    pdf.body(
        "The core problem this project addresses is therefore the absence "
        "of an affordable, real-time, and intelligent air quality "
        "monitoring system capable of not only measuring but also "
        "interpreting, predicting, and recommending action in shared "
        "indoor spaces."
    )

    # --- 3. Objectives ---
    pdf.section(3, "Objectives")
    pdf.subsection("General Objective")
    pdf.body(
        "To design and implement an affordable, intelligent IoT-based "
        "indoor air quality monitoring system for shared spaces, with a "
        "particular focus on schools."
    )
    pdf.subsection("Specific Objectives")
    pdf.bullets([
        "To develop a sensor node that accurately measures CO2, PM1.0, "
        "PM2.5, PM10, temperature, and relative humidity.",
        "To stream and store sensor data in real time using the MQTT "
        "protocol and an InfluxDB time-series database.",
        "To compute the Air Quality Index from raw pollutant "
        "concentrations using internationally recognised EPA breakpoints.",
        "To develop, train, and comparatively evaluate machine learning "
        "models for AQI regression (numeric prediction) and AQI category "
        "classification.",
        "To implement a short-term forecasting model for PM2.5 "
        "concentration.",
        "To build a rule-based recommendation engine that converts "
        "measurements into health, activity, and ventilation guidance "
        "based on World Health Organization (WHO) 2021 guidelines.",
        "To deliver a web-based dashboard for real-time visualisation, "
        "historical analysis, and alerting.",
    ])

    # --- 4. Justification ---
    pdf.section(4, "Why Monitor Air Quality in Schools and Shared Spaces")
    pdf.body(
        "Schools were selected as the primary target for this system for "
        "reasons of both vulnerability and impact. The case for monitoring "
        "rests on the following evidence-based arguments:"
    )
    pdf.lead_bullets([
        ("Children are physiologically more vulnerable.",
         "Children breathe a greater volume of air relative to their body "
         "weight than adults, and their lungs, immune systems, and brains "
         "are still developing. The World Health Organization estimates "
         "that 93% of children worldwide breathe air that exceeds "
         "recommended pollutant limits."),
        ("Classrooms are among the most crowded indoor environments.",
         "A typical classroom places 30 to 50 occupants in a relatively "
         "small, often poorly ventilated room for hours at a time. Each "
         "occupant continuously exhales CO2, so concentrations routinely "
         "exceed the 1,000 ppm ASHRAE comfort limit and frequently surpass "
         "2,000 ppm by the end of a lesson."),
        ("Elevated CO2 measurably impairs learning.",
         "Peer-reviewed studies have shown that cognitive performance — "
         "concentration, decision-making, and recall — declines "
         "significantly as indoor CO2 rises. Higher classroom CO2 has been "
         "associated with reduced attention, lower test scores, and "
         "increased absenteeism. Poor air quality silently undermines the "
         "very purpose of the classroom."),
        ("Particulate matter drives respiratory illness and absenteeism.",
         "Fine particulate matter (PM2.5) penetrates deep into the lungs "
         "and bloodstream. Chronic exposure is strongly linked to the "
         "development and aggravation of asthma, one of the leading causes "
         "of school absenteeism worldwide."),
        ("The interventions are simple — but only if the problem is visible.",
         "The remedy for most IAQ problems is inexpensive: opening a "
         "window, adjusting occupancy, or pausing an activity is often "
         "sufficient. The missing ingredient is information. A monitoring "
         "system makes the invisible visible and converts guesswork into "
         "timely, evidence-based action."),
        ("Schools are a high-impact, equitable point of intervention.",
         "Because every child passes through the education system, "
         "improving classroom air quality delivers broad and equitable "
         "public-health benefit at a low cost per beneficiary, protecting "
         "an entire generation during the hours that matter most."),
        ("Local relevance.",
         "In rapidly urbanising cities such as Kigali, rising traffic, "
         "construction dust, and growing class sizes intensify IAQ "
         "challenges. A locally developed, low-cost system such as "
         "AirSense is well suited to these conditions."),
    ])
    pdf.quote(
        "  In summary, schools represent the intersection of high "
        "vulnerability, high exposure, measurable harm, and low-cost "
        "remedy. Monitoring air quality in these shared spaces is not a "
        "luxury but a practical and necessary safeguard for children's "
        "health and learning.  "
    )

    # --- 5. Methodology & Research Models ---
    pdf.section(5, "Methodology and Research Models Used")
    pdf.subsection("Dataset")
    pdf.body(
        "The machine learning pipeline was developed using a dataset of "
        "6,200 sensor readings recorded at approximately 20-second "
        "intervals. Each reading contains CO2, PM2.5, PM10, temperature, "
        "and humidity, together with derived categorical labels."
    )
    pdf.subsection("Data Preprocessing and AQI Computation")
    pdf.body(
        "Raw data was cleaned through type coercion, removal of physically "
        "impossible values, and time-aware linear interpolation of short "
        "gaps. The Air Quality Index — which serves as the prediction "
        "target — was computed from PM2.5 and PM10 concentrations using "
        "the EPA 2024 piecewise-linear formula:"
    )
    pdf.formula(
        "AQI  =  (I_hi − I_lo) / (C_hi − C_lo) × (C − C_lo)  +  I_lo",
        "where C is the measured pollutant concentration and "
        "(C_lo, C_hi, I_lo, I_hi) are the breakpoints of the category "
        "containing C. The overall AQI is the maximum of the PM2.5 and "
        "PM10 sub-indices."
    )
    pdf.subsection("Feature Engineering")
    pdf.body(
        "To enable the models to capture temporal patterns, the following "
        "features were derived: calendar features (hour, day of week, "
        "month, weekend indicator); cyclic encodings of time using sine "
        "and cosine transforms; lag features capturing values at previous "
        "time steps (t−1, t−2, t−6, t−12, t−24); and rolling-window "
        "statistics (mean and standard deviation over 6, 24, and 72-step "
        "windows)."
    )
    pdf.subsection("Model Families Investigated")
    pdf.lead_bullets([
        ("Regression models — predicting the continuous AQI value.",
         "Linear Regression, Ridge Regression, Lasso Regression, "
         "Polynomial Regression (degrees 2 and 3), Random Forest "
         "Regressor, Support Vector Regression with an RBF kernel, and "
         "XGBoost gradient-boosted trees."),
        ("Classification models — predicting the six-class AQI category.",
         "Logistic Regression, Random Forest Classifier, Support Vector "
         "Classifier with an RBF kernel, and XGBoost Classifier. Categories "
         "range from Good to Hazardous."),
        ("Time-series forecasting — predicting future PM2.5 concentration.",
         "A SARIMA model with automatic order selection by minimisation of "
         "the Akaike Information Criterion (AIC)."),
    ])
    pdf.subsection("Validation Strategy")
    pdf.body(
        "Because the data is a time series, ordinary random "
        "cross-validation would leak future information into the training "
        "set. All hyperparameter tuning therefore used TimeSeriesSplit "
        "five-fold cross-validation, in which each validation fold lies "
        "strictly after its corresponding training fold in time."
    )

    # --- 6. Evaluation Metrics & Formulas ---
    pdf.section(6, "Evaluation Metrics and Formulas")
    pdf.body(
        "Model performance was quantified using standard metrics. In the "
        "formulas below, y is the true value, ŷ is the predicted value, "
        "ȳ is the mean of the true values, n is the number of samples, "
        "and ε is a small constant preventing division by zero."
    )
    pdf.subsection("Regression Metrics")
    pdf.formula("MAE   =  (1/n) · Σ |y − ŷ|",
                "Mean Absolute Error — average magnitude of error.")
    pdf.formula("RMSE  =  √[ (1/n) · Σ (y − ŷ)² ]",
                "Root Mean Square Error — penalises large errors more "
                "heavily.")
    pdf.formula("R²    =  1 − Σ(y − ŷ)² / Σ(y − ȳ)²",
                "Coefficient of determination — proportion of variance "
                "explained (1.0 is perfect).")
    pdf.formula("MAPE  =  (100/n) · Σ |y − ŷ| / max(|y|, ε)",
                "Mean Absolute Percentage Error.")
    pdf.subsection("Classification Metrics")
    pdf.formula("Accuracy   =  (TP + TN) / N")
    pdf.formula("Precision  =  TP / (TP + FP)            [macro-averaged]")
    pdf.formula("Recall     =  TP / (TP + FN)            [macro-averaged]")
    pdf.formula("F1         =  2 · Precision · Recall / (Precision + Recall)",
                "Harmonic mean of precision and recall; ROC-AUC is the "
                "area under the ROC curve (One-vs-Rest for multiclass).")
    pdf.subsection("Forecasting Metrics")
    pdf.formula("SMAPE  =  (200/n) · Σ |y − ŷ| / (|y| + |ŷ| + ε)",
                "Symmetric Mean Absolute Percentage Error.")
    pdf.formula("MASE   =  MAE  /  MAE(naive t−1 forecast)",
                "Mean Absolute Scaled Error — below 1.0 means the model "
                "beats a naive baseline.")

    # --- 7. Comparative Results ---
    pdf.section(7, "Comparative Results on Model Performance")
    pdf.subsection("7.1  Regression — Predicting the Numeric AQI")

    headings = FontFace(emphasis="BOLD", color=WHITE, fill_color=GREEN)
    pdf.set_font("DejaVu", "", 8.6)
    pdf.set_text_color(*BODY)
    with pdf.table(
        col_widths=(14, 64, 24, 24, 24, 24),
        text_align=("CENTER", "LEFT", "RIGHT", "RIGHT", "RIGHT", "RIGHT"),
        headings_style=headings,
        line_height=6.4,
        cell_fill_color=LIGHT,
        cell_fill_mode="ROWS",
        borders_layout="HORIZONTAL_LINES",
    ) as table:
        row = table.row()
        for h in ("Rank", "Model", "MAE", "RMSE", "R²", "MAPE (%)"):
            row.cell(h)
        for rank, name, mae, rmse, r2, mape in REGRESSION:
            row = table.row()
            row.cell(str(rank))
            row.cell(name)
            row.cell(f"{mae:.4f}")
            row.cell(f"{rmse:.4f}")
            row.cell(f"{r2:.4f}")
            row.cell(f"{mape:.2f}")
    pdf.ln(2)
    pdf.set_font("DejaVu", "I", 9)
    pdf.set_text_color(107, 114, 128)
    pdf.multi_cell(pdf.epw, 5,
                   "Best regressor: Polynomial Regression (deg 3) — lowest "
                   "RMSE. XGBoost is statistically equivalent.",
                   new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.ln(3)
    if pdf.get_y() > pdf.h - 75:
        pdf.add_page()
    pdf.image(reg_chart, w=pdf.epw)
    pdf.ln(4)

    pdf.subsection("7.2  Classification — Predicting the AQI Category")
    pdf.set_font("DejaVu", "", 8.6)
    pdf.set_text_color(*BODY)
    with pdf.table(
        col_widths=(13, 49, 23, 23, 21, 21, 24),
        text_align=("CENTER", "LEFT", "RIGHT", "RIGHT", "RIGHT", "RIGHT",
                    "RIGHT"),
        headings_style=headings,
        line_height=6.4,
        cell_fill_color=LIGHT,
        cell_fill_mode="ROWS",
        borders_layout="HORIZONTAL_LINES",
    ) as table:
        row = table.row()
        for h in ("Rank", "Model", "Accuracy", "Precision", "Recall",
                  "F1", "ROC-AUC"):
            row.cell(h)
        for rank, name, acc, prec, rec, f1, roc in CLASSIFICATION:
            row = table.row()
            row.cell(str(rank))
            row.cell(name)
            row.cell(f"{acc:.4f}")
            row.cell(f"{prec:.4f}")
            row.cell(f"{rec:.4f}")
            row.cell(f"{f1:.4f}")
            row.cell(f"{roc:.4f}")
    pdf.ln(2)
    pdf.set_font("DejaVu", "I", 9)
    pdf.set_text_color(107, 114, 128)
    pdf.multi_cell(pdf.epw, 5,
                   "Best classifier: Random Forest — perfect F1 score on "
                   "the held-out test set, matched by XGBoost.",
                   new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.ln(3)
    if pdf.get_y() > pdf.h - 70:
        pdf.add_page()
    pdf.image(clf_chart, w=pdf.epw)
    pdf.ln(4)

    pdf.subsection("7.3  Interpretation of Results")
    pdf.body(
        "Among the eight regression models, the third-degree polynomial "
        "regression and XGBoost achieved the strongest results, both "
        "attaining an R² of 0.9999 and root-mean-square errors below 0.4 "
        "AQI units. Random Forest and the second-degree polynomial also "
        "performed well. The linear family (Linear, Ridge, Lasso) and "
        "Support Vector Regression were noticeably weaker, with RMSE "
        "values between 10 and 15 AQI units. For classification, Random "
        "Forest and XGBoost classified the six AQI categories with "
        "perfect scores on the test set, while SVC and Logistic "
        "Regression achieved F1 scores of 0.985 and 0.964 respectively."
    )

    # --- 8. Discussion ---
    pdf.section(8, "Discussion and Limitations")
    pdf.body(
        "The very high accuracy observed — particularly the near-perfect "
        "regression and classification scores — warrants careful "
        "interpretation. The Air Quality Index is, by definition, a "
        "deterministic mathematical function of PM2.5 and PM10 "
        "concentrations. Because these concentrations are provided to the "
        "models as input features, sufficiently expressive models "
        "(polynomial and tree-based) are able to reconstruct the AQI "
        "function almost exactly. The results therefore confirm that the "
        "models have correctly learned the underlying relationship, but "
        "they do not by themselves demonstrate predictive power on "
        "genuinely unseen future conditions."
    )
    pdf.body("The practical machine-learning value of the system lies in "
             "three areas that go beyond direct AQI recomputation:")
    pdf.bullets([
        "Forecasting — the SARIMA model predicts PM2.5 concentrations "
        "before they occur, giving occupants advance warning of "
        "deteriorating air quality.",
        "Robust inference — classification and recommendation can still "
        "operate when one or more sensor readings are missing or noisy.",
        "Recommendation — measured values are translated into specific, "
        "threshold-based health, activity, and ventilation guidance.",
    ])
    pdf.body(
        "Future work should incorporate larger and more diverse datasets — "
        "including data collected directly from school classrooms — and "
        "should evaluate the forecasting models against held-out future "
        "periods to quantify true predictive performance."
    )

    # --- 9. Conclusion ---
    pdf.section(9, "Conclusion")
    pdf.body(
        "AirSense demonstrates that an affordable, IoT-based indoor air "
        "quality monitoring system, augmented with machine learning, can "
        "be designed and implemented to address a genuine and underserved "
        "public-health need. The system reliably measures key pollutants, "
        "computes internationally standardised air quality indices, "
        "classifies air quality conditions with high accuracy, forecasts "
        "short-term pollutant trends, and delivers actionable "
        "recommendations through an accessible web dashboard."
    )
    pdf.body(
        "By focusing on schools and other shared spaces, the project "
        "targets an environment where the health and cognitive stakes are "
        "highest, the affected population is most vulnerable, and the cost "
        "of corrective action is lowest. Making indoor air quality visible "
        "is a necessary first step toward protecting the health, comfort, "
        "and learning outcomes of the children and communities who depend "
        "on these spaces every day."
    )

    pdf.output(OUT_PDF)


if __name__ == "__main__":
    reg_chart, clf_chart = make_charts()
    build_pdf(reg_chart, clf_chart)
    print(f"Report written to: {os.path.abspath(OUT_PDF)}")
