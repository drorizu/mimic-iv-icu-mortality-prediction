SET search_path TO mimic_hosp;
DROP INDEX IF EXISTS admissions-idx01;
CREATE INDEX admissions-idx01
 ON admissions (admittime, dischtime, deathtime);
