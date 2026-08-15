-- ============================================================================
-- 11_TASK_PIPELINE.SQL — Task DAG for Consumer Insights & Personalization Engine
-- ============================================================================
USE DATABASE CONSUMER_INSIGHTS;
USE SCHEMA APP;

CREATE OR REPLACE TASK APP.TASK_INGEST_BEHAVIOR
  WAREHOUSE = CONSUMER_WH
  SCHEDULE = 'USING CRON 0 */1 * * * UTC'
  COMMENT = 'Ingest latest browse events from Kinesis'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_SCORE_CUSTOMERS
  WAREHOUSE = CONSUMER_WH
  AFTER APP.TASK_INGEST_BEHAVIOR
  COMMENT = 'Refresh purchase intent and churn scores'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_GENERATE_OFFERS
  WAREHOUSE = CONSUMER_WH
  AFTER APP.TASK_SCORE_CUSTOMERS
  COMMENT = 'Generate personalized offers and send via SES'
AS
  SELECT 1; -- Replace with actual refresh logic

ALTER TASK APP.TASK_GENERATE_OFFERS RESUME;
ALTER TASK APP.TASK_SCORE_CUSTOMERS RESUME;
ALTER TASK APP.TASK_INGEST_BEHAVIOR RESUME;
