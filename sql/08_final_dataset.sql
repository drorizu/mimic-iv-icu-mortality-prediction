/*
===============================================================================
08_final_dataset.sql

Purpose:
    Combine the cohort and all feature tables into the final modeling dataset.

Unit of analysis:
    One row per eligible first ICU stay.

Prediction:
    At 24 hours after ICU admission.

Outcome:
    In-hospital mortality occurring after the 24-hour prediction landmark.

Feature windows:
    ICU admission <= measurement time < prediction time

Inputs:
    cohort_24h
    vitals_24h
    labs_24h
    ventilation_24h
    pressors_24h
    urine_output_24h

Output:
    final_dataset

===============================================================================
*/


-- ============================================================================
-- 1. Drop previous version
-- ============================================================================

DROP TABLE IF EXISTS final_dataset;


-- ============================================================================
-- 2. Build final dataset
-- ============================================================================

CREATE TABLE final_dataset AS

SELECT

    -- ========================================================================
    -- IDENTIFIERS
    -- ========================================================================

    c.subject_id,
    c.hadm_id,
    c.stay_id,


    -- ========================================================================
    -- PREDICTION TIME
    -- ========================================================================

    c.intime,
    c.prediction_time,


    -- ========================================================================
    -- DEMOGRAPHICS
    -- ========================================================================

    c.age_at_icu_admission,
    c.gender,

    c.first_careunit,
    c.last_careunit,

    c.admission_type,
    c.admission_location,

    c.insurance,
    c.marital_status,
    c.race,


    -- ========================================================================
    -- OUTCOME
    -- ========================================================================

    c.mortality_after_24h,


    -- ========================================================================
    -- VITAL SIGNS
    -- ========================================================================

    v.hr_first,
    v.hr_last,
    v.hr_min,
    v.hr_max,
    v.hr_mean,
    v.hr_measurement_count,

    v.sbp_first,
    v.sbp_last,
    v.sbp_min,
    v.sbp_max,
    v.sbp_mean,

    v.dbp_first,
    v.dbp_last,
    v.dbp_min,
    v.dbp_max,
    v.dbp_mean,

    v.map_first,
    v.map_last,
    v.map_min,
    v.map_max,
    v.map_mean,

    v.rr_first,
    v.rr_last,
    v.rr_min,
    v.rr_max,
    v.rr_mean,

    v.spo2_first,
    v.spo2_last,
    v.spo2_min,
    v.spo2_max,
    v.spo2_mean,

    v.temp_first,
    v.temp_last,
    v.temp_min,
    v.temp_max,
    v.temp_mean,

    v.gcs_first,
    v.gcs_last,
    v.gcs_min,
    v.gcs_max,
    v.gcs_mean,


    -- ========================================================================
    -- LABORATORY VALUES
    -- ========================================================================

    l.sodium_first,
    l.sodium_last,
    l.sodium_min,
    l.sodium_max,
    l.sodium_mean,

    l.potassium_first,
    l.potassium_last,
    l.potassium_min,
    l.potassium_max,
    l.potassium_mean,

    l.chloride_first,
    l.chloride_last,
    l.chloride_min,
    l.chloride_max,
    l.chloride_mean,

    l.bicarbonate_first,
    l.bicarbonate_last,
    l.bicarbonate_min,
    l.bicarbonate_max,
    l.bicarbonate_mean,

    l.bun_first,
    l.bun_last,
    l.bun_min,
    l.bun_max,
    l.bun_mean,

    l.creatinine_first,
    l.creatinine_last,
    l.creatinine_min,
    l.creatinine_max,
    l.creatinine_mean,

    l.glucose_first,
    l.glucose_last,
    l.glucose_min,
    l.glucose_max,
    l.glucose_mean,

    l.hemoglobin_first,
    l.hemoglobin_last,
    l.hemoglobin_min,
    l.hemoglobin_max,
    l.hemoglobin_mean,

    l.wbc_first,
    l.wbc_last,
    l.wbc_min,
    l.wbc_max,
    l.wbc_mean,

    l.platelets_first,
    l.platelets_last,
    l.platelets_min,
    l.platelets_max,
    l.platelets_mean,

    l.bilirubin_first,
    l.bilirubin_last,
    l.bilirubin_min,
    l.bilirubin_max,
    l.bilirubin_mean,

    l.albumin_first,
    l.albumin_last,
    l.albumin_min,
    l.albumin_max,
    l.albumin_mean,

    l.ast_first,
    l.ast_last,
    l.ast_min,
    l.ast_max,
    l.ast_mean,

    l.alt_first,
    l.alt_last,
    l.alt_min,
    l.alt_max,
    l.alt_mean,

    l.calcium_first,
    l.calcium_last,
    l.calcium_min,
    l.calcium_max,
    l.calcium_mean,

    l.magnesium_first,
    l.magnesium_last,
    l.magnesium_min,
    l.magnesium_max,
    l.magnesium_mean,

    l.phosphate_first,
    l.phosphate_last,
    l.phosphate_min,
    l.phosphate_max,
    l.phosphate_mean,

    l.lactate_first,
    l.lactate_last,
    l.lactate_min,
    l.lactate_max,
    l.lactate_mean,

    l.inr_first,
    l.inr_last,
    l.inr_min,
    l.inr_max,
    l.inr_mean,

    l.ptt_first,
    l.ptt_last,
    l.ptt_min,
    l.ptt_max,
    l.ptt_mean,

    l.ph_first,
    l.ph_last,
    l.ph_min,
    l.ph_max,
    l.ph_mean,

    l.pao2_first,
    l.pao2_last,
    l.pao2_min,
    l.pao2_max,
    l.pao2_mean,

    l.paco2_first,
    l.paco2_last,
    l.paco2_min,
    l.paco2_max,
    l.paco2_mean,


    -- ========================================================================
    -- MECHANICAL VENTILATION
    -- ========================================================================

    COALESCE(
        ve.mechanical_ventilation_24h,
        0
    ) AS mechanical_ventilation_24h,

    ve.ventilation_start,
    ve.ventilation_end,

    COALESCE(
        ve.ventilation_duration_hours,
        0
    ) AS ventilation_duration_hours,


    -- ========================================================================
    -- VASOPRESSORS
    -- ========================================================================

    COALESCE(
        p.vasopressor_any_24h,
        0
    ) AS vasopressor_any_24h,

    COALESCE(
        p.norepinephrine_24h,
        0
    ) AS norepinephrine_24h,

    COALESCE(
        p.epinephrine_24h,
        0
    ) AS epinephrine_24h,

    COALESCE(
        p.vasopressin_24h,
        0
    ) AS vasopressin_24h,

    COALESCE(
        p.phenylephrine_24h,
        0
    ) AS phenylephrine_24h,

    COALESCE(
        p.dopamine_24h,
        0
    ) AS dopamine_24h,

    p.first_pressor_time,
    p.last_pressor_time,

    COALESCE(
        p.pressor_exposure_hours,
        0
    ) AS pressor_exposure_hours,


    -- ========================================================================
    -- URINE OUTPUT
    -- ========================================================================

    u.urine_output_ml_24h,

    u.urine_output_ml_kg_h_24h,

    u.urine_measurement_count,

    u.first_urine_time,
    u.last_urine_time,

    u.weight_kg,
    u.weight_time,

    CASE
        WHEN u.urine_output_ml_24h IS NULL
            THEN 1
        ELSE 0
    END AS urine_output_missing


FROM cohort_24h AS c


-- ============================================================================
-- VITALS
-- ============================================================================

LEFT JOIN vitals_24h AS v
    ON c.subject_id = v.subject_id
    AND c.hadm_id = v.hadm_id
    AND c.stay_id = v.stay_id


-- ============================================================================
-- LABS
-- ============================================================================

LEFT JOIN labs_24h AS l
    ON c.subject_id = l.subject_id
    AND c.hadm_id = l.hadm_id
    AND c.stay_id = l.stay_id


-- ============================================================================
-- VENTILATION
-- ============================================================================

LEFT JOIN ventilation_24h AS ve
    ON c.subject_id = ve.subject_id
    AND c.hadm_id = ve.hadm_id
    AND c.stay_id = ve.stay_id


-- ============================================================================
-- PRESSORS
-- ============================================================================

LEFT JOIN pressors_24h AS p
    ON c.subject_id = p.subject_id
    AND c.hadm_id = p.hadm_id
    AND c.stay_id = p.stay_id


-- ============================================================================
-- URINE OUTPUT
-- ============================================================================

LEFT JOIN urine_output_24h AS u
    ON c.subject_id = u.subject_id
    AND c.hadm_id = u.hadm_id
    AND c.stay_id = u.stay_id
;

