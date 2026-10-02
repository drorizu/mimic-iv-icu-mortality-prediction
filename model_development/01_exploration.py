"""
===============================================================================
01_exploration.py

Purpose:
    Exploratory analysis and data-quality checks for the MIMIC-IV ICU
    mortality prediction dataset.

Input:
    results/final_dataset.csv

Output:
    results/exploration/
        cohort_summary.csv
        missingness.csv
        numeric_summary.csv
        categorical_summary.csv
        outcome_distribution.png
        missingness.png
        numeric_distributions.png

IMPORTANT:
    This script performs exploration only.
    No imputation, scaling, feature selection, or model fitting occurs here.
===============================================================================
"""

from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns


# =============================================================================
# Configuration
# =============================================================================

RANDOM_STATE = 42

PROJECT_ROOT = Path(__file__).resolve().parents[1]

DATA_PATH = PROJECT_ROOT / "results" / "final_dataset.csv"

OUTPUT_DIR = PROJECT_ROOT / "results" / "exploration"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# =============================================================================
# Plotting configuration
# =============================================================================

sns.set_theme(
    style="whitegrid",
    context="notebook"
)


# =============================================================================
# 1. Load data
# =============================================================================

print("=" * 80)
print("Loading dataset")
print("=" * 80)

df = pd.read_csv(DATA_PATH)

print(f"Rows:    {df.shape[0]:,}")
print(f"Columns: {df.shape[1]:,}")

print("\nFirst five rows:")
print(df.head())


# =============================================================================
# 2. Basic structure
# =============================================================================

print("\n" + "=" * 80)
print("Dataset structure")
print("=" * 80)

print(df.info())


# =============================================================================
# 3. Identify outcome
# =============================================================================

TARGET = "mortality_after_24h"

if TARGET not in df.columns:
    raise ValueError(
        f"Target column '{TARGET}' was not found in the dataset."
    )


# =============================================================================
# 4. Basic cohort summary
# =============================================================================

print("\n" + "=" * 80)
print("Cohort summary")
print("=" * 80)

summary = pd.DataFrame({
    "metric": [
        "rows",
        "columns",
        "unique_subjects",
        "unique_admissions",
        "unique_icu_stays",
        "mortality_events",
        "mortality_rate",
    ],
    "value": [
        len(df),
        df.shape[1],
        df["subject_id"].nunique()
        if "subject_id" in df.columns else np.nan,

        df["hadm_id"].nunique()
        if "hadm_id" in df.columns else np.nan,

        df["stay_id"].nunique()
        if "stay_id" in df.columns else np.nan,

        df[TARGET].sum(),

        df[TARGET].mean(),
    ]
})

print(summary)

summary.to_csv(
    OUTPUT_DIR / "cohort_summary.csv",
    index=False
)


# =============================================================================
# 5. Outcome distribution
# =============================================================================

print("\n" + "=" * 80)
print("Outcome distribution")
print("=" * 80)

outcome_counts = (
    df[TARGET]
    .value_counts(dropna=False)
    .sort_index()
)

print(outcome_counts)

print("\nOutcome proportions:")
print(
    df[TARGET]
    .value_counts(normalize=True, dropna=False)
    .sort_index()
)


# =============================================================================
# 6. Check target validity
# =============================================================================

print("\n" + "=" * 80)
print("Target validation")
print("=" * 80)

print(
    "Missing target:",
    df[TARGET].isna().sum()
)

print(
    "Unique target values:",
    sorted(df[TARGET].dropna().unique())
)

invalid_target = ~df[TARGET].isin([0, 1])

print(
    "Invalid target values:",
    invalid_target.sum()
)


# =============================================================================
# 7. Duplicate checks
# =============================================================================

print("\n" + "=" * 80)
print("Duplicate checks")
print("=" * 80)

if "stay_id" in df.columns:

    duplicate_stays = df["stay_id"].duplicated().sum()

    print(
        f"Duplicate stay_id rows: {duplicate_stays:,}"
    )

    if duplicate_stays > 0:
        print(
            "\nWARNING: More than one row exists for at least one ICU stay."
        )


if "subject_id" in df.columns:

    duplicate_subjects = df["subject_id"].duplicated().sum()

    print(
        f"Repeated subject_id rows: {duplicate_subjects:,}"
    )


# =============================================================================
# 8. Missingness analysis
# =============================================================================

