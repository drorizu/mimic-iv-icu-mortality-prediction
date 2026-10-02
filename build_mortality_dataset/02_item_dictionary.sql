 /*
 ===============================================================================
 02_item_dictionary.sql

 Purpose:
     Build a centralized dictionary of MIMIC-IV item IDs used by the
     mortality prediction pipeline.

 Sources:
     mimiciv_icu.d_items
     mimiciv_hosp.d_labitems

 Important:
     This file is a REFERENCE DICTIONARY.

     Do not assume every item returned here should automatically become
     a model feature. The downstream SQL files explicitly select the
     variables they need.

 Categories:
     - VITAL
     - LAB
     - VENTILATION
     - PRESSOR
     - URINE_OUTPUT

 ===============================================================================
 */


-- ============================================================================
-- 1. ICU item dictionary
-- ============================================================================

WITH icu_dictionary AS (

    SELECT
        itemid,
        label,
        abbreviation,
        linksto,
        category,
        unitname,
        param_type,
        lownormalvalue,
        highnormalvalue,

        CASE

            -- ---------------------------------------------------------------
            -- Vital signs
            -- ---------------------------------------------------------------

            WHEN LOWER(label) LIKE '%heart rate%'
                THEN 'heart_rate'

            WHEN LOWER(label) LIKE '%respiratory rate%'
                THEN 'respiratory_rate'

            WHEN LOWER(label) LIKE '%oxygen saturation%'
                OR LOWER(label) LIKE '%spo2%'
                THEN 'spo2'

            WHEN LOWER(label) LIKE '%systolic%'
                THEN 'systolic_bp'

            WHEN LOWER(label) LIKE '%diastolic%'
                THEN 'diastolic_bp'

            WHEN LOWER(label) LIKE '%mean arterial%'
                THEN 'mean_arterial_pressure'

            WHEN LOWER(label) LIKE '%temperature%'
                THEN 'temperature'

            WHEN LOWER(label) LIKE '%gcs%'
                OR LOWER(label) LIKE '%glasgow%'
                THEN 'gcs'


            -- ---------------------------------------------------------------
            -- Mechanical ventilation / respiratory support
            -- ---------------------------------------------------------------

            WHEN LOWER(label) LIKE '%ventilator%'
                THEN 'mechanical_ventilation'

            WHEN LOWER(label) LIKE '%ventilation%'
                THEN 'mechanical_ventilation'

            WHEN LOWER(label) LIKE '%invasive ventilation%'
                THEN 'mechanical_ventilation'


            -- ---------------------------------------------------------------
            -- Vasopressors
            -- ---------------------------------------------------------------

            WHEN LOWER(label) LIKE '%norepinephrine%'
                THEN 'norepinephrine'

            WHEN LOWER(label) LIKE '%noradrenaline%'
                THEN 'norepinephrine'

            WHEN LOWER(label) LIKE '%epinephrine%'
                THEN 'epinephrine'

            WHEN LOWER(label) LIKE '%adrenaline%'
                THEN 'epinephrine'

            WHEN LOWER(label) LIKE '%vasopressin%'
                THEN 'vasopressin'

            WHEN LOWER(label) LIKE '%phenylephrine%'
                THEN 'phenylephrine'

            WHEN LOWER(label) LIKE '%dopamine%'
                THEN 'dopamine'


            -- ---------------------------------------------------------------
            -- Urine output
            -- ---------------------------------------------------------------

            WHEN LOWER(label) LIKE '%urine output%'
                THEN 'urine_output'

            WHEN LOWER(label) LIKE '%urine volume%'
                THEN 'urine_output'


            ELSE NULL

        END AS variable_name

    FROM mimiciv_icu.d_items
),


-- ============================================================================
-- 2. Hospital laboratory dictionary
-- ============================================================================

