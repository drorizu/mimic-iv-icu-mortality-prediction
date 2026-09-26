/"""
===============================================================================
02_preprocessing.py

Purpose:
    Prepare the MIMIC-IV ICU mortality dataset for machine learning.

Pipeline:
    1. Load final_dataset.csv
    2. Remove identifiers / non-predictive timestamps
    3. Validate target
    4. Train/test split
    5. Identify numeric and categorical features
    6. Median-impute numeric variables
    7. Add missing indicators for numeric variables
    8. Most-frequent-impute categorical variables
    9. One-hot encode categorical variables
   10. Standardize numeric variables
   11. Save processed train/test datasets
   12. Save fitted preprocessing pipeline

IMPORTANT:
    The preprocessing pipeline is fitted ONLY on the training set.

    Do not fit imputers, scalers, encoders, or feature-selection methods on the
    complete dataset before splitting.
===============================================================================
"""

from pathlib import Path
import json

import joblib
import numpy as np
import pandas as pd

from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler


# =============================================================================
# Configuration
# =============================================================================

RANDOM_STATE = 42

TEST_SIZE = 0.20

TARGET = "mortality_after_24h"

PROJECT_ROOT = Path(__file__).resolve().parents[1]

DATA_PATH = PROJECT_ROOT / "results" / "final_dataset.csv"

OUTPUT_DIR = PROJECT_ROOT / "results" / "preprocessing"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

PIPELINE_PATH = OUTPUT_DIR / "preprocessing_pipeline.joblib"


# =============================================================================
# 1. Load dataset
# =============================================================================

print("=" * 80)
print("Loading dataset")
print("=" * 80)

df = pd.read_csv(DATA_PATH)

print(
    f"Dataset shape: {df.shape}"
)


# =============================================================================
# 2. Validate target
# =============================================================================

if TARGET not in df.columns:
    raise ValueError(
        f"Target '{TARGET}' was not found."
    )


if df[TARGET].isna().any():
    raise ValueError(
        "Target contains missing values."
    )


if not set(df[TARGET].unique()).issubset({0, 1}):
    raise ValueError(
        "Target must contain only 0 and 1."
    )


# =============================================================================
# 3. Remove rows with invalid target
# =============================================================================

df = df.loc[
    df[TARGET].isin([0, 1])
].copy()


# =============================================================================
# 4. Identify columns that must not be model features
# =============================================================================

# These are identifiers, timestamps, or administrative variables.
#
# They are useful for auditing and joining data, but should not be given to
# the prediction model.

EXCLUDE_COLUMNS = [

    # Identifiers
    "subject_id",
    "hadm_id",
    "stay_id",

    # Absolute timestamps
    "intime",
    "prediction_time",

    # Feature timestamps
    "ventilation_start",
    "ventilation_end",
    "first_pressor_time",
    "last_pressor_time",
    "first_urine_time",
    "last_urine_time",
    "weight_time",
]


# Only exclude columns that actually exist.
EXCLUDE_COLUMNS = [
    column
    for column in EXCLUDE_COLUMNS
    if column in df.columns
]


print("\nExcluded columns:")

for column in EXCLUDE_COLUMNS:
    print(f"  - {column}")


# =============================================================================
# 5. Separate X and y
# =============================================================================

feature_columns = [
    column
    for column in df.columns
    if column not in EXCLUDE_COLUMNS
    and column != TARGET
]


X = df[feature_columns].copy()

y = df[TARGET].astype(int).copy()


print("\n" + "=" * 80)
print("Feature matrix")
print("=" * 80)

print(
    f"Number of features before preprocessing: {X.shape[1]:,}"
)

print(
    f"Number of observations: {X.shape[0]:,}"
)


# =============================================================================
# 6. Check for duplicate rows
# =============================================================================

duplicate_count = X.duplicated().sum()

print(
    f"\nDuplicate feature rows: {duplicate_count:,}"
)


# =============================================================================
# 7. Train/test split
# =============================================================================

print("\n" + "=" * 80)
print("Train/test split")
print("=" * 80)

X_train, X_test, y_train, y_test = train_test_split(

    X,
    y,

    test_size=TEST_SIZE,

    random_state=RANDOM_STATE,

    stratify=y,
)


print(
    f"Training observations: {len(X_train):,}"
)

print(
    f"Test observations:     {len(X_test):,}"
)


print(
    f"\nTraining mortality: {y_train.mean():.4f}"
)

print(
    f"Test mortality:     {y_test.mean():.4f}"
)


# =============================================================================
# 8. Identify data types
# =============================================================================

numeric_features = X_train.select_dtypes(
    include=np.number
).columns.tolist()

categorical_features = X_train.select_dtypes(
    include=[
        "object",
        "category",
        "bool",
    ]
).columns.tolist()


print("\n" + "=" * 80)
print("Feature types")
print("=" * 80)

print(
    f"Numeric features:     {len(numeric_features):,}"
)

print(
    f"Categorical features: {len(categorical_features):,}"
)


print("\nCategorical variables:")

for column in categorical_features:
    print(f"  - {column}")


# =============================================================================
# 9. Numeric preprocessing
# =============================================================================

