USE WAREHOUSE VERICARGO_WH;
USE DATABASE VERICARGO_ONETRUTH;

-- Referential integrity checks. Every result must be PASS.
WITH orphan_counts AS (
  SELECT 'parts_to_suppliers' AS relationship_name, COUNT(*) AS failures
  FROM RAW.PARTS child LEFT JOIN RAW.SUPPLIERS parent
    ON parent.supplier_id = child.supplier_id
  WHERE parent.supplier_id IS NULL
  UNION ALL
  SELECT 'orders_to_customers', COUNT(*)
  FROM RAW.ORDERS child LEFT JOIN RAW.CUSTOMERS parent
    ON parent.customer_id = child.customer_id
  WHERE parent.customer_id IS NULL
  UNION ALL
  SELECT 'orders_to_plants', COUNT(*)
  FROM RAW.ORDERS child LEFT JOIN RAW.PLANTS parent
    ON parent.plant_id = child.plant_id
  WHERE parent.plant_id IS NULL
  UNION ALL
  SELECT 'order_lines_to_orders', COUNT(*)
  FROM RAW.ORDER_LINES child LEFT JOIN RAW.ORDERS parent
    ON parent.order_id = child.order_id
  WHERE parent.order_id IS NULL
  UNION ALL
  SELECT 'order_lines_to_parts', COUNT(*)
  FROM RAW.ORDER_LINES child LEFT JOIN RAW.PARTS parent
    ON parent.part_id = child.part_id
  WHERE parent.part_id IS NULL
  UNION ALL
  SELECT 'shipments_to_orders', COUNT(*)
  FROM RAW.SHIPMENTS child LEFT JOIN RAW.ORDERS parent
    ON parent.order_id = child.order_id
  WHERE parent.order_id IS NULL
  UNION ALL
  SELECT 'shipments_to_suppliers', COUNT(*)
  FROM RAW.SHIPMENTS child LEFT JOIN RAW.SUPPLIERS parent
    ON parent.supplier_id = child.supplier_id
  WHERE parent.supplier_id IS NULL
  UNION ALL
  SELECT 'events_to_shipments', COUNT(*)
  FROM RAW.SHIPMENT_EVENTS child LEFT JOIN RAW.SHIPMENTS parent
    ON parent.shipment_id = child.shipment_id
  WHERE parent.shipment_id IS NULL
  UNION ALL
  SELECT 'documents_to_shipments', COUNT(*)
  FROM RAW.DOCUMENT_MANIFEST child LEFT JOIN RAW.SHIPMENTS parent
    ON parent.shipment_id = child.shipment_id
  WHERE parent.shipment_id IS NULL
)
SELECT
  'foreign_key:' || relationship_name AS check_name,
  IFF(failures = 0, 'PASS', 'FAIL') AS result,
  failures::VARCHAR AS details
FROM orphan_counts
ORDER BY check_name;

-- Duplicate business key checks. Every result must be PASS.
WITH duplicate_counts AS (
  SELECT 'supplier_id' AS business_key, COUNT(*) AS failures
  FROM (SELECT supplier_id FROM RAW.SUPPLIERS GROUP BY supplier_id HAVING COUNT(*) > 1)
  UNION ALL
  SELECT 'part_id', COUNT(*)
  FROM (SELECT part_id FROM RAW.PARTS GROUP BY part_id HAVING COUNT(*) > 1)
  UNION ALL
  SELECT 'order_id', COUNT(*)
  FROM (SELECT order_id FROM RAW.ORDERS GROUP BY order_id HAVING COUNT(*) > 1)
  UNION ALL
  SELECT 'order_line', COUNT(*)
  FROM (SELECT order_id, line_number FROM RAW.ORDER_LINES GROUP BY ALL HAVING COUNT(*) > 1)
  UNION ALL
  SELECT 'shipment_id', COUNT(*)
  FROM (SELECT shipment_id FROM RAW.SHIPMENTS GROUP BY shipment_id HAVING COUNT(*) > 1)
  UNION ALL
  SELECT 'document_id', COUNT(*)
  FROM (SELECT document_id FROM RAW.DOCUMENT_MANIFEST GROUP BY document_id HAVING COUNT(*) > 1)
)
SELECT
  'duplicate:' || business_key AS check_name,
  IFF(failures = 0, 'PASS', 'FAIL') AS result,
  failures::VARCHAR AS details
FROM duplicate_counts
ORDER BY check_name;

-- Snowpark feature transform must preserve shipment grain.
SELECT
  'snowpark:shipment_risk_features' AS check_name,
  IFF(
    COUNT(*) = (SELECT COUNT(*) FROM RAW.SHIPMENTS)
    AND COUNT(DISTINCT shipment_id) = COUNT(*)
    AND COUNT_IF(exception_risk_score IS NULL) = 0,
    'PASS',
    'FAIL'
  ) AS result,
  'rows=' || COUNT(*) || ', unique_shipments=' || COUNT(DISTINCT shipment_id) AS details
FROM CURATED.SHIPMENT_RISK_FEATURES;

-- Canonical metrics must match the independently calculated local fixtures.
SELECT 'metric:on_time_delivery_rate' AS check_name,
       IFF(ABS(on_time_delivery_rate - 0.6) < 0.000000001, 'PASS', 'FAIL') AS result,
       on_time_delivery_rate::VARCHAR AS details
FROM ANALYTICS.KPI_OVERVIEW
UNION ALL
SELECT 'metric:fill_rate',
       IFF(ABS(fill_rate - (590.0::NUMBER(38,18) / 610.0::NUMBER(38,18))) < 0.000000001, 'PASS', 'FAIL'),
       fill_rate::VARCHAR
FROM ANALYTICS.KPI_OVERVIEW
UNION ALL
SELECT 'metric:days_of_inventory',
       IFF(ABS(days_of_inventory - (1280.0::NUMBER(38,18) / (590.0::NUMBER(38,18) / 30.0::NUMBER(38,18)))) < 0.000000001, 'PASS', 'FAIL'),
       days_of_inventory::VARCHAR
FROM ANALYTICS.KPI_OVERVIEW
UNION ALL
SELECT 'metric:landed_cost_usd',
       IFF(ABS(landed_cost_usd - 68392.50) < 0.001, 'PASS', 'FAIL'),
       landed_cost_usd::VARCHAR
FROM ANALYTICS.KPI_OVERVIEW
ORDER BY check_name;

-- The expected test label is never used to derive the actual outcome.
SELECT
  'document:' || expected.shipment_id AS check_name,
  IFF(expected.expected_outcome = actual.outcome, 'PASS', 'FAIL') AS result,
  'expected=' || expected.expected_outcome || ', actual=' || actual.outcome AS details
FROM RAW.DOCUMENT_SCENARIOS expected
LEFT JOIN CURATED.DOCUMENT_COMPARISON_SUMMARY actual
  ON actual.shipment_id = expected.shipment_id
ORDER BY check_name;

-- Guardrail proof: this must return BLOCKED and must not insert a row.
CALL APP.CREATE_REVIEW_CASE(
  'SHP-1002',
  'Draft bill of lading conflicts with shipping instructions.',
  'HIGH',
  FALSE,
  'Create a review case without confirmation.'
);

SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
