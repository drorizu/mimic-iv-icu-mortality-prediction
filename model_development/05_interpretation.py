"""
===============================================================================
05_interpretation.py

Purpose:
    Interpret the fitted ICU mortality prediction models.

Inputs:
    results/preprocessing/train_processed.csv
    results/preprocessing/test_processed.csv
    results/models/*.joblib
    results/models/test_predictions.csv

Outputs:
    results/interpretation/
        logistic_coefficients.csv
        logistic_top_features.png
        permutation_importance.csv
        permutation_importance.png
        subgroup_performance.csv

Important:
    Predictive association is not causal association.

    A feature with high predictive importance may be:
        - directly related to physiologic severity,
        - a proxy for another condition,
        - correlated with another variable,
        - related to clinical treatment,
        - or associated with documentation/intensity of care.

    Interpretation should therefore not be phrased as "this variable causes
    mortality."
===============================================================================
"""

from pathlib import Path

import joblib
import numpy as np
import pandas as pd

import matplotlib.pyplot as plt
import seaborn as sns

from sklearn.inspection import permutation_importance
from sklearn.metrics import (
    roc_auc_score,
    average_precision_score,
)


# =============================================================================
# Configuration
# =============================================================================

RANDOM_STATE = 42

TARGET = "mortality_after_24h"

PROJECT_ROOT = Path(__file__).resolve().parents[1]

PREPROCESSING_DIR = (
    PROJECT_ROOT /
    "results" /
    "preprocessing"
)

MODEL_DIR = (
    PROJECT_ROOT /
    "results" /
    "models"
)

OUTPUT_DIR = (
    PROJECT_ROOT /
    "results" /
    "interpretation"
)

OUTPUT_DIR.mkdir(
    parents=True,
    exist_ok=True
)


sns.set_theme(
    style="whitegrid",
    context="notebook"
)


# =============================================================================
# 1. Load processed datasets
# =============================================================================

print("=" * 80)
print("Loading processed datasets")
print("=" * 80)

train = pd.read_csv(
    PREPROCESSING_DIR /
    "train_processed.csv"
)

test = pd.read_csv(
    PREPROCESSING_DIR /
    "test_processed.csv"
)

X_train = train.drop(
    columns=[TARGET]
)

y_train = train[TARGET].astype(int)

X_test = test.drop(
    columns=[TARGET]
)

y_test = test[TARGET].astype(int)


print(
    f"Training shape: {X_train.shape}"
)

print(
    f"Test shape:     {X_test.shape}"
)


# =============================================================================
# 2. Load models
# =============================================================================

print("\n" + "=" * 80)
print("Loading models")
print("=" * 80)

logistic_model = joblib.load(
    MODEL_DIR /
    "logistic_regression.joblib"
)

random_forest_model = joblib.load(
    MODEL_DIR /
    "random_forest.joblib"
)

gradient_boosting_model = joblib.load(
    MODEL_DIR /
    "gradient_boosting.joblib"
)


# =============================================================================
# 3. Logistic regression coefficients
# =============================================================================

print("\n" + "=" * 80)
print("Logistic regression coefficients")
print("=" * 80)

feature_names = X_train.columns.tolist()

coefficients = (
    logistic_model.coef_[0]
)

coefficient_df = pd.DataFrame(
    {
        "feature": feature_names,
        "coefficient": coefficients,
        "odds_ratio": np.exp(coefficients),
        "absolute_coefficient": np.abs(coefficients),
    }
)


coefficient_df["direction"] = np.where(
    coefficient_df["coefficient"] >= 0,
    "positive association with predicted mortality",
    "negative association with predicted mortality",
)


coefficient_df = (
    coefficient_df
    .sort_values(
        "absolute_coefficient",
        ascending=False
    )
    .reset_index(drop=True)
)


coefficient_df.to_csv(
    OUTPUT_DIR /
    "logistic_coefficients.csv",
    index=False
)


print(
    coefficient_df.head(30).to_string(
        index=False
    )
)


# =============================================================================
# 4. Top positive and negative coefficients
# =============================================================================

top_positive = (
    coefficient_df
    .sort_values(
        "coefficient",
        ascending=False
    )
    .head(15)
    .sort_values(
        "coefficient"
    )
)

top_negative = (
    coefficient_df
    .sort_values(
        "coefficient",
        ascending=True
    )
    .head(15)
    .sort_values(
        "coefficient"
    )
)


fig, axes = plt.subplots(
    1,
    2,
    figsize=(16, 10)
)


axes[0].barh(
    top_positive["feature"],
    top_positive["coefficient"]
)

axes[0].set_title(
    "Largest Positive Logistic Coefficients"
)