print("\n" + "=" * 80)
print("Missingness")
print("=" * 80)

missingness = pd.DataFrame({
    "column": df.columns,
    "missing_n": df.isna().sum().values,
    "missing_percent": (
        df.isna().mean().values * 100
    ),
})

missingness = (
    missingness
    .sort_values(
        "missing_percent",
        ascending=False
    )
    .reset_index(drop=True)
)

print(
    missingness.head(30).to_string(index=False)
)

missingness.to_csv(
    OUTPUT_DIR / "missingness.csv",
    index=False
)


# =============================================================================
# 9. Missingness visualization
# =============================================================================

# Only plot variables with at least some missingness.

missing_plot = (
    missingness[
        missingness["missing_percent"] > 0
    ]
    .head(40)
    .sort_values("missing_percent")
)

if len(missing_plot) > 0:

    plt.figure(figsize=(10, 12))

    plt.barh(
        missing_plot["column"],
        missing_plot["missing_percent"]
    )

    plt.xlabel("Missing (%)")
    plt.ylabel("Variable")
    plt.title("Top Missing Variables")

    plt.tight_layout()

    plt.savefig(
        OUTPUT_DIR / "missingness.png",
        dpi=200
    )

    plt.close()


# =============================================================================
# 10. Numeric variables
# =============================================================================

numeric_columns = df.select_dtypes(
    include=np.number
).columns.tolist()

print("\n" + "=" * 80)
print("Numeric variables")
print("=" * 80)

print(
    f"Number of numeric columns: {len(numeric_columns)}"
)


numeric_summary = (
    df[numeric_columns]
    .describe()
    .T
)

numeric_summary["missing_n"] = (
    df[numeric_columns]
    .isna()
    .sum()
)

numeric_summary["missing_percent"] = (
    df[numeric_columns]
    .isna()
    .mean() * 100
)

numeric_summary.to_csv(
    OUTPUT_DIR / "numeric_summary.csv"
)

print(
    numeric_summary.head(30)
)


# =============================================================================
# 11. Detect suspicious numeric values
# =============================================================================

print("\n" + "=" * 80)
print("Potentially suspicious numeric values")
print("=" * 80)

for column in numeric_columns:

    series = df[column].dropna()

    if len(series) == 0:
        continue

    if np.isinf(series).any():

        print(
            f"WARNING: {column} contains infinite values."
        )

    if (series < 0).any():

        negative_count = (series < 0).sum()

        print(
            f"{column}: {negative_count:,} negative values"
        )


# =============================================================================
# 12. Categorical variables
# =============================================================================

categorical_columns = df.select_dtypes(
    include=["object", "category", "bool"]
).columns.tolist()

print("\n" + "=" * 80)
print("Categorical variables")
print("=" * 80)

print(
    f"Number of categorical columns: {len(categorical_columns)}"
)


categorical_records = []

for column in categorical_columns:

    series = df[column]

    categorical_records.append({
        "column": column,
        "n_unique": series.nunique(dropna=True),
        "missing_n": series.isna().sum(),
        "missing_percent": series.isna().mean() * 100,
    })


categorical_summary = pd.DataFrame(
    categorical_records
)

categorical_summary = (
    categorical_summary
    .sort_values("n_unique", ascending=False)
)

categorical_summary.to_csv(
    OUTPUT_DIR / "categorical_summary.csv",
    index=False
)

print(categorical_summary)


# =============================================================================
# 13. Display categorical distributions
# =============================================================================

for column in categorical_columns:

    # Avoid dumping enormous identifier columns.
    if df[column].nunique(dropna=True) > 30:
        continue

    print("\n" + "-" * 60)
    print(column)
    print("-" * 60)

    print(
        df[column]
        .value_counts(dropna=False)
        .head(30)
    )


# =============================================================================
# 14. Outcome plot
# =============================================================================

plt.figure(figsize=(6, 5))

sns.countplot(
    data=df,
    x=TARGET
)

plt.xlabel("Mortality after 24 hours")
plt.ylabel("Number of ICU stays")
plt.title("Outcome Distribution")

plt.tight_layout()

plt.savefig(
    OUTPUT_DIR / "outcome_distribution.png",
    dpi=200
)

plt.close()


# =============================================================================
# 15. Numerical distributions
# =============================================================================

# Focus on clinically important variables rather than plotting every feature.

