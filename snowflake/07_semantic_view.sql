-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Consumer Insights & Personalization Engine
-- ============================================================================
USE DATABASE CONSUMER_INSIGHTS;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.CONSUMER_ANALYTICS
  COMMENT = 'Customer lifetime value, personalization, campaign, and churn analytics'
AS
  TABLES (
    CURATED.CUSTOMER_360 AS customer_360,CURATED.SEGMENT_PERFORMANCE AS segment_performance,CURATED.PRODUCT_AFFINITY AS product_affinity,CURATED.NEXT_BEST_OFFER AS next_best_offer
  );
