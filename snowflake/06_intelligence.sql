-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live-offer alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes checked __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_OFFER_EVENTS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic offer-issue knowledge base (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.ISSUE_DOCS AS
WITH types AS (
  SELECT DISTINCT r.ISSUE_TYPE, a.CATEGORY
  FROM RAW.SEGMENT_DAILY r JOIN RAW.SEGMENTS a ON a.ID = r.ENTITY_ID
  WHERE r.OPTOUT_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, ISSUE_TYPE)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  ISSUE_TYPE,
  CATEGORY || ' - ' || ISSUE_TYPE || ' offer issue handling' AS TITLE,
  'Synthetic demo SOP. Category affinity: ' || CATEGORY || '. Offer issue type: ' || ISSUE_TYPE || '. '
  || 'Step 1: open a CRM case for the segment, link the campaign and pause new automated offers to the segment in the affected category until the case is triaged. '
  || 'Step 2: ' || CASE
       WHEN ISSUE_TYPE = 'Expired voucher' THEN 'check the voucher end date in the offer template, withdraw expired codes, and reissue a valid voucher to the affected members.'
       WHEN ISSUE_TYPE = 'Out-of-stock item promoted' THEN 'compare the promoted items with store stock for the city, exclude items below the stock threshold from the next send, and swap in an in-stock alternative.'
       WHEN ISSUE_TYPE = 'Wrong store price' THEN 'compare the offer price with the store price list for the city, correct the price feed, and honour the advertised price at the counter.'
       WHEN ISSUE_TYPE = 'Irrelevant recommendation' THEN 'review the recommendation rules for the category affinity, remove items outside the affinity, and run a creative refresh for the segment.'
       WHEN ISSUE_TYPE = 'Duplicate message' THEN 'check the send log for repeated sends to the segment, apply the frequency cap, and suppress the duplicate campaign.'
       WHEN ISSUE_TYPE = 'Message sent late at night' THEN 'check the scheduled send window, move sends to the 8 AM to 8 PM quiet-hours window, and re-queue held messages.'
       ELSE 'review the issue against the segment profile and escalate to the CRM lead if unexplained.'
     END
  || ' Step 3: if the ignore rate for the segment exceeds 60% or contacts per member exceed 4 per week after triage, keep the case open and reduce the send frequency. '
  || 'Step 4: record the resolution; if members opted out or reported a message as spam, honour the opt-out at once and log it for the weekly consent report.' AS CONTENT
FROM types;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.ISSUE_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, ISSUE_TYPE
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, ISSUE_TYPE, CONTENT FROM SEARCH.ISSUE_DOCS);

