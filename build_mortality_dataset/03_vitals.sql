/*
===============================================================================
03_vitals.sql

Purpose:
    Extract vital-sign measurements available during the first 24 hours of
    the patient's first ICU stay.

Prediction design:
    Prediction landmark = ICU admission + 24 hours

    Only measurements satisfying:

        intime <= charttime < prediction_time

    are eligible.

Output:
    One row per ICU stay.

Features:
    Heart rate
    Systolic blood pressure
    Diastolic blood pressure
    Mean arterial pressure
    Respiratory rate
    SpO2
    Temperature
    GCS

For each variable we calculate:
    - first
    - last
    - minimum
    - maximum
    - mean

IMPORTANT:
    Verify the item IDs against your exact MIMIC-IV version before using this
    query in the final analysis.
===============================================================================
*/


-- ============================================================================
-- 1. Define the item IDs
-- ============================================================================

WITH vital_items AS (

    SELECT *
    FROM (
        VALUES

            -- Heart rate
            (220045::integer, 'heart_rate'),

            -- Blood pressure
            (220179::integer, 'systolic_bp'),
            (220180::integer, 'diastolic_bp'),
            (220181::integer, 'mean_arterial_pressure'),

            -- Respiratory rate
            (220210::integer, 'respiratory_rate'),

            -- Oxygen saturation
            (220277::integer, 'spo2'),

            -- Temperature
            (223761::integer, 'temperature'),

            -- GCS
            (223900::integer, 'gcs_total')

    ) AS x(itemid, variable_name)
),


-- ============================================================================
-- 2. Select measurements from CHARTEVENTS
-- ============================================================================

raw_vitals AS (

    SELECT
        c.subject_id,
        c.hadm_id,
        c.stay_id,

        c.charttime,

        vi.variable_name,

        c.valuenum,
        c.valueuom

    FROM mimiciv_icu.chartevents AS c

    INNER JOIN vital_items AS vi
        ON c.itemid = vi.itemid

    INNER JOIN cohort_24h AS co
        ON c.subject_id = co.subject_id
        AND c.hadm_id = co.hadm_id
        AND c.stay_id = co.stay_id

    WHERE
        c.charttime >= co.intime
        AND c.charttime < co.prediction_time

        -- Ignore rows without a numeric value
        AND c.valuenum IS NOT NULL
),


-- ============================================================================
-- 3. Remove obviously invalid physiological values
-- ============================================================================

clean_vitals AS (

    SELECT
        *
    FROM raw_vitals

    WHERE

        (
            variable_name = 'heart_rate'
            AND valuenum BETWEEN 20 AND 300
        )

        OR

        (
            variable_name = 'systolic_bp'
            AND valuenum BETWEEN 30 AND 300
        )

        OR

        (
            variable_name = 'diastolic_bp'
            AND valuenum BETWEEN 10 AND 200
        )

        OR

        (
            variable_name = 'mean_arterial_pressure'
            AND valuenum BETWEEN 20 AND 250
        )

        OR

        (
            variable_name = 'respiratory_rate'
            AND valuenum BETWEEN 1 AND 100
        )

        OR

        (
            variable_name = 'spo2'
            AND valuenum BETWEEN 50 AND 100
        )

        OR

        (
            variable_name = 'temperature'
            AND valuenum BETWEEN 25 AND 45
        )

        OR

        (
            variable_name = 'gcs_total'
            AND valuenum BETWEEN 3 AND 15
        )
),


-- ============================================================================
-- 4. Calculate summary statistics
-- ============================================================================

vital_summary AS (

    SELECT
        subject_id,
        hadm_id,
        stay_id,

        variable_name,

        MIN(valuenum) AS value_min,
        MAX(valuenum) AS value_max,
        AVG(valuenum) AS value_mean,

        -- First measurement
        (
            ARRAY_AGG(
                valuenum
                ORDER BY charttime ASC
            )
        )[1] AS value_first,

        -- Last measurement
        (
            ARRAY_AGG(
                valuenum
                ORDER BY charttime DESC
            )
        )[1] AS value_last,

        COUNT(*) AS measurement_count

    FROM clean_vitals

    GROUP BY
        subject_id,
        hadm_id,
        stay_id,
        variable_name
)


