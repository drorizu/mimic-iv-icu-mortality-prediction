# MIMIC-IV ICU Mortality Prediction

A reproducible machine-learning pipeline for predicting in-hospital mortality among ICU patients using data from the MIMIC-IV
 database.

The project combines SQL-based cohort construction and feature extraction with Python-based preprocessing, modeling, evaluation, and interpretation.

Important: MIMIC-IV is a restricted-access clinical database. This repository contains analysis code and does not include the underlying patient-level data.

Project Structure
```
mimic-iv-icu-mortality/
│
├── README.md
│
├── sql/
│   ├── 01_cohort.sql
│   ├── 02_item_dictionary.sql
│   ├── 03_vitals.sql
│   ├── 04_labs.sql
│   ├── 05_ventilation.sql
│   ├── 06_pressors.sql
│   ├── 07_urine_output.sql
│   └── 08_final_dataset.sql
│
├── python/
│   ├── 01_exploration.py
│   ├── 02_preprocessing.py
│   ├── 03_models.py
│   ├── 04_evaluation.py
│   └── 05_interpretation.py
│
├── notebooks/
│
├── results/
│
└── requirements.txt


##Objectives

The main objectives are to:

Construct an ICU cohort from MIMIC-IV.

Extract clinically relevant measurements during an initial ICU time window.

Generate patient-level features from vital signs, laboratory measurements, ventilation, vasopressor use, and urine output.

Train machine-learning models to predict in-hospital mortality.

Evaluate discrimination, calibration, and clinically relevant performance.

Investigate model feature importance and individual predictions.

Data

This project uses MIMIC-IV, a large de-identified electronic health record database containing information from patients admitted to Beth Israel Deaconess Medical Center.

Access to MIMIC-IV requires completion of the applicable PhysioNet credentialing and data-use requirements.

The SQL scripts assume that MIMIC-IV has been loaded into a relational database such as PostgreSQL.

Cohort Definition

The exact cohort definition is implemented in:

sql/01_cohort.sql


The cohort construction should explicitly define:

ICU admission criteria.

Adult versus pediatric patients.

Index ICU stay.

Mortality outcome.

Observation/prediction window.

Exclusion criteria.

Handling of multiple ICU admissions.

The prediction target is:

in-hospital mortality


The prediction time point and observation window should be fixed before model training to avoid using information that would not have been available at prediction time.

Feature Extraction
Item Dictionary
sql/02_item_dictionary.sql


Maps MIMIC-IV item identifiers to the clinical variables required by the project.

Vital Signs
sql/03_vitals.sql


Extracts measurements such as:

Heart rate

Systolic blood pressure

Diastolic blood pressure

Mean arterial pressure

Respiratory rate

Temperature

Oxygen saturation

Laboratory Measurements
sql/04_labs.sql


Extracts relevant laboratory measurements, for example:

Sodium

Potassium

Chloride

Bicarbonate

Creatinine

Blood urea nitrogen

Glucose

Hemoglobin

White blood cell count

Platelets

Lactate

The final variable list should be documented in the corresponding SQL file.

Mechanical Ventilation
sql/05_ventilation.sql


Creates features describing mechanical ventilation exposure during the observation window.

Vasopressors
sql/06_pressors.sql


Extracts vasopressor exposure and, where appropriate, dose-related features.

Urine Output
sql/07_urine_output.sql


Calculates urine-output-related features over the predefined observation period.

Final Dataset
sql/08_final_dataset.sql


Combines the cohort and extracted variables into the modeling dataset.

The resulting dataset should contain one modeling record per index ICU stay.

Python Pipeline
1. Exploration
python/01_exploration.py


Performs exploratory data analysis, including:

Dataset dimensions.

Missingness.

Variable distributions.

Outcome prevalence.

Basic descriptive statistics.

Potential data-quality problems.

2. Preprocessing
python/02_preprocessing.py


Handles:

Missing values.

Outliers where appropriate.

Variable transformations.

Categorical encoding.

Feature scaling where required.

Train/validation/test splitting.

Preprocessing operations that learn parameters from the data should be fitted only on the training set to prevent data leakage.

3. Model Training
python/03_models.py


Contains the machine-learning models used for mortality prediction.

Potential baseline models include:

Logistic regression.

Random forest.

Gradient boosting.

Model selection should be based on predefined evaluation criteria rather than test-set performance alone.

4. Evaluation
python/04_evaluation.py


Evaluates model performance using metrics such as:

AUROC.

AUPRC.

Sensitivity.

Specificity.

Positive predictive value.

Negative predictive value.

Calibration.

Brier score.

Because ICU mortality datasets may be imbalanced, AUPRC and calibration should be considered alongside AUROC.

The test set should be kept separate from model development and used only for final performance estimation.

5. Interpretation
python/05_interpretation.py


Provides model interpretation using appropriate techniques such as:

Feature importance.

Permutation importance.

SHAP values, where appropriate.

Individual prediction explanations.

Feature importance should not be interpreted as evidence that a variable causally affects mortality.

Reproducibility

A typical workflow is:

MIMIC-IV
   │
   ▼
01_cohort.sql
   │
   ▼
02_item_dictionary.sql
   │
   ├── 03_vitals.sql
   ├── 04_labs.sql
   ├── 05_ventilation.sql
   ├── 06_pressors.sql
   └── 07_urine_output.sql
   │
   ▼
08_final_dataset.sql
   │
   ▼
01_exploration.py
   │
   ▼
02_preprocessing.py
   │
   ▼
03_models.py
   │
   ▼
04_evaluation.py
   │
   ▼
05_interpretation.py
   │
   ▼
results/

Requirements

Python dependencies are listed in:

requirements.txt


A typical environment can be created with:

python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt


On Windows:

python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt

Results

Generated figures, tables, metrics, and model artifacts should be stored in:

results/


Examples include:

results/
├── cohort_summary.csv
├── missingness.png
├── feature_distributions.png
├── roc_curves.png
├── precision_recall_curves.png
├── calibration.png
├── model_metrics.csv
└── feature_importance.png


Large model artifacts and patient-level datasets should generally not be committed to Git.

Notebooks

The notebooks/ directory can contain exploratory or presentation-oriented notebooks.

Production/reproducible logic should remain in the sql/ and python/ directories where practical, rather than existing only inside notebooks.

Data Leakage Considerations

Clinical prediction models are particularly vulnerable to temporal leakage.

This project should ensure that:

Only information available before the prediction time is used.

Future measurements are excluded.

Outcome-related variables are not used as predictors.

Imputation parameters are learned from the training data only.

Feature-selection procedures are performed within the training process.

The test set remains untouched until final evaluation.

Limitations

Important limitations include:

MIMIC-IV represents a single healthcare system and may not generalize to other populations.

EHR measurements are irregular and subject to missingness.

Missingness itself may contain clinical information.

Retrospective observational data cannot establish causal relationships.

Model performance can change across institutions, populations, and time periods.

A model with good discrimination may still have poor calibration.

Predictions should not be interpreted as clinical recommendations without appropriate prospective validation and clinical evaluation.

Ethical Considerations

This project is intended for research and educational purposes.

Mortality predictions generated from retrospective EHR data should not be used directly for clinical decision-making. Any clinical deployment would require additional validation, governance, monitoring, and assessment of potential harms and biases.

Citation

If you use MIMIC-IV, cite the corresponding MIMIC-IV publication and follow the citation requirements specified by PhysioNet.

MIMIC-IV is available through PhysioNet:

{"fallbackMarkdown":"MIMIC-IV on PhysioNet
","reference":{"matched_text":"","prefix":null,"start_idx":8959,"end_idx":9025,"safe_urls":[],"refs":[],"alt":"MIMIC-IV on PhysioNet
","prompt_text":"MIMIC-IV on PhysioNet
","type":"url","title":"MIMIC-IV on PhysioNet","layout":null,"item":{"title":"MIMIC-IV on PhysioNet","url":"https://physionet.org/content/mimiciv/?utm_source=chatgpt.com","attribution":"physionet.org","pub_date":null,"snippet":null,"attribution_segments":null,"supporting_websites":null,"refs":[],"hue":null,"attributions":null},"logo":null},"showLoginRequiredCard":false}

License and Data Access

This repository's code license should be specified separately from the MIMIC-IV data-use terms.

Do not commit MIMIC-IV patient-level data, credentials, or other restricted-access data to this repository.
```
