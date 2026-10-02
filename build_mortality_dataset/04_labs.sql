/*
===============================================================================
04_labs.sql

Purpose:
    Extract laboratory measurements available during the first 24 hours
    after ICU admission.

Prediction landmark:
    ICU admission + 24 hours

Eligibility:
    intime <= specimen_time < prediction_time

Output:
    One row per stay_id.

Features:
    - First value
    - Last value
    - Minimum
    - Maximum
    - Mean
    - Measurement count

Laboratory groups:
    Electrolytes
    Renal function
    Glucose
    Hematology
    Liver function
    Calcium / magnesium / phosphate
    Lactate
    Coagulation
    Blood gas

IMPORTANT:
    Verify item IDs and units against your local MIMIC-IV installation before
    final analysis.
===============================================================================
*/


-- ============================================================================
-- 1. Define laboratory item IDs
-- ============================================================================

WITH lab_items AS (

    SELECT *
    FROM (
        VALUES

            -- ----------------------------------------------------------------
            -- Basic chemistry
            -- ----------------------------------------------------------------

            (50971::integer, 'sodium'),
            (50824::integer, 'sodium'),

            (50822::integer, 'potassium'),
            (50972::integer, 'potassium'),

            (50806::integer, 'chloride'),
            (50902::integer, 'chloride'),

            (50882::integer, 'bicarbonate'),
            (50803::integer, 'bicarbonate'),

            (51006::integer, 'bun'),
            (51000::integer, 'creatinine'),

            (50931::integer, 'glucose'),
            (50809::integer, 'glucose'),


            -- ----------------------------------------------------------------
            -- Hematology
            -- ----------------------------------------------------------------

            (51222::integer, 'hemoglobin'),
            (51221::integer, 'hematocrit'),
            (51301::integer, 'wbc'),
            (51265::integer, 'platelets'),


            -- ----------------------------------------------------------------
            -- Liver function
            -- ----------------------------------------------------------------

            (50885::integer, 'bilirubin_total'),
            (50861::integer, 'alt'),
            (50878::integer, 'ast'),
            (50862::integer, 'albumin'),


            -- ----------------------------------------------------------------
            -- Minerals
            -- ----------------------------------------------------------------

            (50808::integer, 'calcium'),

            (50960::integer, 'magnesium'),

            (50970::integer, 'phosphate'),


            -- ----------------------------------------------------------------
            -- Lactate
            -- ----------------------------------------------------------------

            (50813::integer, 'lactate'),


            -- ----------------------------------------------------------------
            -- Coagulation
            -- ----------------------------------------------------------------

            (51237::integer, 'inr'),
            (51274::integer, 'ptt'),


            -- ----------------------------------------------------------------
            -- Blood gas
            -- ----------------------------------------------------------------

            (50820::integer, 'ph'),
            (50821::integer, 'pao2'),
            (50818::integer, 'paco2')

    ) AS x(itemid, variable_name)
),


-- ============================================================================
-- 2. Extract laboratory measurements
-- ============================================================================

raw_labs AS (

    SELECT

        l.subject_id,
        l.hadm_id,

        /*
        Labevents are hospital-level rather than ICU-level.

        We therefore associate each lab with the ICU stay based on timing.
        */
        c.stay_id,

        l.charttime,

        li.variable_name,

        l.valuenum,

        l.valueuom

    FROM mimiciv_hosp.labevents AS l

    INNER JOIN lab_items AS li
        ON l.itemid = li.itemid

    INNER JOIN cohort_24h AS c
        ON l.subject_id = c.subject_id
        AND l.hadm_id = c.hadm_id

        /*
        Associate the laboratory measurement with the first ICU stay.
        */

        AND l.charttime >= c.intime
        AND l.charttime < c.prediction_time

    WHERE
        l.valuenum IS NOT NULL
),


-- ============================================================================
-- 3. Basic plausibility filtering
-- ============================================================================

