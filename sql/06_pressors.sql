/*
===============================================================================
06_pressors.sql

Purpose:
    Identify vasopressor exposure during the first 24 hours after ICU
    admission.

Prediction landmark:
    ICU admission + 24 hours

Primary features:
    - vasopressor_any_24h
    - norepinephrine_24h
    - epinephrine_24h
    - vasopressin_24h
    - phenylephrine_24h
    - dopamine_24h

Secondary features:
    - first pressor time
    - last pressor time
    - pressor exposure duration

Important:
    Drug administration must occur before prediction_time.

===============================================================================
*/


-- ============================================================================
-- 1. Define vasopressor item IDs
-- ============================================================================

WITH pressor_items AS (

    SELECT *
    FROM (
        VALUES

            /*
            Verify these item IDs against your local MIMIC-IV installation.
            */

            (221906::integer, 'norepinephrine'),

            (221289::integer, 'epinephrine'),

            (222315::integer, 'vasopressin'),

            (221749::integer, 'phenylephrine'),

            (221662::integer, 'dopamine')

    ) AS x(itemid, pressor_name)
),


-- ============================================================================
-- 2. Extract vasopressor administration records
-- ============================================================================

raw_pressors AS (

    SELECT

        c.subject_id,
        c.hadm_id,
        c.stay_id,

        c.starttime,
        c.endtime,

        pi.pressor_name,

        c.rate,
        c.amount,
        c.amountuom,
        c.rateuom

    FROM mimiciv_icu.inputevents AS c

    INNER JOIN pressor_items AS pi
        ON c.itemid = pi.itemid

    INNER JOIN cohort_24h AS co
        ON c.subject_id = co.subject_id
        AND c.hadm_id = co.hadm_id
        AND c.stay_id = co.stay_id

    WHERE

        /*
        Administration must overlap the first 24 hours.
        */

        c.starttime < co.prediction_time

        AND (
            c.endtime IS NULL
            OR c.endtime > co.intime
        )
),


-- ============================================================================
-- 3. Clip administration periods to the prediction window
-- ============================================================================

clipped_pressors AS (

    SELECT

        rp.subject_id,
        rp.hadm_id,
        rp.stay_id,

        rp.pressor_name,

        GREATEST(
            rp.starttime,
            co.intime
        ) AS starttime,

        LEAST(
            COALESCE(
                rp.endtime,
                co.prediction_time
            ),
            co.prediction_time
        ) AS endtime,

        rp.rate,
        rp.amount,
        rp.amountuom,
        rp.rateuom

    FROM raw_pressors AS rp

    INNER JOIN cohort_24h AS co
        ON rp.subject_id = co.subject_id
        AND rp.hadm_id = co.hadm_id
        AND rp.stay_id = co.stay_id
),


-- ============================================================================
-- 4. Keep valid administration intervals
-- ============================================================================

valid_pressors AS (

    SELECT *

    FROM clipped_pressors

    WHERE endtime > starttime
),


-- ============================================================================
-- 5. Summarize pressor exposure
-- ============================================================================

pressor_summary AS (

    SELECT

        subject_id,
        hadm_id,
        stay_id,

        /*
        Any vasopressor
        */

        1 AS vasopressor_any_24h,

        /*
        Individual drugs
        */

        MAX(
            CASE
                WHEN pressor_name = 'norepinephrine'
                THEN 1
                ELSE 0
            END
        ) AS norepinephrine_24h,

        MAX(
            CASE
                WHEN pressor_name = 'epinephrine'
                THEN 1
                ELSE 0
            END
        ) AS epinephrine_24h,

        MAX(
            CASE
                WHEN pressor_name = 'vasopressin'
                THEN 1
                ELSE 0
            END
        ) AS vasopressin_24h,

        MAX(
            CASE
                WHEN pressor_name = 'phenylephrine'
                THEN 1
                ELSE 0
            END
        ) AS phenylephrine_24h,

        MAX(
            CASE
                WHEN pressor_name = 'dopamine'
                THEN 1
                ELSE 0
            END
        ) AS dopamine_24h,


        /*
        Timing
        */

        MIN(starttime) AS first_pressor_time,

        MAX(endtime) AS last_pressor_time,


        /*
        Total observed pressor exposure.

        NOTE:
        This sums administration intervals. It should not be interpreted
        as total drug dose.
        */

        SUM(
            EXTRACT(
                EPOCH FROM (
                    endtime - starttime
                )
            ) / 3600.0
        ) AS pressor_exposure_hours

    FROM valid_pressors

    GROUP BY
        subject_id,
        hadm_id,
        stay_id
)


-- ============================================================================
-- 6. Produce one row per ICU stay
-- ============================================================================

SELECT

    co.subject_id,
    co.hadm_id,
    co.stay_id,

    COALESCE(
        ps.vasopressor_any_24h,
        0
    ) AS vasopressor_any_24h,

    COALESCE(
        ps.norepinephrine_24h,
        0
    ) AS norepinephrine_24h,

    COALESCE(
        ps.epinephrine_24h,
        0
    ) AS epinephrine_24h,

    COALESCE(
        ps.vasopressin_24h,
        0
    ) AS vasopressin_24h,

    COALESCE(
        ps.phenylephrine_24h,
        0
    ) AS phenylephrine_24h,

    COALESCE(
        ps.dopamine_24h,
        0
    ) AS dopamine_24h,

    ps.first_pressor_time,

    ps.last_pressor_time,

    COALESCE(
        ps.pressor_exposure_hours,
        0
    ) AS pressor_exposure_hours

FROM cohort_24h AS co

LEFT JOIN pressor_summary AS ps
    ON co.subject_id = ps.subject_id
    AND co.hadm_id = ps.hadm_id
    AND co.stay_id = ps.stay_id
;