axes[0].set_xlabel(
    "Coefficient"
)


axes[1].barh(
    top_negative["feature"],
    top_negative["coefficient"]
)

axes[1].set_title(
    "Largest Negative Logistic Coefficients"
)

axes[1].set_xlabel(
    "Coefficient"
)


plt.tight_layout()

plt.savefig(
    OUTPUT_DIR /
    "logistic_top_features.png",
    dpi=200
)

plt.close()


# =============================================================================
# 5. Permutation importance — logistic regression
# =============================================================================

print("\n" + "=" * 80)
print("Permutation importance — logistic regression")
print("=" * 80)

logistic_importance = permutation_importance(

    logistic_model,

    X_test,

    y_test,

    scoring="roc_auc",

    n_repeats=10,

    random_state=RANDOM_STATE,

    n_jobs=-1,
)


logistic_importance_df = pd.DataFrame(
    {
        "feature": X_test.columns,

        "importance_mean":
            logistic_importance.importances_mean,

        "importance_std":
            logistic_importance.importances_std,
    }
)


logistic_importance_df = (
    logistic_importance_df
    .sort_values(
        "importance_mean",
        ascending=False
    )
    .reset_index(drop=True)
)


logistic_importance_df["model"] = (
    "logistic_regression"
)


# =============================================================================
# 6. Permutation importance — random forest
# =============================================================================

print("\n" + "=" * 80)
print("Permutation importance — random forest")
print("=" * 80)

rf_importance = permutation_importance(

    random_forest_model,

    X_test,

    y_test,

    scoring="roc_auc",

    n_repeats=10,

    random_state=RANDOM_STATE,

    n_jobs=-1,
)


rf_importance_df = pd.DataFrame(
    {
        "feature": X_test.columns,

        "importance_mean":
            rf_importance.importances_mean,

        "importance_std":
            rf_importance.importances_std,
    }
)


rf_importance_df = (
    rf_importance_df
    .sort_values(
        "importance_mean",
        ascending=False
    )
    .reset_index(drop=True)
)


rf_importance_df["model"] = (
    "random_forest"
)


# =============================================================================
# 7. Permutation importance — gradient boosting
# =============================================================================

print("\n" + "=" * 80)
print("Permutation importance — gradient boosting")
print("=" * 80)

gb_importance = permutation_importance(

    gradient_boosting_model,

    X_test,

    y_test,

    scoring="roc_auc",

    n_repeats=10,

    random_state=RANDOM_STATE,

    n_jobs=-1,
)


gb_importance_df = pd.DataFrame(
    {
        "feature": X_test.columns,

        "importance_mean":
            gb_importance.importances_mean,

        "importance_std":
            gb_importance.importances_std,
    }
)


gb_importance_df = (
    gb_importance_df
    .sort_values(
        "importance_mean",
        ascending=False
    )
    .reset_index(drop=True)
)


gb_importance_df["model"] = (
    "gradient_boosting"
)


# =============================================================================
# 8. Combine permutation importance
# =============================================================================

permutation_importance_df = pd.concat(
    [
        logistic_importance_df,
        rf_importance_df,
        gb_importance_df,
    ],
    ignore_index=True,
)


permutation_importance_df.to_csv(
    OUTPUT_DIR /
    "permutation_importance.csv",
    index=False
)


# =============================================================================
# 9. Plot top random-forest features
# =============================================================================

top_rf = (
    rf_importance_df
    .head(25)
    .sort_values(
        "importance_mean"
    )
)


plt.figure(
    figsize=(10, 10)
)


plt.barh(
    top_rf["feature"],
    top_rf["importance_mean"],
    xerr=top_rf["importance_std"],
)


plt.xlabel(
    "Decrease in ROC-AUC after permutation"
)

plt.ylabel(
    "Feature"
)

plt.title(
    "Random Forest Permutation Importance"
)


plt.tight_layout()

plt.savefig(
    OUTPUT_DIR /
    "permutation_importance.png",
    dpi=200
)

plt.close()


# =============================================================================
# 10. Compare feature importance across models
# =============================================================================

top_features = (
    permutation_importance_df
    .groupby("feature")["importance_mean"]
    .max()
    .sort_values(
        ascending=False
    )
    .head(20)
    .index
)


comparison = (
    permutation_importance_df[
        permutation_importance_df["feature"].isin(
            top_features
        )
    ]
    .pivot(
        index="feature",
        columns="model",
        values="importance_mean"
    )
)


comparison = comparison.loc[
    comparison.max(axis=1)
    .sort_values()
    .index
]


plt.figure(
    figsize=(12, 10)
)


