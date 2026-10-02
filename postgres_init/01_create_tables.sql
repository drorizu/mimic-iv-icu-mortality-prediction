-- Create schemas --
DROP SCHEMA IF EXISTS mimiciv_hosp CASCADE;
CREATE SCHEMA mimiciv_hosp;
DROP SCHEMA IF EXISTS mimiciv_icu CASCADE;
CREATE SCHEMA mimiciv_icu;
DROP SCHEMA IF EXISTS mimiciv_derived CASCADE;
CREATE SCHEMA mimiciv_derived;

-- Create the admissions table in the mimiciv_hosp schema--
DROP TABLE IF EXISTS mimiciv_hosp.admissions;
CREATE TABLE mimiciv_hosp.admissions
(
  subject_id INTEGER NOT NULL,
  hadm_id INTEGER NOT NULL,
  admittime TIMESTAMP NOT NULL,
  dischtime TIMESTAMP,
  deathtime TIMESTAMP,
  admission_type VARCHAR(40) NOT NULL,
  admit_provider_id VARCHAR(10),
  admission_location VARCHAR(60),
  discharge_location VARCHAR(60),
  insurance VARCHAR (255),
  language VARCHAR (30),
  marital_status VARCHAR(30),
  race VARCHAR(80),
  edregtime TIMESTAMP,
  edouttime TIMESTAMP,
  hospital_expire_flag SMALLINT
);

-- Create the Healthcare Common Procedure Coding System (hcpcs) table in the mimiciv_hosp schema --
DROP TABLE IF EXISTS mimiciv_hosp.d_hcpcs;
CREATE TABLE mimiciv_hosp.d_hcpcs
(
  code CHAR(5) NOT NULL,
  category SMALLINT,
  long_description TEXT,
  short_description VARCHAR(180)
);