numeric_pipeline = Pipeline(
    steps=[

        /*
        Median imputation is robust to extreme laboratory values.

        The imputer is fitted ONLY on X_train.
        */

        (
            "imputer",
            SimpleImputer(
                strategy="median",
                add_indicator=True,
            ),
        ),

        /*
        Standardization is useful for linear/logistic models.

        Tree-based models do not require scaling, but keeping a consistent
        preprocessing pipeline makes model comparisons easier.
        */

        (
            "scaler",
            StandardScaler(),
        ),
    ]
)


# =============================================================================
# 10. Categorical preprocessing
# =============================================================================

categorical_pipeline = Pipeline(
    steps=[

        (
            "imputer",
            SimpleImputer(
                strategy="most_frequent"
            ),
        ),

        (
            "onehot",
            OneHotEncoder(
                handle_unknown="ignore",
                sparse_output=False,
            ),
        ),
    ]
)


# =============================================================================
# 11. Combine preprocessing
# =============================================================================

transformers = []


if numeric_features:

    transformers.append(
        (
            "numeric",
            numeric_pipeline,
            numeric_features,
        )
    )


if categorical_features:

    transformers.append(
        (
            "categorical",
            categorical_pipeline,
            categorical_features,
        )
    )


preprocessor = ColumnTransformer(
    transformers=transformers,

    remainder="drop",

    verbose_feature_names_out=False,
)


# =============================================================================
# 12. Fit preprocessing on training data ONLY
# =============================================================================

print("\n" + "=" * 80)
print("Fitting preprocessing pipeline")
print("=" * 80)

X_train_processed = preprocessor.fit_transform(
    X_train
)

X_test_processed = preprocessor.transform(
    X_test
)


print(
    f"Processed training shape: {X_train_processed.shape}"
)

print(
    f"Processed test shape:     {X_test_processed.shape}"
)


# =============================================================================
# 13. Get processed feature names
# =============================================================================

feature_names = (
    preprocessor
    .get_feature_names_out()
    .tolist()
)


print(
    f"Processed feature count: {len(feature_names):,}"
)


# =============================================================================
# 14. Convert to DataFrames
# =============================================================================

X_train_processed = pd.DataFrame(
    X_train_processed,
    columns=feature_names,
    index=X_train.index,
)

X_test_processed = pd.DataFrame(
    X_test_processed,
    columns=feature_names,
    index=X_test.index,
)


# =============================================================================
# 15. Restore target
# =============================================================================

train_processed = X_train_processed.copy()

train_processed[TARGET] = y_train

test_processed = X_test_processed.copy()

test_processed[TARGET] = y_test


# =============================================================================
# 16. Save processed datasets
# =============================================================================

train_path = (
    OUTPUT_DIR /
    "train_processed.csv"
)

test_path = (
    OUTPUT_DIR /
    "test_processed.csv"
)

train_processed.to_csv(
    train_path,
    index=False,
)

test_processed.to_csv(
    test_path,
    index=False,
)


# =============================================================================
# 17. Save preprocessing pipeline
# =============================================================================

joblib.dump(
    preprocessor,
    PIPELINE_PATH,
)


# =============================================================================
# 18. Save feature names
# =============================================================================

feature_names_path = (
    OUTPUT_DIR /
    "feature_names.json"
)

with open(
    feature_names_path,
    "w"
) as f:

    json.dump(
        feature_names,
        f,
        indent=2,
    )


# =============================================================================
# 19. Save split indices
# =============================================================================

split_indices = {

    "train_indices": X_train.index.tolist(),

    "test_indices": X_test.index.tolist(),
}


with open(
    OUTPUT_DIR / "split_indices.json",
    "w",
) as f:

    json.dump(
        split_indices,
        f,
    )


# =============================================================================
# 20. Final validation
# =============================================================================

print("\n" + "=" * 80)
print("Final validation")
print("=" * 80)

print(
    "Training missing values:",
    X_train_processed.isna().sum().sum()
)

print(
    "Test missing values:",
    X_test_processed.isna().sum().sum()
)

print(
    "Training infinite values:",
    np.isinf(
        X_train_processed.to_numpy()
    ).sum()
)

print(
    "Test infinite values:",
    np.isinf(
        X_test_processed.to_numpy()
    ).sum()
)


# =============================================================================
# 21. Save preprocessing summary
# =============================================================================

summary = {

    "original_rows": int(len(df)),

    "original_features": int(len(feature_columns)),

    "numeric_features": int(
        len(numeric_features)
    ),

    "categorical_features": int(
        len(categorical_features)
    ),

    "processed_features": int(
        len(feature_names)
    ),

    "train_rows": int(
        len(X_train)
    ),

    "test_rows": int(
        len(X_test)
    ),

    "train_mortality": float(
        y_train.mean()
    ),

    "test_mortality": float(
        y_test.mean()
    ),

    "random_state": RANDOM_STATE,

    "test_size": TEST_SIZE,
}


with open(
    OUTPUT_DIR / "preprocessing_summary.json",
    "w",
) as f:

    json.dump(
        summary,
        f,
        indent=2,
    )


print("\n" + "=" * 80)
print("Preprocessing complete")
print("=" * 80)

print(
    f"\nOutputs written to:\n{OUTPUT_DIR}"
)

