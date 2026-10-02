/*
===============================================================================
05_ventilation.sql

Purpose:
    Identify invasive mechanical ventilation during the first 24 hours of ICU
    admission.

Prediction landmark:
    ICU admission + 24 hours

Primary feature:
    mechanical_ventilation_24h

Additional features:
    - ventilation_start
    - ventilation_end
    - ventilation_duration_hours

Important:
    Only ventilation occurring before the 24-hour prediction landmark is
    eligible.

===============================================================================
*/


-- ============================================================================
-- 1. Identify mechanical ventilation periods
-- ============================================================================

WITH ventilation_periods AS (

    SELECT
        v.subject_id,
        v.hadm_id,
        v.stay_id,

        v.starttime,
        v.endtime,

        /*
        Some records can have missing end times.
        For feature extraction we will handle these below.
        */

        CASE
            WHEN v.endtime IS NULL
                THEN 1
            ELSE 0
        END AS missing_endtime

    FROM mimiciv_derived.ventilation AS v

    INNER JOIN cohort_24h AS c
        ON v.subject_id = c.subject_id
        AND v.hadm_id = c.hadm_id
        AND v.stay_id = c.stay_id

    WHERE
        /*
        Ventilation must overlap the prediction window.
        */

        v.starttime < c.prediction_time

        AND (
            v.endtime IS NULL
            OR v.endtime > c.intime
        )
),


-- ============================================================================
-- 2. Restrict ventilation to the prediction window
-- ============================================================================

ventilation_clipped AS (

    SELECT

        vp.subject_id,
        vp.hadm_id,
        vp.stay_id,

        /*
        Start cannot precede ICU admission.
        */

        GREATEST(
            vp.starttime,
            c.intime
        ) AS ventilation_start,

        /*
        End cannot extend beyond the 24-hour prediction landmark.
        */

        LEAST(
            COALESCE(
                vp.endtime,
                c.prediction_time
            ),
            c.prediction_time
        ) AS ventilation_end,

        c.intime,
        c.prediction_time

    FROM ventilation_periods AS vp

    INNER JOIN cohort_24h AS c
        ON vp.subject_id = c.subject_id
        AND vp.hadm_id = c.hadm_id
        AND vp.stay_id = c.stay_id
),


-- ============================================================================
-- 3. Remove invalid intervals
-- ============================================================================

valid_ventilation AS (

    SELECT
        *
    FROM ventilation_clipped

    WHERE ventilation_end > ventilation_start
),


-- ============================================================================
-- 4. Summarize ventilation exposure
-- ============================================================================

ventilation_summary AS (

    SELECT

        subject_id,
        hadm_id,
        stay_id,

        MIN(ventilation_start) AS ventilation_start,

        MAX(ventilation_end) AS ventilation_end,

        SUM(
            EXTRACT(
                EPOCH FROM (
                    ventilation_end - ventilation_start
                )
            ) / 3600.0
        ) AS ventilation_duration_hours

    FROM valid_ventilation

    GROUP BY
        subject_id,
        hadm_id,
        stay_id
)


-- ============================================================================
-- 5. Produce one row per ICU stay
-- ============================================================================

SELECT

    c.subject_id,
    c.hadm_id,
    c.stay_id,

    /*
    Primary feature:
        1 = invasive mechanical ventilation occurred during the first 24h
        0 = no invasive mechanical ventilation identified
    */

    CASE
        WHEN vs.stay_id IS NOT NULL
            THEN 1
        ELSE 0
    END AS mechanical_ventilation_24h,

    vs.ventilation_start,

    vs.ventilation_end,

    COALESCE(
        vs.ventilation_duration_hours,
        0
    ) AS ventilation_duration_hours

FROM cohort_24h AS c

LEFT JOIN ventilation_summary AS vs
    ON c.subject_id = vs.subject_id
    AND c.hadm_id = vs.hadm_id
    AND c.stay_id = vs.stay_id
;