clean_labs AS (

    SELECT *

    FROM raw_labs

    WHERE

        (
            variable_name = 'sodium'
            AND valuenum BETWEEN 100 AND 200
        )

        OR

        (
            variable_name = 'potassium'
            AND valuenum BETWEEN 1 AND 15
        )

        OR

        (
            variable_name = 'chloride'
            AND valuenum BETWEEN 50 AND 160
        )

        OR

        (
            variable_name = 'bicarbonate'
            AND valuenum BETWEEN 2 AND 60
        )

        OR

        (
            variable_name = 'bun'
            AND valuenum BETWEEN 0 AND 300
        )

        OR

        (
            variable_name = 'creatinine'
            AND valuenum BETWEEN 0 AND 30
        )

        OR

        (
            variable_name = 'glucose'
            AND valuenum BETWEEN 10 AND 2000
        )

        OR

        (
            variable_name = 'hemoglobin'
            AND valuenum BETWEEN 2 AND 25
        )

        OR

        (
            variable_name = 'hematocrit'
            AND valuenum BETWEEN 5 AND 80
        )

        OR

        (
            variable_name = 'wbc'
            AND valuenum BETWEEN 0 AND 500
        )

        OR

        (
            variable_name = 'platelets'
            AND valuenum BETWEEN 1 AND 2000
        )

        OR

        (
            variable_name = 'bilirubin_total'
            AND valuenum BETWEEN 0 AND 100
        )

        OR

        (
            variable_name = 'alt'
            AND valuenum BETWEEN 0 AND 10000
        )

        OR

        (
            variable_name = 'ast'
            AND valuenum BETWEEN 0 AND 10000
        )

        OR

        (
            variable_name = 'albumin'
            AND valuenum BETWEEN 0 AND 10
        )

        OR

        (
            variable_name = 'calcium'
            AND valuenum BETWEEN 2 AND 20
        )

        OR

        (
            variable_name = 'magnesium'
            AND valuenum BETWEEN 0.5 AND 10
        )

        OR

        (
            variable_name = 'phosphate'
            AND valuenum BETWEEN 0 AND 20
        )

        OR

        (
            variable_name = 'lactate'
            AND valuenum BETWEEN 0 AND 30
        )

        OR

        (
            variable_name = 'inr'
            AND valuenum BETWEEN 0 AND 20
        )

        OR

        (
            variable_name = 'ptt'
            AND valuenum BETWEEN 0 AND 300
        )

        OR

        (
            variable_name = 'ph'
            AND valuenum BETWEEN 6 AND 8
        )

        OR

        (
            variable_name = 'pao2'
            AND valuenum BETWEEN 10 AND 700
        )

        OR

        (
            variable_name = 'paco2'
            AND valuenum BETWEEN 10 AND 200
        )
),


-- ============================================================================
-- 4. Summarize each laboratory variable
-- ============================================================================

lab_summary AS (

    SELECT

        subject_id,
        hadm_id,
        stay_id,
        variable_name,

        MIN(valuenum) AS value_min,

        MAX(valuenum) AS value_max,

        AVG(valuenum) AS value_mean,

        (
            ARRAY_AGG(
                valuenum
                ORDER BY charttime ASC
            )
        )[1] AS value_first,

        (
            ARRAY_AGG(
                valuenum
                ORDER BY charttime DESC
            )
        )[1] AS value_last,

        COUNT(*) AS measurement_count

    FROM clean_labs

    GROUP BY
        subject_id,
        hadm_id,
        stay_id,
        variable_name
)


-- ============================================================================
-- 5. Pivot into one row per ICU stay
-- ============================================================================

