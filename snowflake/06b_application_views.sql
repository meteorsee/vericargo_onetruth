USE WAREHOUSE VERICARGO_WH;
USE DATABASE VERICARGO_ONETRUTH;

-- Stable contracts for the Streamlit application. The UI never joins raw tables.
CREATE OR REPLACE VIEW APP.VW_SHIPMENT_360 AS
WITH line_summary AS (
  SELECT order_id,
    LISTAGG(DISTINCT part_id, ', ') WITHIN GROUP (ORDER BY part_id) AS part_ids,
    SUM(ordered_qty) AS ordered_quantity,
    SUM(shipped_qty) AS shipped_quantity
  FROM CURATED.ORDER_LINE_METRICS
  GROUP BY order_id
), exception_summary AS (
  SELECT shipment_id,
    COUNT(*) AS open_exception_count,
    COUNT_IF(severity IN ('HIGH', 'CRITICAL')) AS high_exception_count,
    LISTAGG(exception_id, ', ') WITHIN GROUP (ORDER BY exception_id) AS exception_ids
  FROM ANALYTICS.SHIPMENT_EXCEPTIONS
  WHERE status = 'OPEN'
  GROUP BY shipment_id
)
SELECT
  sm.shipment_id, sm.order_id, sm.supplier_id, supplier.supplier_name,
  supplier.risk_tier AS supplier_risk_tier,
  sm.customer_id, customer.customer_name, sm.plant_id, plant.plant_name,
  lines.part_ids, lines.ordered_quantity, lines.shipped_quantity,
  sm.container_id, sm.origin_port_code, origin.port_name AS origin_port_name,
  sm.destination_port_code, destination.port_name AS destination_port_name,
  sm.ship_date, sm.promised_delivery_date, sm.actual_delivery_date, sm.status,
  sm.delivered_flag, sm.on_time_delivered_flag,
  sm.product_cost_usd, sm.freight_usd, sm.duty_usd, sm.insurance_usd,
  sm.handling_usd, sm.landed_cost_usd,
  risk.delivery_days_late, risk.days_of_inventory,
  risk.delivery_risk_score, risk.document_risk_score,
  risk.inventory_risk_score, risk.cost_risk_score,
  risk.data_quality_risk_score, risk.overall_risk_score, risk.risk_severity,
  risk.risk_contributors, risk.feature_refreshed_at,
  docs.outcome AS document_outcome, docs.outcome_reason AS document_outcome_reason,
  docs.min_confidence AS document_min_confidence,
  COALESCE(ex.open_exception_count, 0) AS open_exception_count,
  COALESCE(ex.high_exception_count, 0) AS high_exception_count,
  ex.exception_ids
FROM CURATED.SHIPMENT_METRICS sm
JOIN RAW.SUPPLIERS supplier ON supplier.supplier_id = sm.supplier_id
JOIN RAW.CUSTOMERS customer ON customer.customer_id = sm.customer_id
JOIN RAW.PLANTS plant ON plant.plant_id = sm.plant_id
JOIN RAW.PORTS origin ON origin.port_code = sm.origin_port_code
JOIN RAW.PORTS destination ON destination.port_code = sm.destination_port_code
LEFT JOIN line_summary lines ON lines.order_id = sm.order_id
LEFT JOIN CURATED.SHIPMENT_RISK_FEATURES risk ON risk.shipment_id = sm.shipment_id
LEFT JOIN CURATED.DOCUMENT_COMPARISON_SUMMARY docs ON docs.shipment_id = sm.shipment_id
LEFT JOIN exception_summary ex ON ex.shipment_id = sm.shipment_id;

