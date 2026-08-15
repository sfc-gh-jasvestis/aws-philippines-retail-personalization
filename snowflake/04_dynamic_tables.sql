-- ============================================================================
-- 04_DYNAMIC_TABLES.SQL — Curated layer for Consumer Insights & Personalization Engine
-- ============================================================================
USE DATABASE CONSUMER_INSIGHTS;
USE SCHEMA CURATED;

-- CUSTOMER_360: Unified customer profile with behavior, purchases, and loyalty
-- Source: CUSTOMERS, PURCHASE_HISTORY, LOYALTY_POINTS, BROWSE_EVENTS
CREATE OR REPLACE DYNAMIC TABLE CURATED.CUSTOMER_360
  TARGET_LAG = '5 minutes'
  WAREHOUSE = CONSUMER_WH
AS
SELECT * FROM RAW.CUSTOMERS;
-- TODO: Replace with actual join/aggregation logic per demo

-- SEGMENT_PERFORMANCE: Segment-level CLV, churn risk, and campaign response rates
-- Source: CUSTOMERS, PURCHASE_HISTORY, CAMPAIGN_RESPONSES
CREATE OR REPLACE DYNAMIC TABLE CURATED.SEGMENT_PERFORMANCE
  TARGET_LAG = '5 minutes'
  WAREHOUSE = CONSUMER_WH
AS
SELECT * FROM RAW.CUSTOMERS;
-- TODO: Replace with actual join/aggregation logic per demo

-- PRODUCT_AFFINITY: Customer-product affinity scores for recommendation
-- Source: BROWSE_EVENTS, PURCHASE_HISTORY, PRODUCT_CATALOG
CREATE OR REPLACE DYNAMIC TABLE CURATED.PRODUCT_AFFINITY
  TARGET_LAG = '5 minutes'
  WAREHOUSE = CONSUMER_WH
AS
SELECT * FROM RAW.BROWSE_EVENTS;
-- TODO: Replace with actual join/aggregation logic per demo

-- NEXT_BEST_OFFER: Personalized offer candidates per customer
-- Source: CUSTOMER_360, PRODUCT_AFFINITY
CREATE OR REPLACE DYNAMIC TABLE CURATED.NEXT_BEST_OFFER
  TARGET_LAG = '5 minutes'
  WAREHOUSE = CONSUMER_WH
AS
SELECT * FROM RAW.CUSTOMER_360;
-- TODO: Replace with actual join/aggregation logic per demo

