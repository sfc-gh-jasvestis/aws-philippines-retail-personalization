-- Synthetic loyalty audience segment-day observations for a fictional Philippine
-- omnichannel retailer. A segment is an aggregate group of loyalty members in
-- one Philippine city with one category affinity; no member-level records exist.
-- Nothing is seeded as a prediction. Randomness is HASH-seeded, so every rebuild
-- is reproducible: per-segment opt-out propensity, offer fatigue between
-- creative refreshes, missed refreshes, category-weighted offer issue types,
-- issues resolved without an opt-out, and two city-wide SMS gateway outages.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.SEGMENTS AS
WITH segments AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS SEGMENT_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT SEGMENT_INDEX,
         MOD(ABS(HASH(SEGMENT_INDEX, 'phrp-tenure')), 1000000) / 1e6 AS U_TENURE,
         MOD(ABS(HASH(SEGMENT_INDEX, 'phrp-rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(SEGMENT_INDEX, 'phrp-refresh')), 1000000) / 1e6 AS U_REFRESH,
         MOD(ABS(HASH(SEGMENT_INDEX, 'phrp-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(SEGMENT_INDEX, 'phrp-tier')), 1000000) / 1e6 AS U_TIER
  FROM segments
)
SELECT 'SEG-' || LPAD(SEGMENT_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic segment ' || LPAD(SEGMENT_INDEX::VARCHAR, 4, '0') AS NAME,
       -- Deterministic spread (5 and 8 are coprime): every city and category is present.
       CASE MOD(SEGMENT_INDEX, 5) WHEN 0 THEN 'Pasig City' WHEN 1 THEN 'Mandaue City'
            WHEN 2 THEN 'General Santos City' WHEN 3 THEN 'Zamboanga City' ELSE 'Angeles City' END AS REGION,
       CASE MOD(SEGMENT_INDEX, 8) WHEN 0 THEN 'Groceries' WHEN 1 THEN 'Groceries'
            WHEN 2 THEN 'Fashion' WHEN 3 THEN 'Health and beauty' WHEN 4 THEN 'Health and beauty'
            WHEN 5 THEN 'Home and living' WHEN 6 THEN 'Mobile and gadgets' ELSE 'Fashion' END AS CATEGORY,
       SEGMENT_INDEX,
       1 + FLOOR(U_TIER * 3) AS RISK_TIER,
       ROUND(0.3 + U_TENURE * 6.7, 1) AS MEMBER_TENURE_YEARS,
       -- Base daily probability of an opt-out 0.5%-3.2%; ~15% of segments are
       -- chronically over-contacted (x3).
       (0.005 + U_RATE * 0.027) * IFF(U_RATE > 0.85, 3, 1) AS BASE_OPTOUT_RATE,
       7 * (1 + FLOOR(U_REFRESH * 3)) AS REFRESH_INTERVAL_DAYS,
       0.55 + U_DISCIPLINE * 0.45 AS REFRESH_COMPLETION_PROB,
       'Active' AS STATUS
FROM draws;

CREATE TABLE RAW.SEGMENT_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), city_events AS (
  -- Two city-wide SMS gateway outages; every segment in the city raises an offer
  -- issue that is resolved once messages flow again.
  SELECT * FROM VALUES (31, 'Zamboanga City'), (58, 'General Santos City') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT s.ID AS ENTITY_ID, s.SEGMENT_INDEX, s.CATEGORY, s.REGION, s.MEMBER_TENURE_YEARS,
         s.BASE_OPTOUT_RATE, s.REFRESH_INTERVAL_DAYS, s.REFRESH_COMPLETION_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + s.SEGMENT_INDEX * 3, s.REFRESH_INTERVAL_DAYS) AS DAYS_SINCE_REFRESH,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'phrp-optout')), 1000000) / 1e6 AS U_OPTOUT,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'phrp-detect')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'phrp-resolve')), 1000000) / 1e6 AS U_RESOLVE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'phrp-type')), 1000000) / 1e6 AS U_TYPE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'phrp-done')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'phrp-volume')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'phrp-noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'phrp-spam')), 1000000) / 1e6 AS U_SPAM,
         e.REGION IS NOT NULL AS CITY_EVENT
  FROM RAW.SEGMENTS s CROSS JOIN days d
  LEFT JOIN city_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = s.REGION
), refresh AS (
  SELECT *,
         IFF(DAYS_SINCE_REFRESH = 0, 1, 0) AS REFRESH_DUE,
         IFF(DAYS_SINCE_REFRESH = 0 AND U_DONE < REFRESH_COMPLETION_PROB, 1, 0) AS REFRESH_DONE,
         -- Offer fatigue rises between creative refreshes; weak refresh
         -- discipline carries it over.
         DAYS_SINCE_REFRESH / REFRESH_INTERVAL_DAYS + (1 - REFRESH_COMPLETION_PROB) AS FATIGUE
  FROM base
), optouts AS (
  SELECT *,
         CASE WHEN U_OPTOUT < LEAST(0.5, BASE_OPTOUT_RATE * (0.4 + 1.6 * FATIGUE) * (1 + 1 / (1 + MEMBER_TENURE_YEARS))) / 4 THEN 2
              WHEN U_OPTOUT < LEAST(0.5, BASE_OPTOUT_RATE * (0.4 + 1.6 * FATIGUE) * (1 + 1 / (1 + MEMBER_TENURE_YEARS))) THEN 1
              ELSE 0 END AS OPTOUT_RISK_COUNT
  FROM refresh
), issues AS (
  SELECT *,
         -- About 85% of at-risk days raise an offer issue and end in opt-outs;
         -- the rest go quiet without an issue.
         IFF(CITY_EVENT, 0, IFF(U_DETECT < 0.85, OPTOUT_RISK_COUNT, 0)) AS OPTOUT_COUNT,
         -- Issues resolved without an opt-out: higher for high-frequency categories.
         IFF(CITY_EVENT, 1, IFF(U_RESOLVE < CASE CATEGORY WHEN 'Groceries' THEN 0.19
                                                         WHEN 'Health and beauty' THEN 0.13
                                                         WHEN 'Mobile and gadgets' THEN 0.11 ELSE 0.08 END, 1, 0)) AS RESOLVED_COUNT
  FROM optouts
), measured AS (
  SELECT *,
         OPTOUT_COUNT + RESOLVED_COUNT AS ISSUE_COUNT,
         ROUND(CASE CATEGORY WHEN 'Groceries' THEN 900 WHEN 'Health and beauty' THEN 520
                             WHEN 'Mobile and gadgets' THEN 260 WHEN 'Home and living' THEN 340 ELSE 610 END
               * (0.7 + 0.6 * U_VOLUME) * (1 + 0.6 * OPTOUT_RISK_COUNT)) AS OFFER_COUNT,
         CASE CATEGORY WHEN 'Groceries' THEN 1450 WHEN 'Health and beauty' THEN 980
                       WHEN 'Mobile and gadgets' THEN 6200 WHEN 'Home and living' THEN 2300 ELSE 1350 END
           * (0.8 + 0.4 * U_NOISE) AS AVG_BASKET_PHP
  FROM issues
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       OFFER_COUNT,
       ROUND(OFFER_COUNT * 0.08 * AVG_BASKET_PHP, 0) AS SALES_PHP,
       ISSUE_COUNT, OPTOUT_COUNT,
       IFF(OPTOUT_COUNT > 0 AND U_SPAM < 0.55, 1, 0) AS SPAM_REPORT,
       CASE WHEN ISSUE_COUNT = 0 THEN 'None'
            WHEN CITY_EVENT THEN 'SMS gateway outage'
            WHEN CATEGORY = 'Groceries' THEN IFF(U_TYPE < 0.5, 'Expired voucher', IFF(U_TYPE < 0.8, 'Out-of-stock item promoted', 'Wrong store price'))
            WHEN CATEGORY = 'Fashion' THEN IFF(U_TYPE < 0.5, 'Irrelevant recommendation', IFF(U_TYPE < 0.8, 'Duplicate message', 'Expired voucher'))
            WHEN CATEGORY = 'Health and beauty' THEN IFF(U_TYPE < 0.45, 'Irrelevant recommendation', IFF(U_TYPE < 0.8, 'Message sent late at night', 'Duplicate message'))
            WHEN CATEGORY = 'Home and living' THEN IFF(U_TYPE < 0.55, 'Wrong store price', 'Out-of-stock item promoted')
            ELSE IFF(U_TYPE < 0.5, 'Duplicate message', IFF(U_TYPE < 0.75, 'Irrelevant recommendation', 'Expired voucher')) END AS ISSUE_TYPE,
       REFRESH_DUE, REFRESH_DONE,
       ROUND(38 + 9.0 * FATIGUE + 11.0 * OPTOUT_RISK_COUNT + U_NOISE * 5, 2) AS IGNORE_RATE_PCT,
       ROUND(1.8 + 1.4 * FATIGUE + 1.6 * OPTOUT_RISK_COUNT + U_NOISE * 0.5, 2) AS CONTACTS_PER_MEMBER_WK,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM measured;

-- Marketing consent record coverage per segment (aggregate counts, snapshot).
CREATE TABLE RAW.CONSENT_RECORDS AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Groceries' THEN 'SMS marketing consent batch'
                     WHEN 'Fashion' THEN 'Email marketing consent batch'
                     WHEN 'Health and beauty' THEN 'Push notification consent batch'
                     WHEN 'Home and living' THEN 'Viber message consent batch'
                     ELSE 'Personalised offer consent batch' END AS DOC_TYPE,
       1 + MOD(ABS(HASH(ID, 'phrp-req')), 4) AS REQUIRED_QTY,
       MOD(ABS(HASH(ID, 'phrp-file')), 5) AS ON_FILE_QTY,
       IFF(MOD(ABS(HASH(ID, 'phrp-file')), 5) < 1 + MOD(ABS(HASH(ID, 'phrp-req')), 4),
           MOD(ABS(HASH(ID, 'phrp-pending')), 3), 0) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.SEGMENTS;
