USE WAREHOUSE VERICARGO_WH;
USE DATABASE VERICARGO_ONETRUTH;

CREATE TABLE IF NOT EXISTS APP.EXCEPTION_DIGEST_RUNS (
  RUN_AT TIMESTAMP_LTZ NOT NULL,
  OPEN_EXCEPTION_COUNT NUMBER NOT NULL,
  HIGH_SEVERITY_COUNT NUMBER NOT NULL,
  PENDING_REVIEW_COUNT NUMBER NOT NULL,
  DIGEST_TEXT VARCHAR NOT NULL
);

CREATE OR REPLACE TASK APP.DAILY_EXCEPTION_DIGEST
  WAREHOUSE = VERICARGO_WH
  SCHEDULE = 'USING CRON 0 1 * * * UTC'
AS
INSERT INTO APP.EXCEPTION_DIGEST_RUNS (
  run_at,
  open_exception_count,
  high_severity_count,
  pending_review_count,
  digest_text
)
WITH exception_counts AS (
  SELECT
    COUNT(*) AS open_exception_count,
    COUNT_IF(severity IN ('HIGH', 'CRITICAL')) AS high_severity_count
  FROM ANALYTICS.SHIPMENT_EXCEPTIONS
),
review_counts AS (
  SELECT COUNT_IF(status = 'PENDING') AS pending_review_count
  FROM APP.REVIEW_CASES
)
SELECT
  CURRENT_TIMESTAMP(),
  e.open_exception_count,
  e.high_severity_count,
  r.pending_review_count,
  CONCAT(
    'VeriCargo OneTruth daily digest: ', e.open_exception_count,
    ' open exception(s), ', e.high_severity_count,
    ' high/critical, ', r.pending_review_count,
    ' pending human-review case(s).'
  )
FROM exception_counts e
CROSS JOIN review_counts r;

ALTER TASK APP.DAILY_EXCEPTION_DIGEST RESUME;
