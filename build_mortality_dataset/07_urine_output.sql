/*
===============================================================================
07_urine_output.sql

Purpose:
    Calculate urine output during the first 24 hours after ICU admission.

Prediction landmark:
    ICU admission + 24 hours

Primary features:
    - urine_output_ml_24h
    - urine_output_ml_kg_h_24h

Secondary features:
    - urine_measurement_count

Important:
    Only urine output documented before the 24-hour prediction landmark is
    included.

Weight:
    We use the patient's weight documented at/before the prediction landmark.
    If no valid weight is available, the normalized urine-output feature is
    NULL rather than using a later weight.

===============================================================================
*/


-- ============================================================================
-- 1. Identify urine-output item IDs
-- ============================================================================

WITH urine_items AS (

    SELECT *
    FROM (
        VALUES

            /*
            Common MIMIC-IV ICU urine-output item.
            Verify against your local d_items table.
            */

            (226559::integer, 'urine_output')

    ) AS x(itemid, variable_name)
),


-- ============================================================================
-- 2. Extract urine output during first 24 hours
-- ============================================================================

raw_urine AS (

    SELECT

        o.subject_id,
        o.hadm_id,
        o.stay_id,

        o.charttime,

        o.itemid,

        o.value,

        o.valueuom,

        ui.variable_name

    FROM mimiciv_icu.outputevents AS o

    INNER JOIN urine_items AS ui
        ON o.itemid = ui.itemid

    INNER JOIN cohort_24h AS c
        ON o.subject_id = c.subject_id
        AND o.hadm_id = c.hadm_id
        AND o.stay_id = c.stay_id

    WHERE

        o.charttime >= c.intime
        AND o.charttime < c.prediction_time

        AND o.value IS NOT NULL

        /*
        Urine output should be non-negative.
        */
        AND o.value >= 0
),


-- ============================================================================
-- 3. Aggregate urine output
-- ============================================================================

urine_summary AS (

    SELECT

        subject_id,
        hadm_id,
        stay_id,

        SUM(value) AS urine_output_ml_24h,

        COUNT(*) AS urine_measurement_count,

        MIN(charttime) AS first_urine_time,

        MAX(charttime) AS last_urine_time

    FROM raw_urine

    GROUP BY
        subject_id,
        hadm_id,
        stay_id
),


-- ============================================================================
-- 4. Obtain patient weight available by prediction time
-- ============================================================================

weight_measurements AS (

    SELECT

        c.subject_id,
        c.hadm_id,
        c.stay_id,

        ce.charttime,

        ce.valuenum AS weight_kg

    FROM mimiciv_icu.chartevents AS ce

    INNER JOIN cohort_24h AS c
        ON ce.subject_id = c.subject_id
        AND ce.hadm_id = c.hadm_id
        AND ce.stay_id = c.stay_id

    WHERE

        /*
        Common MIMIC-IV weight item.
        Verify against d_items.
        */

        ce.itemid IN (
            226512
        )

        AND ce.charttime <= c.prediction_time

        AND ce.valuenum IS NOT NULL

        /*
        Basic plausibility range.
        */

        AND ce.valuenum BETWEEN 20 AND 300
),


-- ============================================================================
-- 5. Select the most recent valid weight before prediction
-- ============================================================================

latest_weight AS (

    SELECT

        subject_id,
        hadm_id,
        stay_id,

        weight_kg,

        charttime AS weight_time,

        ROW_NUMBER() OVER (
            PARTITION BY
                subject_id,
                hadm_id,
                stay_id
            ORDER BY charttime DESC
        ) AS rn

    FROM weight_measurements
),


-- ============================================================================
-- 6. Combine urine output and weight
-- ============================================================================

final_features AS (

    SELECT

        c.subject_id,
        c.hadm_id,
        c.stay_id,

        COALESCE(
            us.urine_output_ml_24h,
            0
        ) AS urine_output_ml_24h,

        COALESCE(
            us.urine_measurement_count,
            0
        ) AS urine_measurement_count,

        us.first_urine_time,

        us.last_urine_time,

        lw.weight_kg,

        lw.weight_time

    FROM cohort_24h AS c

    LEFT JOIN urine_summary AS us
        ON c.subject_id = us.subject_id
        AND c.hadm_id = us.hadm_id
        AND c.stay_id = us.stay_id

    LEFT JOIN latest_weight AS lw
        ON c.subject_id = lw.subject_id
        AND c.hadm_id = lw.hadm_id
        AND c.stay_id = lw.stay_id
        AND lw.rn = 1
)


-- ============================================================================
-- 7. Final output
-- ============================================================================

SELECT

    subject_id,
    hadm_id,
    stay_id,

    urine_output_ml_24h,

    urine_measurement_count,

    first_urine_time,

    last_urine_time,

    weight_kg,

    weight_time,

    /*
    Convert 24-hour urine output into mL/kg/hour.

    If weight is unavailable, return NULL rather than inventing a weight.
    */

    CASE

        WHEN weight_kg IS NOT NULL
             AND weight_kg > 0

        THEN
            urine_output_ml_24h
            / weight_kg
            / 24.0

        ELSE NULL

    END AS urine_output_ml_kg_h_24h

FROM final_features
;
