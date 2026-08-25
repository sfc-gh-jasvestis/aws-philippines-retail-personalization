-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for Consumer Insights & Personalization Engine
-- ============================================================================
USE DATABASE CONSUMER_INSIGHTS;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_philippines_retail_personalization_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('<YOUR_EMAIL>');

-- Alert: CHURN_COHORT_ALERT
CREATE OR REPLACE ALERT APP.CHURN_COHORT_ALERT
  WAREHOUSE = CONSUMER_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'High-value customer at risk of churning'
IF (EXISTS (
  SELECT 1 FROM CURATED.CUSTOMER_360
  WHERE 1=1 -- Condition: CHURN_RISK_SCORE > 0.8 AND CLV_TIER = 'HIGH'
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_philippines_retail_personalization_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] Consumer Insights & Personalization Engine: High-value customer at risk of churning',
    'High-value customer at risk of churning'
  );

ALTER ALERT APP.CHURN_COHORT_ALERT RESUME;

-- Alert: CAMPAIGN_UNDERPERFORM_ALERT
CREATE OR REPLACE ALERT APP.CAMPAIGN_UNDERPERFORM_ALERT
  WAREHOUSE = CONSUMER_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Campaign performing below threshold'
IF (EXISTS (
  SELECT 1 FROM CURATED.CUSTOMER_360
  WHERE 1=1 -- Condition: CAMPAIGN_CTR < 50% OF TARGET
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_philippines_retail_personalization_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] Consumer Insights & Personalization Engine: Campaign performing below threshold',
    'Campaign performing below threshold'
  );

ALTER ALERT APP.CAMPAIGN_UNDERPERFORM_ALERT RESUME;

