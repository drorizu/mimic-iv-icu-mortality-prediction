"""
===============================================================================
03_models.py

Purpose:
    Train baseline ICU mortality prediction models.

Models:
    1. Logistic regression
    2. Random forest
    3. HistGradientBoostingClassifier

Input:
    results/preprocessing/train_processed.csv
    results/preprocessing/test_processed.csv

Output:
    results/models/
        logistic_regression.joblib
        random_forest.joblib
        gradient_boosting.joblib
        test_predictions.csv
        model_summary.csv

Important:
    - Models are trained only on the training set.
    - The test set is used only to generate predictions.
    - Model selection should ultimately be performed using validation data,
      not repeatedly using the final test set.
===============================================================================
"""

from pathlib import Path

import joblib
import numpy as np
import pandas as pd

from sklearn.ensemble import (
    RandomForestClassifier,
    HistGradientBoostingClassifier,
)

from sklearn.linear_model import LogisticRegression

from sklearn.metrics import (
    roc_auc_score,
    average_precision_score,
)

from sklearn.inspection import permutation_importance


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

OUTPUT_DIR = (
    PROJECT_ROOT /
    "results" /
    "models"
)

OUTPUT_DIR.mkdir(
    parents=True,
    exist_ok=True
)


# =============================================================================
# 1. Load processed data
# =============================================================================

print("=" * 80)
print("Loading processed data")
print("=" * 80)

train = pd.read_csv(
    PREPROCESSING_DIR /
    "train_processed.csv"
)

test = pd.read_csv(
    PREPROCESSING_DIR /
    "test_processed.csv"
)


# =============================================================================
# 2. Separate X and y
# =============================================================================

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

print(
    f"Training mortality: {y_train.mean():.4f}"
)

print(
    f"Test mortality:     {y_test.mean():.4f}"
)


# =============================================================================
# 3. Define models
# =============================================================================

models = {

    "logistic_regression": LogisticRegression(
        max_iter=2000,

        class_weight="balanced",

        C=1.0,

        solver="lbfgs",

        random_state=RANDOM_STATE,
    ),


    "random_forest": RandomForestClassifier(

        n_estimators=500,

        max_depth=None,

        min_samples_leaf=5,

        max_features="sqrt",

        class_weight="balanced",

        n_jobs=-1,

        random_state=RANDOM_STATE,
    ),


    "gradient_boosting": HistGradientBoostingClassifier(

        max_iter=300,

        learning_rate=0.05,

        max_leaf_nodes=31,

        l2_regularization=1.0,

        random_state=RANDOM_STATE,
    ),
}


# =============================================================================
# 4. Train models
# =============================================================================

predictions = pd.DataFrame(
    {
        "y_true": y_test.values
    }
)

model_results = []


for model_name, model in models.items():

    print("\n" + "=" * 80)
    print(f"Training: {model_name}")
    print("=" * 80)

    model.fit(
        X_train,
        y_train
    )

    # -------------------------------------------------------------------------
    # Predicted probability
    # -------------------------------------------------------------------------

    y_probability = model.predict_proba(
        X_test
    )[:, 1]

    # -------------------------------------------------------------------------
    # Basic metrics
    # -------------------------------------------------------------------------

    roc_auc = roc_auc_score(
        y_test,
        y_probability
    )

    average_precision = average_precision_score(
        y_test,
        y_probability
    )

    print(
        f"ROC-AUC:           {roc_auc:.4f}"
    )

    print(
        f"Average precision: {average_precision:.4f}"
    )

    # -------------------------------------------------------------------------
    # Save predictions
    # -------------------------------------------------------------------------

    predictions[
        f"{model_name}_probability"
    ] = y_probability

    # -------------------------------------------------------------------------
    # Save model
    # -------------------------------------------------------------------------

    model_path = (
        OUTPUT_DIR /
        f"{model_name}.joblib"
    )

    joblib.dump(
        model,
        model_path
    )

    print(
        f"Saved model: {model_path}"
    )

    # -------------------------------------------------------------------------
    # Store summary
    # -------------------------------------------------------------------------

    model_results.append(
        {
            "model": model_name,
            "roc_auc": roc_auc,
            "average_precision": average_precision,
        }
    )


# =============================================================================
# 5. Save predictions
# =============================================================================

prediction_path = (
    OUTPUT_DIR /
    "test_predictions.csv"
)

predictions.to_csv(
    prediction_path,
    index=False
)


# =============================================================================
# 6. Save model summary
# =============================================================================

model_summary = pd.DataFrame(
    model_results
)

model_summary.to_csv(
    OUTPUT_DIR /
    "model_summary.csv",
    index=False
)


# =============================================================================
# 7. Permutation importance
# =============================================================================

print("\n" + "=" * 80)
print("Permutation importance")
print("=" * 80)

importance_model = models[
    "logistic_regression"
]


importance = permutation_importance(

    importance_model,

    X_test,

    y_test,

    scoring="roc_auc",

    n_repeats=5,

    random_state=RANDOM_STATE,

    n_jobs=-1,
)


importance_df = pd.DataFrame(
    {
        "feature": X_test.columns,

        "importance_mean":
            importance.importances_mean,

        "importance_std":
            importance.importances_std,
    }
)

importance_df = (
    importance_df
    .sort_values(
        "importance_mean",
        ascending=False
    )
)


importance_df.to_csv(
    OUTPUT_DIR /
    "logistic_permutation_importance.csv",

    index=False
)


print(
    importance_df.head(30).to_string(
        index=False
    )
)


# =============================================================================
# 8. Final output
# =============================================================================

print("\n" + "=" * 80)
print("Model training complete")
print("=" * 80)

print(
    f"\nOutputs written to:\n{OUTPUT_DIR}"
)