lab_dictionary AS (

    SELECT
        itemid,
        label,
        fluid,
        category,

        CASE

            -- ---------------------------------------------------------------
            -- Electrolytes / chemistry
            -- ---------------------------------------------------------------

            WHEN LOWER(label) IN ('sodium', 'sodium, serum')
                THEN 'sodium'

            WHEN LOWER(label) IN ('potassium', 'potassium, serum')
                THEN 'potassium'

            WHEN LOWER(label) IN ('chloride', 'chloride, serum')
                THEN 'chloride'

            WHEN LOWER(label) LIKE '%bicarbonate%'
                THEN 'bicarbonate'

            WHEN LOWER(label) IN ('urea nitrogen', 'bun')
                THEN 'bun'

            WHEN LOWER(label) IN ('creatinine', 'creatinine, serum')
                THEN 'creatinine'

            WHEN LOWER(label) LIKE '%glucose%'
                THEN 'glucose'


            -- ---------------------------------------------------------------
            -- Hematology
            -- ---------------------------------------------------------------

            WHEN LOWER(label) IN ('hemoglobin', 'hemoglobin, blood')
                THEN 'hemoglobin'

            WHEN LOWER(label) IN ('hematocrit', 'hematocrit, blood')
                THEN 'hematocrit'

            WHEN LOWER(label) LIKE '%white blood cell%'
                THEN 'wbc'

            WHEN LOWER(label) LIKE '%platelet%'
                THEN 'platelets'


            -- ---------------------------------------------------------------
            -- Liver / nutrition
            -- ---------------------------------------------------------------

            WHEN LOWER(label) LIKE '%albumin%'
                THEN 'albumin'

            WHEN LOWER(label) LIKE '%bilirubin, total%'
                THEN 'bilirubin_total'

            WHEN LOWER(label) LIKE '%bilirubin%'
                AND LOWER(label) NOT LIKE '%direct%'
                AND LOWER(label) NOT LIKE '%indirect%'
                THEN 'bilirubin_total'

            WHEN LOWER(label) IN ('ast', 'aspartate aminotransferase')
                THEN 'ast'

            WHEN LOWER(label) IN ('alt', 'alanine aminotransferase')
                THEN 'alt'


            -- ---------------------------------------------------------------
            -- Calcium / magnesium / phosphate
            -- ---------------------------------------------------------------

            WHEN LOWER(label) LIKE '%calcium%'
                THEN 'calcium'

            WHEN LOWER(label) LIKE '%magnesium%'
                THEN 'magnesium'

            WHEN LOWER(label) LIKE '%phosphate%'
                THEN 'phosphate'


            -- ---------------------------------------------------------------
            -- Lactate
            -- ---------------------------------------------------------------

            WHEN LOWER(label) LIKE '%lactate%'
                THEN 'lactate'


            -- ---------------------------------------------------------------
            -- Coagulation
            -- ---------------------------------------------------------------

            WHEN LOWER(label) LIKE '%inr%'
                THEN 'inr'

            WHEN LOWER(label) LIKE '%ptt%'
                OR LOWER(label) LIKE '%partial thromboplastin%'
                THEN 'ptt'


            -- ---------------------------------------------------------------
            -- Blood gas
            -- ---------------------------------------------------------------

            WHEN LOWER(label) IN ('ph', 'pH')
                THEN 'ph'

            WHEN LOWER(label) LIKE '%pao2%'
                OR LOWER(label) LIKE '%po2%'
                THEN 'pao2'

            WHEN LOWER(label) LIKE '%paco2%'
                OR LOWER(label) LIKE '%pco2%'
                THEN 'paco2'


            ELSE NULL

        END AS variable_name

    FROM mimiciv_hosp.d_labitems
)


-- ============================================================================
-- 3. Unified dictionary
-- ============================================================================

SELECT
    'icu' AS source_table,
    itemid,
    label,
    abbreviation,
    linksto,
    category,
    unitname,
    param_type,
    lownormalvalue,
    highnormalvalue,
    NULL::text AS fluid,
    variable_name

FROM icu_dictionary

WHERE variable_name IS NOT NULL


UNION ALL


SELECT
    'lab' AS source_table,
    itemid,
    label,
    NULL::text AS abbreviation,
    NULL::text AS linksto,
    category,
    NULL::text AS unitname,
    NULL::text AS param_type,
    NULL::double precision AS lownormalvalue,
    NULL::double precision AS highnormalvalue,
    fluid,
    variable_name

FROM lab_dictionary

WHERE variable_name IS NOT NULL

ORDER BY
    source_table,
    variable_name,
    itemid
;
