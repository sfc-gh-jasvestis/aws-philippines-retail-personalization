-- ============================================================================
-- 03_STAGING.SQL — Generate synthetic data for Consumer Insights & Personalization Engine
-- Country: PHILIPPINES | Currency: PHP
-- ============================================================================
USE DATABASE CONSUMER_INSIGHTS;
USE SCHEMA RAW;

-- Data generation scripts are demo-specific.
-- See the handcrafted SQL in the aws-malaysia-semiconductor-yield demo for
-- the full pattern: GENERATOR + UNIFORM + LATERAL for distribution,
-- Cortex Complete for text generation, engineered key demo numbers.

-- Target row counts:
-- CUSTOMERS: 2,800,000 rows — Customer profiles with demographics and preferences
-- BROWSE_EVENTS: 45,000,000 rows — 30 days of browsing behavior from Kinesis
-- PURCHASE_HISTORY: 8,500,000 rows — 12 months of purchase transactions
-- CAMPAIGN_RESPONSES: 12,000,000 rows — Email/SMS/push campaign interaction data
-- PRODUCT_CATALOG: 85,000 rows — Full product catalog with attributes and margins
-- LOYALTY_POINTS: 1,800,000 rows — Loyalty program activity (earn/burn/tier)