CREATE OR REPLACE VIEW APP.VW_CONTROL_TOWER AS
SELECT
  shipment.*,
  kpi.on_time_delivery_rate, kpi.fill_rate,
  kpi.days_of_inventory AS portfolio_days_of_inventory,
  kpi.landed_cost_usd AS portfolio_landed_cost_usd, kpi.measured_at,
  COUNT(*) OVER () AS shipment_count,
  COUNT_IF(shipment.delivery_days_late > 0) OVER () AS delayed_shipment_count,
  SUM(shipment.open_exception_count) OVER () AS exception_count,
  DENSE_RANK() OVER (
    ORDER BY shipment.overall_risk_score DESC NULLS LAST, shipment.shipment_id
  ) AS attention_rank,
  CASE
    WHEN shipment.open_exception_count = 0 THEN 'No open exception'
    ELSE COALESCE(shipment.risk_contributors, 'Open exception requires attention')
  END AS attention_reason
FROM APP.VW_SHIPMENT_360 shipment
CROSS JOIN ANALYTICS.KPI_OVERVIEW kpi;

CREATE OR REPLACE VIEW APP.VW_SHIPMENT_TIMELINE AS
SELECT event_id, shipment_id, event_ts, event_type, location_code, temperature_c,
  ROW_NUMBER() OVER (PARTITION BY shipment_id ORDER BY event_ts, event_id) AS event_sequence
FROM RAW.SHIPMENT_EVENTS;

CREATE OR REPLACE VIEW APP.VW_DOCUMENT_COMPARISON AS
SELECT
  comparison.shipment_id, comparison.field_name,
  comparison.comparison_status,
  comparison.si_value, comparison.normalized_si,
  si.confidence AS si_confidence, comparison.si_source,
  si.source_location AS si_source_location, si.processing_status AS si_processing_status,
  comparison.bl_value, comparison.normalized_bl,
  bl.confidence AS bl_confidence, comparison.bl_source,
  bl.source_location AS bl_source_location, bl.processing_status AS bl_processing_status,
  COALESCE(si.error_details, bl.error_details) AS error_details,
  CASE comparison.comparison_status
    WHEN 'MISMATCH' THEN 1 WHEN 'UNRESOLVED' THEN 2 WHEN 'MISSING' THEN 3
    WHEN 'MATCH' THEN 4 ELSE 5 END AS display_order
FROM CURATED.DOCUMENT_FIELD_COMPARISONS comparison
LEFT JOIN CURATED.DOCUMENT_FIELD_EVIDENCE si
  ON si.shipment_id = comparison.shipment_id
 AND si.document_type = 'SI' AND si.field_name = comparison.field_name
LEFT JOIN CURATED.DOCUMENT_FIELD_EVIDENCE bl
  ON bl.shipment_id = comparison.shipment_id
 AND bl.document_type = 'DRAFT_BL' AND bl.field_name = comparison.field_name;

CREATE OR REPLACE VIEW APP.VW_EXCEPTION_DETAIL AS
SELECT exception_id, shipment_id, exception_type, exception_category,
  severity, status, reason, description, source_type, source_reference,
  evidence_required, error_details, detected_at
FROM ANALYTICS.SHIPMENT_EXCEPTIONS;

CREATE OR REPLACE VIEW APP.VW_REVIEW_QUEUE AS
SELECT
  review.case_id, review.shipment_id, review.reason, review.severity, review.status,
  review.assigned_to, review.source_question, review.created_by, review.created_at,
  review.updated_by, review.updated_at, review.resolution_note,
  review.resolved_by, review.resolved_at, review.confirmation_recorded,
  LISTAGG(link.exception_id, ', ') WITHIN GROUP (ORDER BY link.exception_id) AS exception_ids,
  COUNT(link.exception_id) AS linked_exception_count
FROM APP.REVIEW_CASES review
LEFT JOIN APP.REVIEW_CASE_EXCEPTIONS link ON link.case_id = review.case_id
GROUP BY ALL;

CREATE OR REPLACE VIEW APP.VW_AUDIT_HISTORY AS
SELECT audit_event_id, case_id, event_type, from_status, to_status,
  event_note, actor, event_at
FROM APP.REVIEW_AUDIT_EVENTS;

