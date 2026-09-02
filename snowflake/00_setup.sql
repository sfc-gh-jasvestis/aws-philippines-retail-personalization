-- Generated from generator/demo_specs/aws-philippines-retail-personalization.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-philippines-retail-personalization
-- This is the schema that is actually deployed for PH_RETAIL_PERSONALIZATION.

-- PH_RETAIL_PERSONALIZATION  (Consumer Insights & Personalization Engine)
-- generated from generator/demo_specs/aws-philippines-retail-personalization.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS PH_RETAIL_PERSONALIZATION;
CREATE SCHEMA IF NOT EXISTS PH_RETAIL_PERSONALIZATION.RAW;
CREATE SCHEMA IF NOT EXISTS PH_RETAIL_PERSONALIZATION.CURATED;
CREATE SCHEMA IF NOT EXISTS PH_RETAIL_PERSONALIZATION.APP;
USE DATABASE PH_RETAIL_PERSONALIZATION;

-- 5 real regions; entity names carry their region so the two always agree
