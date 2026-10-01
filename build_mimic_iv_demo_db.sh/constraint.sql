ALTER TABLE mimic_hosp.admissions DROP CONSTRAINT
 IF EXISTS admissions_pk CASCADE;
ALTER TABLE mimic_hosp.admissions
ADD CONSTRAINT admissions_pk
 PRIMARY KEY (hadm_id);