CREATE OR REPLACE VIEW APP.VW_DOCUMENT_INTAKE AS
SELECT
  intake_id, shipment_id, declared_document_type, original_filename, safe_filename,
  content_type, size_bytes, sha256, stage_path, stage_status, client_validation,
  verification_status, matched_document_id, matched_shipment_id,
  matched_document_type, processing_mode, status_note, error_details,
  viewer_identity, created_by, created_at
FROM APP.DOCUMENT_INTAKE_EVENTS;

CREATE OR REPLACE VIEW APP.VW_GOVERNANCE_STATUS AS
SELECT 'DATA_FRESHNESS' AS check_name,
  IFF(DATEDIFF('hour', MAX(feature_refreshed_at), CURRENT_TIMESTAMP()) <= 24,
      'HEALTHY', 'STALE') AS status,
  MAX(feature_refreshed_at)::VARCHAR AS check_value,
  'Latest deterministic risk-feature refresh' AS details,
  CURRENT_TIMESTAMP() AS checked_at
FROM CURATED.SHIPMENT_RISK_FEATURES
UNION ALL
SELECT 'DOCUMENT_HEALTH',
  IFF(COUNT_IF(processing_status = 'FAILED') = 0, 'HEALTHY', 'ATTENTION'),
  COUNT_IF(processing_status = 'PARSED') || '/' || COUNT(*) || ' parsed',
  'Failed and low-confidence documents remain unresolved', CURRENT_TIMESTAMP()
FROM CURATED.DOCUMENT_PROCESSING
UNION ALL
SELECT config_key, 'GOVERNED', config_value,
  config_note, CURRENT_TIMESTAMP()
FROM RAW.RUNTIME_CONFIG
WHERE config_key IN ('DOCUMENT_PROCESSING_MODE', 'EVIDENCE_RETRIEVAL_MODE')
UNION ALL
SELECT 'EVIDENCE_CORPUS', IFF(COUNT(*) > 0, 'HEALTHY', 'ATTENTION'),
  COUNT(*) || ' governed evidence row(s)',
  'Structured evidence is available to Cortex Analyst through the semantic view', CURRENT_TIMESTAMP()
FROM CURATED.DOCUMENT_SEARCH_CORPUS
UNION ALL
SELECT 'DOCUMENT_INTAKE',
  IFF(COUNT_IF(verification_status = 'REJECTED') = 0, 'HEALTHY', 'ATTENTION'),
  COUNT(*) || ' upload attempt(s)',
  'Uploads are checksum-verified and quarantined; they never replace governed evidence automatically',
  CURRENT_TIMESTAMP()
FROM APP.DOCUMENT_INTAKE_EVENTS
UNION ALL
SELECT 'REVIEW_GUARDRAIL', 'ENFORCED',
  COUNT_IF(confirmation_recorded) || ' confirmed case(s)',
  'Mutation requires explicit UI confirmation and emits audit events', CURRENT_TIMESTAMP()
FROM APP.REVIEW_CASES
UNION ALL
SELECT 'KPI:ON_TIME_DELIVERY_RATE', 'GOVERNED',
  'Delivered on/before promise / delivered shipments',
  'Shipment grain; canonical semantic metric', CURRENT_TIMESTAMP()
UNION ALL
SELECT 'KPI:FILL_RATE', 'GOVERNED',
  'Sum(min(shipped, ordered)) / sum(ordered)',
  'Order-line grain; canonical semantic metric', CURRENT_TIMESTAMP()
UNION ALL
SELECT 'KPI:DAYS_OF_INVENTORY', 'GOVERNED',
  'On-hand / trailing-30-day average daily shipped',
  'Plant-part grain; null for zero demand', CURRENT_TIMESTAMP()
UNION ALL
SELECT 'KPI:LANDED_COST', 'GOVERNED',
  'Product + freight + duty + insurance + handling',
  'Shipment grain; USD only', CURRENT_TIMESTAMP();