comparison.plot(
    kind="barh",
    figsize=(12, 10)
)


plt.xlabel(
    "Permutation importance"
)

plt.ylabel(
    "Feature"
)

plt.title(
    "Feature Importance Across Models"
)

plt.tight_layout()

plt.savefig(
    OUTPUT_DIR /
    "importance_comparison.png",
    dpi=200
)

plt.close()


# =============================================================================
# 11. Subgroup evaluation
# =============================================================================

print("\n" + "=" * 80)
print("Subgroup evaluation")
print("=" * 80)

# We need the original, unprocessed test data to define clinically meaningful
# subgroups. The split indices saved by preprocessing.py allow us to recover
# the corresponding original rows.

original_data_path = (
    PROJECT_ROOT /
    "results" /
    "final_dataset.csv"
)

original_df = pd.read_csv(
    original_data_path
)


split_path = (
    PREPROCESSING_DIR /
    "split_indices.json"
)

import json

with open(
    split_path,
    "r"
) as f:

    split_indices = json.load(f)


test_indices = [
    int(i)
    for i in split_indices["test_indices"]
]


original_test = (
    original_df
    .loc[test_indices]
    .copy()
)


# =============================================================================
# 12. Generate test predictions
# =============================================================================

test_predictions = pd.DataFrame(
    {
        "logistic_regression":
            logistic_model.predict_proba(X_test)[:, 1],

        "random_forest":
            random_forest_model.predict_proba(X_test)[:, 1],

        "gradient_boosting":
            gradient_boosting_model.predict_proba(X_test)[:, 1],
    }
)


# Ensure ordering matches original_test.

test_predictions.index = (
    original_test.index
)


# =============================================================================
# 13. Define clinically interpretable subgroups
# =============================================================================

subgroups = {}


if "age_at_icu_admission" in original_test.columns:

    age = (
        original_test[
            "age_at_icu_admission"
        ]
    )

    subgroups["age_<65"] = (
        age < 65
    )

    subgroups["age_65_79"] = (
        (age >= 65) &
        (age < 80)
    )

    subgroups["age_80+"] = (
        age >= 80
    )


if "gender" in original_test.columns:

    subgroups["gender_M"] = (
        original_test["gender"] == "M"
    )

    subgroups["gender_F"] = (
        original_test["gender"] == "F"
    )


if "mechanical_ventilation_24h" in original_test.columns:

    subgroups["ventilated"] = (
        original_test[
            "mechanical_ventilation_24h"
        ] == 1
    )

    subgroups["not_ventilated"] = (
        original_test[
            "mechanical_ventilation_24h"
        ] == 0
    )


if "vasopressor_any_24h" in original_test.columns:

    subgroups["vasopressor"] = (
        original_test[
            "vasopressor_any_24h"
        ] == 1
    )

    subgroups["no_vasopressor"] = (
        original_test[
            "vasopressor_any_24h"
        ] == 0
    )


# =============================================================================
# 14. Calculate subgroup performance
# =============================================================================

subgroup_records = []


for subgroup_name, mask in subgroups.items():

    mask = mask.fillna(False)

    n = int(mask.sum())

    if n < 50:
        continue

    y_subgroup = (
        y_test.loc[mask]
    )

    if y_subgroup.nunique() < 2:
        continue

    for model_name in test_predictions.columns:

        probability = (
            test_predictions
            .loc[mask, model_name]
        )

        subgroup_records.append(
            {
                "subgroup": subgroup_name,

                "model": model_name,

                "n": n,

                "events": int(
                    y_subgroup.sum()
                ),

                "mortality_rate":
                    float(
                        y_subgroup.mean()
                    ),

                "roc_auc":
                    roc_auc_score(
                        y_subgroup,
                        probability
                    ),

                "average_precision":
                    average_precision_score(
                        y_subgroup,
                        probability
                    ),
            }
        )


subgroup_performance = pd.DataFrame(
    subgroup_records
)


subgroup_performance.to_csv(
    OUTPUT_DIR /
    "subgroup_performance.csv",
    index=False
)


# =============================================================================
# 15. Print subgroup results
# =============================================================================

if len(subgroup_performance) > 0:

    print(
        subgroup_performance.to_string(
            index=False
        )
    )

else:

    print(
        "No subgroup contained enough observations/events for analysis."
    )


# =============================================================================
# 16. Final output
# =============================================================================

print("\n" + "=" * 80)
print("Interpretation complete")
print("=" * 80)

print(
    f"\nOutputs written to:\n{OUTPUT_DIR}"
)

print(
    "\nReminder:"
)

print(
    "Feature importance describes predictive contribution, "
    "not causal effect."
)
