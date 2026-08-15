-- ============================================================================
-- Consumer Insights & Personalization Engine
-- 110M Filipino internet users, price-sensitive and mobile-first — Snowflake builds consumer profiles with ML.CLASSIFICATION, generates personalized offers via Cortex Complete, and delivers through SES at scale.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS CONSUMER_INSIGHTS;
CREATE WAREHOUSE IF NOT EXISTS CONSUMER_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE CONSUMER_INSIGHTS;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE CONSUMER_WH;
