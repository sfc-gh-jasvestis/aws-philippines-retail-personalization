-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Consumer Insights & Personalization Engine
-- ============================================================================
USE DATABASE CONSUMER_INSIGHTS;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.PRODUCT_SEARCH
  ON PRODUCT_DESCRIPTION
  ATTRIBUTES CATEGORY, BRAND, PRICE_TIER
  WAREHOUSE = CONSUMER_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.PRODUCT_CATALOG
);