-- ---------- Ignore rate anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.IGNORE_RATE_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, IGNORE_RATE_PCT::FLOAT AS IGNORE_RATE
FROM RAW.SEGMENT_DAILY;
CREATE OR REPLACE VIEW ML.IGNORE_RATE_TRAIN AS
SELECT * FROM ML.IGNORE_RATE_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.IGNORE_RATE_SERIES);
CREATE OR REPLACE VIEW ML.IGNORE_RATE_DETECT AS
SELECT * FROM ML.IGNORE_RATE_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.IGNORE_RATE_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.IGNORE_RATE_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.IGNORE_RATE_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'IGNORE_RATE',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.IGNORE_RATE_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS IGNORE_RATE, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.IGNORE_RATE_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.IGNORE_RATE_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'IGNORE_RATE'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.PERSONALIZATION_ANALYTICS
  TABLES (
    segments AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      WITH SYNONYMS = ('entities', 'audiences', 'member segments')
      COMMENT = 'One row per loyalty member segment (city and category affinity), 90-day totals',
    risk AS ML.OPTOUT_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day member opt-out probability per segment',
    issues AS CURATED.ISSUE_SUMMARY PRIMARY KEY (ISSUE_TYPE)
      COMMENT = 'Offer issues, member opt-outs and spam reports by issue type, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Program-wide totals per day'
  )
  RELATIONSHIPS (risk_segment AS risk (ENTITY_ID) REFERENCES segments)
  FACTS (
    segments.issues_f AS ISSUE_COUNT,
    segments.optout_f AS OPTOUT_COUNT,
    segments.spam_f AS SPAM_REPORT_COUNT,
    segments.offers_f AS OFFER_COUNT,
    segments.sales_f AS SALES_PHP,
    segments.refresh_due_f AS REFRESH_DUE,
    segments.refresh_done_f AS REFRESH_DONE,
    risk.optout_prob_f AS OPTOUT_PROB_7D,
    issues.type_issues_f AS ISSUE_COUNT,
    issues.type_optout_f AS OPTOUT_COUNT,
    issues.type_spam_f AS SPAM_REPORT_COUNT,
    issues.type_sales_f AS EXPOSED_SALES_PHP,
    daily.day_issues_f AS ISSUE_COUNT,
    daily.day_optout_f AS OPTOUT_COUNT,
    daily.day_sales_f AS SALES_PHP
  )
  DIMENSIONS (
    segments.segment_id AS ENTITY_ID WITH SYNONYMS = ('segment', 'audience', 'entity', 'member segment'),
    segments.segment_name AS ENTITY_NAME,
    segments.city AS REGION WITH SYNONYMS = ('city', 'region', 'location')
      COMMENT = 'Philippine city where the segment members shop',
    segments.category AS CATEGORY WITH SYNONYMS = ('category affinity', 'product category'),
    segments.risk_tier AS RISK_TIER COMMENT = 'Segment engagement risk tier 1 (low) to 3 (high)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    issues.issue_type AS ISSUE_TYPE WITH SYNONYMS = ('issue', 'complaint type', 'issue reason'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    segments.segment_count AS COUNT(segments.segment_id) WITH SYNONYMS = ('number of segments', 'number of entities', 'how many segments'),
    segments.clean_offer_rate_pct AS 100 * (SUM(segments.offers_f) - SUM(segments.issues_f)) / NULLIF(SUM(segments.offers_f), 0)
      WITH SYNONYMS = ('clean offer rate', 'perfect offer rate')
      COMMENT = 'Offers without an issue / offers sent',
    segments.issue_optout_pct AS 100 * SUM(segments.optout_f) / NULLIF(SUM(segments.issues_f), 0)
      COMMENT = 'Member opt-outs / offer issues raised',
    segments.issues_raised AS SUM(segments.issues_f) WITH SYNONYMS = ('offer issues', 'complaints'),
    segments.member_optouts AS SUM(segments.optout_f) WITH SYNONYMS = ('opt-outs', 'opted out'),
    segments.spam_reports AS SUM(segments.spam_f) WITH SYNONYMS = ('spam complaints', 'marked as spam'),
    segments.offers_sent AS SUM(segments.offers_f) WITH SYNONYMS = ('offers', 'offer volume'),
    segments.total_sales_php AS SUM(segments.sales_f) WITH SYNONYMS = ('attributed sales', 'offer-attributed sales', 'sales in PHP'),
    segments.offer_refresh_compliance_pct AS 100 * SUM(segments.refresh_done_f) / NULLIF(SUM(segments.refresh_due_f), 0)
      COMMENT = 'Creative refreshes completed / creative refreshes due',
    risk.avg_optout_prob AS AVG(risk.optout_prob_f),
    issues.type_issues AS SUM(issues.type_issues_f),
    issues.type_optouts AS SUM(issues.type_optout_f),
    issues.type_spam AS SUM(issues.type_spam_f),
    issues.type_optout_share_pct AS 100 * SUM(issues.type_optout_f) / NULLIF(SUM(issues.type_issues_f), 0),
    daily.daily_issues AS SUM(daily.day_issues_f),
    daily.daily_optouts AS SUM(daily.day_optout_f),
    daily.daily_sales_php AS SUM(daily.day_sales_f)
  )
  COMMENT = 'Synthetic Philippine retail loyalty personalization analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.PERSONALIZATION_AGENT
  COMMENT = 'Loyalty personalization assistant over a synthetic Philippine omnichannel retailer'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give segment IDs and numbers with units (PHP, %)."
  orchestration: "Use personalization_analyst for offers, attributed sales, offer issues, member opt-outs, spam reports, clean offer rate, creative refresh compliance, segments, cities, categories, issue types and opt-out risk. Use sop_search for offer-issue handling procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: personalization_analyst
      description: "Offers sent, attributed sales in PHP, offer issues, member opt-outs, spam reports, clean offer rate, creative refresh compliance, issue types and member opt-out risk scores by segment, city and category"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic offer-issue handling SOPs by category affinity and issue type"
tool_resources:
  personalization_analyst:
    semantic_view: __DEMO_DB__.APP.PERSONALIZATION_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.ISSUE_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live-offer alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), SEGMENT_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, AMOUNT_PHP FLOAT, SEND_DELAY_MINUTES FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION PH_RETAIL_PERSONALIZATION_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (SEGMENT_ID, EVENT_TS, AMOUNT_PHP, SEND_DELAY_MINUTES, SOP_HINT)
    SELECT p.SEGMENT_ID, p.EVENT_TS, p.AMOUNT_PHP, p.SEND_DELAY_MINUTES,
           'Check ' || r.CATEGORY || ' offer-issue SOPs; current risk band ' || COALESCE(s.RISK_BAND, 'n/a')
    FROM RAW.LIVE_OFFER_EVENTS p
    JOIN RAW.SEGMENTS r ON r.ID = p.SEGMENT_ID
    LEFT JOIN ML.OPTOUT_RISK_SCORES s ON s.ENTITY_ID = p.SEGMENT_ID
    WHERE p.STATUS = 'ISSUE'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.SEGMENT_ID = p.SEGMENT_ID AND l.EVENT_TS = p.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('PH_RETAIL_PERSONALIZATION_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Offer issue alert',
      'New live offer issues logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_OFFER_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_OFFER_EVENTS p
    WHERE p.STATUS = 'ISSUE'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.SEGMENT_ID = p.SEGMENT_ID AND l.EVENT_TS = p.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.ISSUE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.OPTOUT_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.OPTOUT_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.OPTOUT_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'RISK_TIER', RISK_TIER, 'MEMBER_TENURE_YEARS', MEMBER_TENURE_YEARS,
             'IGNORE_RATE_PCT', IGNORE_RATE_PCT, 'CONTACTS_PER_MEMBER_WK', CONTACTS_PER_MEMBER_WK,
             'IGNORE_RATE_7D', IGNORE_RATE_7D, 'OPTOUTS_30D', OPTOUTS_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:OPTOUT::FLOAT, 4) AS OPTOUT_PROB_7D,
         CASE WHEN PRED:probability:OPTOUT::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:OPTOUT::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
