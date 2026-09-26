/*
===============================================================================
01_cohort.sql

Purpose:
    Define the adult first-ICU-stay cohort for the 24-hour ICU mortality model.

Study design:
    - Adults >= 18 years
    - First ICU stay per patient
    - Prediction landmark = 24 hours after ICU admission
    - Patient must survive to the 24-hour landmark
    - Outcome = in-hospital mortality after the 24-hour landmark

Unit of analysis:
    One row per patient / first ICU stay.

Output:
    cohort_24h

Important:
    All predictor variables must subsequently be restricted to:
        intime <= measurement_time < prediction_time
===============================================================================
*/

-- ============================================================================
-- 1. Identify adult ICU stays
-- ============================================================================

WITH adult_icu_stays AS (
    SELECT
        i.subject_id,
        i.hadm_id,
        i.stay_id,

        i.intime,
        i.outtime,

        i.first_careunit,
        i.last_careunit,

        i.los AS icu_los_days,

        -- Demographics
        p.gender,
        p.anchor_age,
        p.anchor_year,
        p.anchor_year_group,

        -- Hospital admission information
        a.admittime,
        a.dischtime,
        a.deathtime,
        a.admission_type,
        a.admission_location,
        a.discharge_location,
        a.insurance,
        a.marital_status,
        a.race,

        -- Hospital mortality indicator
        a.hospital_expire_flag,

        /*
        MIMIC-IV anchor_age is used with anchor_year to derive age
        at the time of admission.
        */
        (
            p.anchor_age
            + EXTRACT(YEAR FROM i.intime)::integer
            - p.anchor_year
        ) AS age_at_icu_admission

    FROM mimiciv_icu.icustays AS i

    INNER JOIN mimiciv_hosp.patients AS p
        ON i.subject_id = p.subject_id

    INNER JOIN mimiciv_hosp.admissions AS a
        ON i.hadm_id = a.hadm_id
        AND i.subject_id = a.subject_id

    WHERE
        (
            p.anchor_age
            + EXTRACT(YEAR FROM i.intime)::integer
            - p.anchor_year
        ) >= 18
),

-- ============================================================================
-- 2. Select the first ICU stay for each patient
-- ============================================================================

first_icu_stay AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY subject_id
            ORDER BY intime, stay_id
        ) AS icu_stay_number

    FROM adult_icu_stays
),

-- ============================================================================
-- 3. Define the 24-hour prediction landmark
-- ============================================================================

with_prediction_time AS (
    SELECT
        *,

        intime + INTERVAL '24 hours' AS prediction_time

    FROM first_icu_stay

    WHERE icu_stay_number = 1
),

-- ============================================================================
-- 4. Determine whether the patient survived to the prediction landmark
-- ============================================================================

eligible_cohort AS (
    SELECT
        *,

        /*
        A patient is eligible if they are alive at the 24-hour landmark.

        If deathtime is NULL:
            patient did not have a documented death during the hospitalization.

        If deathtime exists:
            death must occur at or after prediction_time.
        */

        CASE
            WHEN deathtime IS NULL THEN 1
            WHEN deathtime >= prediction_time THEN 1
            ELSE 0
        END AS survived_to_24h

    FROM with_prediction_time
)

-- ============================================================================
-- 5. Final cohort
-- ============================================================================

SELECT

    -- Identifiers
    subject_id,
    hadm_id,
    stay_id,

    -- Time variables
    intime,
    outtime,
    prediction_time,

    admittime,
    dischtime,
    deathtime,

    -- Demographics
    gender,
    age_at_icu_admission,
    anchor_age,
    anchor_year,
    anchor_year_group,

    -- ICU information
    first_careunit,
    last_careunit,
    icu_los_days,

    -- Admission information
    admission_type,
    admission_location,
    discharge_location,
    insurance,
    marital_status,
    race,

    -- Mortality information
    hospital_expire_flag,

    /*
    Primary outcome.

    1 = patient died after the 24-hour prediction landmark
    0 = patient survived to hospital discharge
    */
    CASE
        WHEN hospital_expire_flag = 1
             AND deathtime > prediction_time
        THEN 1
        ELSE 0
    END AS mortality_after_24h,

    survived_to_24h

FROM eligible_cohort

WHERE survived_to_24h = 1
;