SELECT

    c.subject_id,
    c.hadm_id,
    c.stay_id,


    -- ========================================================================
    -- Electrolytes
    -- ========================================================================

    MAX(
        CASE
            WHEN ls.variable_name = 'sodium'
            THEN ls.value_first
        END
    ) AS sodium_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'sodium'
            THEN ls.value_last
        END
    ) AS sodium_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'sodium'
            THEN ls.value_min
        END
    ) AS sodium_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'sodium'
            THEN ls.value_max
        END
    ) AS sodium_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'sodium'
            THEN ls.value_mean
        END
    ) AS sodium_mean,


    MAX(
        CASE
            WHEN ls.variable_name = 'potassium'
            THEN ls.value_first
        END
    ) AS potassium_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'potassium'
            THEN ls.value_last
        END
    ) AS potassium_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'potassium'
            THEN ls.value_min
        END
    ) AS potassium_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'potassium'
            THEN ls.value_max
        END
    ) AS potassium_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'potassium'
            THEN ls.value_mean
        END
    ) AS potassium_mean,


    MAX(
        CASE
            WHEN ls.variable_name = 'chloride'
            THEN ls.value_first
        END
    ) AS chloride_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'chloride'
            THEN ls.value_last
        END
    ) AS chloride_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'chloride'
            THEN ls.value_min
        END
    ) AS chloride_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'chloride'
            THEN ls.value_max
        END
    ) AS chloride_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'chloride'
            THEN ls.value_mean
        END
    ) AS chloride_mean,


    MAX(
        CASE
            WHEN ls.variable_name = 'bicarbonate'
            THEN ls.value_first
        END
    ) AS bicarbonate_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'bicarbonate'
            THEN ls.value_last
        END
    ) AS bicarbonate_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'bicarbonate'
            THEN ls.value_min
        END
    ) AS bicarbonate_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'bicarbonate'
            THEN ls.value_max
        END
    ) AS bicarbonate_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'bicarbonate'
            THEN ls.value_mean
        END
    ) AS bicarbonate_mean,


    -- ========================================================================
    -- Renal function
    -- ========================================================================

    MAX(
        CASE
            WHEN ls.variable_name = 'bun'
            THEN ls.value_first
        END
    ) AS bun_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'bun'
            THEN ls.value_last
        END
    ) AS bun_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'bun'
            THEN ls.value_min
        END
    ) AS bun_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'bun'
            THEN ls.value_max
        END
    ) AS bun_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'bun'
            THEN ls.value_mean
        END
    ) AS bun_mean,


    MAX(
        CASE
            WHEN ls.variable_name = 'creatinine'
            THEN ls.value_first
        END
    ) AS creatinine_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'creatinine'
            THEN ls.value_last
        END
    ) AS creatinine_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'creatinine'
            THEN ls.value_min
        END
    ) AS creatinine_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'creatinine'
            THEN ls.value_max
        END
    ) AS creatinine_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'creatinine'
            THEN ls.value_mean
        END
    ) AS creatinine_mean,


    -- ========================================================================
    -- Glucose
    -- ========================================================================

    MAX(
        CASE
            WHEN ls.variable_name = 'glucose'
            THEN ls.value_first
        END
    ) AS glucose_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'glucose'
            THEN ls.value_last
        END
    ) AS glucose_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'glucose'
            THEN ls.value_min
        END
    ) AS glucose_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'glucose'
            THEN ls.value_max
        END
    ) AS glucose_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'glucose'
            THEN ls.value_mean
        END
    ) AS glucose_mean,


    -- ========================================================================
    -- Hematology
    -- ========================================================================

    MAX(
        CASE
            WHEN ls.variable_name = 'hemoglobin'
            THEN ls.value_first
        END
    ) AS hemoglobin_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'hemoglobin'
            THEN ls.value_last
        END
    ) AS hemoglobin_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'hemoglobin'
            THEN ls.value_min
        END
    ) AS hemoglobin_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'hemoglobin'
            THEN ls.value_max
        END
    ) AS hemoglobin_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'hemoglobin'
            THEN ls.value_mean
        END
    ) AS hemoglobin_mean,


    MAX(
        CASE
            WHEN ls.variable_name = 'wbc'
            THEN ls.value_first
        END
    ) AS wbc_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'wbc'
            THEN ls.value_last
        END
    ) AS wbc_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'wbc'
            THEN ls.value_min
        END
    ) AS wbc_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'wbc'
            THEN ls.value_max
        END
    ) AS wbc_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'wbc'
            THEN ls.value_mean
        END
    ) AS wbc_mean,


    MAX(
        CASE
            WHEN ls.variable_name = 'platelets'
            THEN ls.value_first
        END
    ) AS platelets_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'platelets'
            THEN ls.value_last
        END
    ) AS platelets_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'platelets'
            THEN ls.value_min
        END
    ) AS platelets_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'platelets'
            THEN ls.value_max
        END
    ) AS platelets_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'platelets'
            THEN ls.value_mean
        END
    ) AS platelets_mean,


    -- ========================================================================
    -- Liver function
    -- ========================================================================

    MAX(
        CASE
            WHEN ls.variable_name = 'bilirubin_total'
            THEN ls.value_first
        END
    ) AS bilirubin_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'bilirubin_total'
            THEN ls.value_last
        END
    ) AS bilirubin_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'bilirubin_total'
            THEN ls.value_min
        END
    ) AS bilirubin_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'bilirubin_total'
            THEN ls.value_max
        END
    ) AS bilirubin_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'bilirubin_total'
            THEN ls.value_mean
        END
    ) AS bilirubin_mean,


    MAX(
        CASE
            WHEN ls.variable_name = 'albumin'
            THEN ls.value_first
        END
    ) AS albumin_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'albumin'
            THEN ls.value_last
        END
    ) AS albumin_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'albumin'
            THEN ls.value_min
        END
    ) AS albumin_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'albumin'
            THEN ls.value_max
        END
    ) AS albumin_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'albumin'
            THEN ls.value_mean
        END
    ) AS albumin_mean,


    MAX(
        CASE
            WHEN ls.variable_name = 'ast'
            THEN ls.value_first
        END
    ) AS ast_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'ast'
            THEN ls.value_last
        END
    ) AS ast_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'ast'
            THEN ls.value_min
        END
    ) AS ast_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'ast'
            THEN ls.value_max
        END
    ) AS ast_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'ast'
            THEN ls.value_mean
        END
    ) AS ast_mean,


    MAX(
        CASE
            WHEN ls.variable_name = 'alt'
            THEN ls.value_first
        END
    ) AS alt_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'alt'
            THEN ls.value_last
        END
    ) AS alt_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'alt'
            THEN ls.value_min
        END
    ) AS alt_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'alt'
            THEN ls.value_max
        END
    ) AS alt_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'alt'
            THEN ls.value_mean
        END
    ) AS alt_mean,


    -- ========================================================================
    -- Minerals
    -- ========================================================================

    MAX(
        CASE
            WHEN ls.variable_name = 'calcium'
            THEN ls.value_first
        END
    ) AS calcium_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'calcium'
            THEN ls.value_last
        END
    ) AS calcium_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'calcium'
            THEN ls.value_min
        END
    ) AS calcium_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'calcium'
            THEN ls.value_max
        END
    ) AS calcium_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'calcium'
            THEN ls.value_mean
        END
    ) AS calcium_mean,


    MAX(
        CASE
            WHEN ls.variable_name = 'magnesium'
            THEN ls.value_first
        END
    ) AS magnesium_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'magnesium'
            THEN ls.value_last
        END
    ) AS magnesium_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'magnesium'
            THEN ls.value_min
        END
    ) AS magnesium_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'magnesium'
            THEN ls.value_max
        END
    ) AS magnesium_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'magnesium'
            THEN ls.value_mean
        END
    ) AS magnesium_mean,


    MAX(
        CASE
            WHEN ls.variable_name = 'phosphate'
            THEN ls.value_first
        END
    ) AS phosphate_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'phosphate'
            THEN ls.value_last
        END
    ) AS phosphate_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'phosphate'
            THEN ls.value_min
        END
    ) AS phosphate_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'phosphate'
            THEN ls.value_max
        END
    ) AS phosphate_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'phosphate'
            THEN ls.value_mean
        END
    ) AS phosphate_mean,


    -- ========================================================================
    -- Lactate
    -- ========================================================================

    MAX(
        CASE
            WHEN ls.variable_name = 'lactate'
            THEN ls.value_first
        END
    ) AS lactate_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'lactate'
            THEN ls.value_last
        END
    ) AS lactate_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'lactate'
            THEN ls.value_min
        END
    ) AS lactate_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'lactate'
            THEN ls.value_max
        END
    ) AS lactate_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'lactate'
            THEN ls.value_mean
        END
    ) AS lactate_mean,


    -- ========================================================================
    -- Coagulation
    -- ========================================================================

    MAX(
        CASE
            WHEN ls.variable_name = 'inr'
            THEN ls.value_first
        END
    ) AS inr_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'inr'
            THEN ls.value_last
        END
    ) AS inr_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'inr'
            THEN ls.value_min
        END
    ) AS inr_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'inr'
            THEN ls.value_max
        END
    ) AS inr_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'inr'
            THEN ls.value_mean
        END
    ) AS inr_mean,


    MAX(
        CASE
            WHEN ls.variable_name = 'ptt'
            THEN ls.value_first
        END
    ) AS ptt_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'ptt'
            THEN ls.value_last
        END
    ) AS ptt_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'ptt'
            THEN ls.value_min
        END
    ) AS ptt_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'ptt'
            THEN ls.value_max
        END
    ) AS ptt_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'ptt'
            THEN ls.value_mean
        END
    ) AS ptt_mean,


    -- ========================================================================
    -- Blood gas
    -- ========================================================================

    MAX(
        CASE
            WHEN ls.variable_name = 'ph'
            THEN ls.value_first
        END
    ) AS ph_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'ph'
            THEN ls.value_last
        END
    ) AS ph_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'ph'
            THEN ls.value_min
        END
    ) AS ph_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'ph'
            THEN ls.value_max
        END
    ) AS ph_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'ph'
            THEN ls.value_mean
        END
    ) AS ph_mean,


    MAX(
        CASE
            WHEN ls.variable_name = 'pao2'
            THEN ls.value_first
        END
    ) AS pao2_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'pao2'
            THEN ls.value_last
        END
    ) AS pao2_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'pao2'
            THEN ls.value_min
        END
    ) AS pao2_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'pao2'
            THEN ls.value_max
        END
    ) AS pao2_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'pao2'
            THEN ls.value_mean
        END
    ) AS pao2_mean,


    MAX(
        CASE
            WHEN ls.variable_name = 'paco2'
            THEN ls.value_first
        END
    ) AS paco2_first,

    MAX(
        CASE
            WHEN ls.variable_name = 'paco2'
            THEN ls.value_last
        END
    ) AS paco2_last,

    MAX(
        CASE
            WHEN ls.variable_name = 'paco2'
            THEN ls.value_min
        END
    ) AS paco2_min,

    MAX(
        CASE
            WHEN ls.variable_name = 'paco2'
            THEN ls.value_max
        END
    ) AS paco2_max,

    MAX(
        CASE
            WHEN ls.variable_name = 'paco2'
            THEN ls.value_mean
        END
    ) AS paco2_mean

FROM cohort_24h AS c

LEFT JOIN lab_summary AS ls
    ON c.subject_id = ls.subject_id
    AND c.hadm_id = ls.hadm_id
    AND c.stay_id = ls.stay_id

GROUP BY
    c.subject_id,
    c.hadm_id,
    c.stay_id
;