plot_candidates = [
    "age_at_icu_admission",

    "hr_mean",
    "sbp_mean",
    "dbp_mean",
    "map_mean",
    "rr_mean",
    "spo2_mean",
    "temp_mean",

    "sodium_mean",
    "potassium_mean",
    "bicarbonate_mean",
    "bun_mean",
    "creatinine_mean",
    "glucose_mean",

    "hemoglobin_mean",
    "wbc_mean",
    "platelets_mean",

    "bilirubin_mean",
    "albumin_mean",

    "lactate_mean",

    "ph_mean",
    "pao2_mean",
    "paco2_mean",

    "urine_output_ml_24h",
    "urine_output_ml_kg_h_24h",
    "ventilation_duration_hours",
    "pressor_exposure_hours",
]

plot_columns = [
    column
    for column in plot_candidates
    if column in df.columns
]


if plot_columns:

    n_columns = 3
    n_rows = int(
        np.ceil(len(plot_columns) / n_columns)
    )

    fig, axes = plt.subplots(
        n_rows,
        n_columns,
        figsize=(15, 4 * n_rows)
    )

    axes = np.asarray(axes).reshape(-1)

    for ax, column in zip(
        axes,
        plot_columns
    ):

        sns.histplot(
            data=df,
            x=column,
            hue=TARGET,
            element="step",
            stat="density",
            common_norm=False,
            ax=ax
        )

        ax.set_title(column)

    # Remove unused axes.
    for ax in axes[len(plot_columns):]:
        ax.remove()

    plt.tight_layout()

    plt.savefig(
        OUTPUT_DIR / "numeric_distributions.png",
        dpi=200
    )

    plt.close()


# =============================================================================
# 16. Compare key variables by outcome
# =============================================================================

print("\n" + "=" * 80)
print("Key variables by outcome")
print("=" * 80)

comparison_columns = [
    "age_at_icu_admission",
    "hr_mean",
    "map_mean",
    "rr_mean",
    "spo2_mean",
    "lactate_mean",
    "creatinine_mean",
    "wbc_mean",
    "hemoglobin_mean",
    "urine_output_ml_kg_h_24h",
]

comparison_columns = [
    column
    for column in comparison_columns
    if column in df.columns
]


for column in comparison_columns:

    print("\n" + "-" * 60)
    print(column)
    print("-" * 60)

    print(
        df.groupby(TARGET)[column]
        .agg(
            [
                "count",
                "mean",
                "median",
                "std",
                "min",
                "max",
            ]
        )
    )


# =============================================================================
# 17. Intervention prevalence
# =============================================================================

print("\n" + "=" * 80)
print("Intervention prevalence")
print("=" * 80)

intervention_columns = [
    "mechanical_ventilation_24h",
    "vasopressor_any_24h",
    "norepinephrine_24h",
    "epinephrine_24h",
    "vasopressin_24h",
    "phenylephrine_24h",
    "dopamine_24h",
]

for column in intervention_columns:

    if column not in df.columns:
        continue

    print(
        f"{column}: "
        f"{df[column].mean() * 100:.2f}%"
    )


# =============================================================================
# 18. Intervention prevalence by outcome
# =============================================================================

for column in intervention_columns:

    if column not in df.columns:
        continue

    print("\n" + "-" * 60)
    print(column)
    print("-" * 60)

    print(
        pd.crosstab(
            df[TARGET],
            df[column],
            normalize="index"
        ) * 100
    )


# =============================================================================
# 19. Time-window sanity checks
# =============================================================================

print("\n" + "=" * 80)
print("Time-window checks")
print("=" * 80)

if {
    "intime",
    "prediction_time"
}.issubset(df.columns):

    intime = pd.to_datetime(
        df["intime"],
        errors="coerce"
    )

    prediction_time = pd.to_datetime(
        df["prediction_time"],
        errors="coerce"
    )

    prediction_hours = (
        prediction_time - intime
    ).dt.total_seconds() / 3600

    print(
        prediction_hours.describe()
    )

    print(
        "\nNon-24-hour prediction windows:",
        (
            ~np.isclose(
                prediction_hours,
                24,
                atol=0.01
            )
        ).sum()
    )


# =============================================================================
# 20. Final report
# =============================================================================

print("\n" + "=" * 80)
print("Exploration complete")
print("=" * 80)

print(
    f"Results written to:\n{OUTPUT_DIR}"
)

print(
    "\nNo preprocessing or model fitting was performed."
)