-- ============================================================================
-- 5. Convert long format to one row per ICU stay
-- ============================================================================

SELECT

    co.subject_id,
    co.hadm_id,
    co.stay_id,

    -- ------------------------------------------------------------------------
    -- Heart rate
    -- ------------------------------------------------------------------------

    MAX(
        CASE
            WHEN vs.variable_name = 'heart_rate'
            THEN vs.value_first
        END
    ) AS hr_first,

    MAX(
        CASE
            WHEN vs.variable_name = 'heart_rate'
            THEN vs.value_last
        END
    ) AS hr_last,

    MAX(
        CASE
            WHEN vs.variable_name = 'heart_rate'
            THEN vs.value_min
        END
    ) AS hr_min,

    MAX(
        CASE
            WHEN vs.variable_name = 'heart_rate'
            THEN vs.value_max
        END
    ) AS hr_max,

    MAX(
        CASE
            WHEN vs.variable_name = 'heart_rate'
            THEN vs.value_mean
        END
    ) AS hr_mean,

    MAX(
        CASE
            WHEN vs.variable_name = 'heart_rate'
            THEN vs.measurement_count
        END
    ) AS hr_measurement_count,


    -- ------------------------------------------------------------------------
    -- Systolic BP
    -- ------------------------------------------------------------------------

    MAX(
        CASE
            WHEN vs.variable_name = 'systolic_bp'
            THEN vs.value_first
        END
    ) AS sbp_first,

    MAX(
        CASE
            WHEN vs.variable_name = 'systolic_bp'
            THEN vs.value_last
        END
    ) AS sbp_last,

    MAX(
        CASE
            WHEN vs.variable_name = 'systolic_bp'
            THEN vs.value_min
        END
    ) AS sbp_min,

    MAX(
        CASE
            WHEN vs.variable_name = 'systolic_bp'
            THEN vs.value_max
        END
    ) AS sbp_max,

    MAX(
        CASE
            WHEN vs.variable_name = 'systolic_bp'
            THEN vs.value_mean
        END
    ) AS sbp_mean,


    -- ------------------------------------------------------------------------
    -- Diastolic BP
    -- ------------------------------------------------------------------------

    MAX(
        CASE
            WHEN vs.variable_name = 'diastolic_bp'
            THEN vs.value_first
        END
    ) AS dbp_first,

    MAX(
        CASE
            WHEN vs.variable_name = 'diastolic_bp'
            THEN vs.value_last
        END
    ) AS dbp_last,

    MAX(
        CASE
            WHEN vs.variable_name = 'diastolic_bp'
            THEN vs.value_min
        END
    ) AS dbp_min,

    MAX(
        CASE
            WHEN vs.variable_name = 'diastolic_bp'
            THEN vs.value_max
        END
    ) AS dbp_max,

    MAX(
        CASE
            WHEN vs.variable_name = 'diastolic_bp'
            THEN vs.value_mean
        END
    ) AS dbp_mean,


    -- ------------------------------------------------------------------------
    -- MAP
    -- ------------------------------------------------------------------------

    MAX(
        CASE
            WHEN vs.variable_name = 'mean_arterial_pressure'
            THEN vs.value_first
        END
    ) AS map_first,

    MAX(
        CASE
            WHEN vs.variable_name = 'mean_arterial_pressure'
            THEN vs.value_last
        END
    ) AS map_last,

    MAX(
        CASE
            WHEN vs.variable_name = 'mean_arterial_pressure'
            THEN vs.value_min
        END
    ) AS map_min,

    MAX(
        CASE
            WHEN vs.variable_name = 'mean_arterial_pressure'
            THEN vs.value_max
        END
    ) AS map_max,

    MAX(
        CASE
            WHEN vs.variable_name = 'mean_arterial_pressure'
            THEN vs.value_mean
        END
    ) AS map_mean,


    -- ------------------------------------------------------------------------
    -- Respiratory rate
    -- ------------------------------------------------------------------------

    MAX(
        CASE
            WHEN vs.variable_name = 'respiratory_rate'
            THEN vs.value_first
        END
    ) AS rr_first,

    MAX(
        CASE
            WHEN vs.variable_name = 'respiratory_rate'
            THEN vs.value_last
        END
    ) AS rr_last,

    MAX(
        CASE
            WHEN vs.variable_name = 'respiratory_rate'
            THEN vs.value_min
        END
    ) AS rr_min,

    MAX(
        CASE
            WHEN vs.variable_name = 'respiratory_rate'
            THEN vs.value_max
        END
    ) AS rr_max,

    MAX(
        CASE
            WHEN vs.variable_name = 'respiratory_rate'
            THEN vs.value_mean
        END
    ) AS rr_mean,


    -- ------------------------------------------------------------------------
    -- SpO2
    -- ------------------------------------------------------------------------

    MAX(
        CASE
            WHEN vs.variable_name = 'spo2'
            THEN vs.value_first
        END
    ) AS spo2_first,

    MAX(
        CASE
            WHEN vs.variable_name = 'spo2'
            THEN vs.value_last
        END
    ) AS spo2_last,

    MAX(
        CASE
            WHEN vs.variable_name = 'spo2'
            THEN vs.value_min
        END
    ) AS spo2_min,

    MAX(
        CASE
            WHEN vs.variable_name = 'spo2'
            THEN vs.value_max
        END
    ) AS spo2_max,

    MAX(
        CASE
            WHEN vs.variable_name = 'spo2'
            THEN vs.value_mean
        END
    ) AS spo2_mean,


    -- ------------------------------------------------------------------------
    -- Temperature
    -- ------------------------------------------------------------------------

    MAX(
        CASE
            WHEN vs.variable_name = 'temperature'
            THEN vs.value_first
        END
    ) AS temp_first,

    MAX(
        CASE
            WHEN vs.variable_name = 'temperature'
            THEN vs.value_last
        END
    ) AS temp_last,

    MAX(
        CASE
            WHEN vs.variable_name = 'temperature'
            THEN vs.value_min
        END
    ) AS temp_min,

    MAX(
        CASE
            WHEN vs.variable_name = 'temperature'
            THEN vs.value_max
        END
    ) AS temp_max,

    MAX(
        CASE
            WHEN vs.variable_name = 'temperature'
            THEN vs.value_mean
        END
    ) AS temp_mean,


    -- ------------------------------------------------------------------------
    -- GCS
    -- ------------------------------------------------------------------------

    MAX(
        CASE
            WHEN vs.variable_name = 'gcs_total'
            THEN vs.value_first
        END
    ) AS gcs_first,

    MAX(
        CASE
            WHEN vs.variable_name = 'gcs_total'
            THEN vs.value_last
        END
    ) AS gcs_last,

    MAX(
        CASE
            WHEN vs.variable_name = 'gcs_total'
            THEN vs.value_min
        END
    ) AS gcs_min,

    MAX(
        CASE
            WHEN vs.variable_name = 'gcs_total'
            THEN vs.value_max
        END
    ) AS gcs_max,

    MAX(
        CASE
            WHEN vs.variable_name = 'gcs_total'
            THEN vs.value_mean
        END
    ) AS gcs_mean

FROM cohort_24h AS co

LEFT JOIN vital_summary AS vs
    ON co.subject_id = vs.subject_id
    AND co.hadm_id = vs.hadm_id
    AND co.stay_id = vs.stay_id

GROUP BY
    co.subject_id,
    co.hadm_id,
    co.stay_id
;
