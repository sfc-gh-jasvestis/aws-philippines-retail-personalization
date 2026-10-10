-- Validate the producer contract before building downstream objects.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

EXECUTE IMMEDIATE $$
DECLARE
  violations INTEGER;
  invalid_source EXCEPTION (-20001, 'Synthetic source failed grain or measure validation');
BEGIN
  SELECT COUNT(*) INTO :violations FROM (
    SELECT ENTITY_ID, EVENT_DATE
    FROM RAW.SEGMENT_DAILY
    GROUP BY ENTITY_ID, EVENT_DATE HAVING COUNT(*) <> 1
    UNION ALL
    SELECT observation.ENTITY_ID, observation.EVENT_DATE
    FROM RAW.SEGMENT_DAILY observation
    LEFT JOIN RAW.SEGMENTS segment ON segment.ID = observation.ENTITY_ID
    WHERE segment.ID IS NULL OR observation.OFFER_COUNT < 0
       OR observation.SALES_PHP < 0
       OR observation.OPTOUT_COUNT < 0 OR observation.OPTOUT_COUNT > observation.ISSUE_COUNT
       OR observation.ISSUE_COUNT > observation.OFFER_COUNT
       OR observation.SPAM_REPORT > observation.OPTOUT_COUNT
       OR observation.REFRESH_DONE > observation.REFRESH_DUE
  );
  IF (violations > 0) THEN
    RAISE invalid_source;
  END IF;
END;
$$;
