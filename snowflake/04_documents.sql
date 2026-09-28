USE WAREHOUSE VERICARGO_WH;
USE DATABASE VERICARGO_ONETRUTH;

CREATE TABLE IF NOT EXISTS CURATED.DOCUMENT_PROCESSING (
  DOCUMENT_ID VARCHAR NOT NULL,
  SHIPMENT_ID VARCHAR NOT NULL,
  DOCUMENT_TYPE VARCHAR NOT NULL,
  RELATIVE_PATH VARCHAR NOT NULL,
  PARSE_RESULT VARIANT,
  EXTRACTION_RESULT VARIANT,
  MIN_CONFIDENCE FLOAT,
  PROCESSING_STATUS VARCHAR NOT NULL,
  ERROR_DETAILS VARCHAR,
  PROCESSED_AT TIMESTAMP_LTZ NOT NULL
);

CREATE OR REPLACE FUNCTION CURATED.NORMALIZE_TEXT(VALUE VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
IMMUTABLE
AS
$$
  NULLIF(TRIM(REGEXP_REPLACE(UPPER(VALUE), '\\s+', ' ')), '')
$$;

CREATE OR REPLACE FUNCTION CURATED.NORMALIZE_CONTAINER(VALUE VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
IMMUTABLE
AS
$$
  NULLIF(REGEXP_REPLACE(UPPER(VALUE), '[^A-Z0-9]', ''), '')
$$;

CREATE OR REPLACE FUNCTION CURATED.NORMALIZE_PORT(VALUE VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
IMMUTABLE
AS
$$
  CASE
    WHEN VALUE IS NULL THEN NULL
    WHEN UPPER(VALUE) RLIKE '.*(MYPEN|PENANG).*' THEN 'MYPEN'
    WHEN UPPER(VALUE) RLIKE '.*(MYPKG|PORT KLANG|KLANG).*' THEN 'MYPKG'
    WHEN UPPER(VALUE) RLIKE '.*(SGSIN|SINGAPORE).*' THEN 'SGSIN'
    WHEN UPPER(VALUE) RLIKE '.*(THLCH|LAEM CHABANG).*' THEN 'THLCH'
    WHEN UPPER(VALUE) RLIKE '.*(VNSGN|CAT LAI|HO CHI MINH).*' THEN 'VNSGN'
    ELSE CURATED.NORMALIZE_TEXT(VALUE)
  END
$$;

CREATE OR REPLACE FUNCTION CURATED.NORMALIZE_NUMBER(VALUE VARCHAR)
RETURNS NUMBER(18, 3)
LANGUAGE SQL
IMMUTABLE
AS
$$
  TRY_TO_DECIMAL(
    REGEXP_SUBSTR(REPLACE(VALUE, ',', ''), '[0-9]+(\\.[0-9]+)?'),
    18,
    3
  )
$$;

CREATE OR REPLACE PROCEDURE CURATED.PROCESS_DOCUMENTS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  processed_count INTEGER;
BEGIN
  TRUNCATE TABLE CURATED.DOCUMENT_PROCESSING;

  INSERT INTO CURATED.DOCUMENT_PROCESSING (
    document_id,
    shipment_id,
    document_type,
    relative_path,
    parse_result,
    extraction_result,
    min_confidence,
    processing_status,
    error_details,
    processed_at
  )
  WITH inference AS (
    SELECT
      m.document_id,
      m.shipment_id,
      m.document_type,
      m.relative_path,
      AI_PARSE_DOCUMENT(
        TO_FILE('@VERICARGO_ONETRUTH.RAW.DOCUMENT_STAGE', m.relative_path),
        OBJECT_CONSTRUCT('mode', 'LAYOUT')
      ) AS parse_result,
      AI_EXTRACT(
        file => TO_FILE('@VERICARGO_ONETRUTH.RAW.DOCUMENT_STAGE', m.relative_path),
        responseFormat => OBJECT_CONSTRUCT(
          'consignee', 'Extract the consignee name.',
          'port_of_loading', 'Extract the port of loading or origin port.',
          'port_of_discharge', 'Extract the port of discharge or destination port.',
          'container_number', 'Extract the container number.',
          'container_count', 'Extract the number of containers as a number.',
          'gross_weight_kg', 'Extract gross weight in kilograms as a number.',
          'marks_and_numbers', 'Extract marks and numbers.'
        ),
        scores => TRUE
      ) AS extraction_result
    FROM RAW.DOCUMENT_MANIFEST m
  ),
  scored AS (
    SELECT
      inference.*,
      LEAST_IGNORE_NULLS(
        extraction_result:scoring:scores:consignee:score::FLOAT,
        extraction_result:scoring:scores:port_of_loading:score::FLOAT,
        extraction_result:scoring:scores:port_of_discharge:score::FLOAT,
        extraction_result:scoring:scores:container_number:score::FLOAT,
        extraction_result:scoring:scores:container_count:score::FLOAT,
        extraction_result:scoring:scores:gross_weight_kg:score::FLOAT,
        extraction_result:scoring:scores:marks_and_numbers:score::FLOAT
      ) AS min_confidence
    FROM inference
  )
  SELECT
    document_id,
    shipment_id,
    document_type,
    relative_path,
    parse_result,
    extraction_result,
    min_confidence,
    CASE
      WHEN COALESCE(parse_result:content::STRING, '') = ''
        OR COALESCE(NOT IS_NULL_VALUE(parse_result:errorInformation), FALSE)
        OR COALESCE(NOT IS_NULL_VALUE(parse_result:error), FALSE)
        OR COALESCE(NOT IS_NULL_VALUE(extraction_result:errorInformation), FALSE)
        OR COALESCE(NOT IS_NULL_VALUE(extraction_result:error), FALSE)
        THEN 'FAILED'
      WHEN min_confidence IS NULL OR min_confidence < 0.20
        THEN 'LOW_CONFIDENCE'
      ELSE 'PARSED'
    END AS processing_status,
    COALESCE(
      IFF(COALESCE(NOT IS_NULL_VALUE(parse_result:errorInformation), FALSE),
          parse_result:errorInformation::STRING, NULL),
      IFF(COALESCE(NOT IS_NULL_VALUE(parse_result:error), FALSE),
          parse_result:error::STRING, NULL),
      IFF(COALESCE(NOT IS_NULL_VALUE(extraction_result:errorInformation), FALSE),
          extraction_result:errorInformation::STRING, NULL),
      IFF(COALESCE(NOT IS_NULL_VALUE(extraction_result:error), FALSE),
          extraction_result:error::STRING, NULL),
      IFF(min_confidence IS NULL OR min_confidence < 0.20,
          'Extraction confidence is missing or below 0.20.', NULL)
    ) AS error_details,
    CURRENT_TIMESTAMP()
  FROM scored;

  SELECT COUNT(*) INTO :processed_count
  FROM CURATED.DOCUMENT_PROCESSING;

  RETURN 'Processed ' || processed_count || ' document(s).';
END;
$$;

CREATE OR REPLACE VIEW CURATED.DOCUMENT_CARDINALITY AS
SELECT
  s.shipment_id,
  COUNT_IF(m.document_type = 'SI') AS si_count,
  COUNT_IF(m.document_type = 'DRAFT_BL') AS bl_count
FROM RAW.SHIPMENTS s
LEFT JOIN RAW.DOCUMENT_MANIFEST m ON m.shipment_id = s.shipment_id
GROUP BY s.shipment_id;

CREATE OR REPLACE VIEW CURATED.DOCUMENT_FIELDS AS
SELECT
  document_id,
  shipment_id,
  document_type,
  relative_path,
  processing_status,
  min_confidence,
  error_details,
  GET(COALESCE(extraction_result:response, extraction_result), 'consignee')::STRING
    AS consignee,
  GET(COALESCE(extraction_result:response, extraction_result), 'port_of_loading')::STRING
    AS port_of_loading,
  GET(COALESCE(extraction_result:response, extraction_result), 'port_of_discharge')::STRING
    AS port_of_discharge,
  GET(COALESCE(extraction_result:response, extraction_result), 'container_number')::STRING
    AS container_number,
  GET(COALESCE(extraction_result:response, extraction_result), 'container_count')::STRING
    AS container_count,
  GET(COALESCE(extraction_result:response, extraction_result), 'gross_weight_kg')::STRING
    AS gross_weight_kg,
  GET(COALESCE(extraction_result:response, extraction_result), 'marks_and_numbers')::STRING
    AS marks_and_numbers
FROM CURATED.DOCUMENT_PROCESSING;

CREATE OR REPLACE VIEW CURATED.DOCUMENT_FIELD_COMPARISONS AS
WITH eligible AS (
  SELECT c.shipment_id
  FROM CURATED.DOCUMENT_CARDINALITY c
  WHERE c.si_count = 1 AND c.bl_count = 1
),
pairs AS (
  SELECT
    e.shipment_id,
    si.processing_status AS si_processing_status,
    bl.processing_status AS bl_processing_status,
    si.relative_path AS si_source,
    bl.relative_path AS bl_source,
    si.consignee AS si_consignee,
    bl.consignee AS bl_consignee,
    si.port_of_loading AS si_port_of_loading,
    bl.port_of_loading AS bl_port_of_loading,
    si.port_of_discharge AS si_port_of_discharge,
    bl.port_of_discharge AS bl_port_of_discharge,
    si.container_count AS si_container_count,
    bl.container_count AS bl_container_count,
    si.gross_weight_kg AS si_gross_weight_kg,
    bl.gross_weight_kg AS bl_gross_weight_kg,
    si.marks_and_numbers AS si_marks_and_numbers,
    bl.marks_and_numbers AS bl_marks_and_numbers
  FROM eligible e
  JOIN CURATED.DOCUMENT_FIELDS si
    ON si.shipment_id = e.shipment_id AND si.document_type = 'SI'
  JOIN CURATED.DOCUMENT_FIELDS bl
    ON bl.shipment_id = e.shipment_id AND bl.document_type = 'DRAFT_BL'
),
unpivoted AS (
  SELECT shipment_id, 'CONSIGNEE' AS field_name,
         si_consignee AS si_value, bl_consignee AS bl_value,
         CURATED.NORMALIZE_TEXT(si_consignee) AS normalized_si,
         CURATED.NORMALIZE_TEXT(bl_consignee) AS normalized_bl,
         si_processing_status, bl_processing_status, si_source, bl_source
  FROM pairs
  UNION ALL
  SELECT shipment_id, 'PORT_OF_LOADING', si_port_of_loading, bl_port_of_loading,
         CURATED.NORMALIZE_PORT(si_port_of_loading),
         CURATED.NORMALIZE_PORT(bl_port_of_loading),
         si_processing_status, bl_processing_status, si_source, bl_source
  FROM pairs
  UNION ALL
  SELECT shipment_id, 'PORT_OF_DISCHARGE', si_port_of_discharge, bl_port_of_discharge,
         CURATED.NORMALIZE_PORT(si_port_of_discharge),
         CURATED.NORMALIZE_PORT(bl_port_of_discharge),
         si_processing_status, bl_processing_status, si_source, bl_source
  FROM pairs
  UNION ALL
  SELECT shipment_id, 'CONTAINER_COUNT', si_container_count, bl_container_count,
         CURATED.NORMALIZE_NUMBER(si_container_count)::VARCHAR,
         CURATED.NORMALIZE_NUMBER(bl_container_count)::VARCHAR,
         si_processing_status, bl_processing_status, si_source, bl_source
  FROM pairs
  UNION ALL
  SELECT shipment_id, 'GROSS_WEIGHT_KG', si_gross_weight_kg, bl_gross_weight_kg,
         CURATED.NORMALIZE_NUMBER(si_gross_weight_kg)::VARCHAR,
         CURATED.NORMALIZE_NUMBER(bl_gross_weight_kg)::VARCHAR,
         si_processing_status, bl_processing_status, si_source, bl_source
  FROM pairs
  UNION ALL
  SELECT shipment_id, 'MARKS_AND_NUMBERS', si_marks_and_numbers, bl_marks_and_numbers,
         CURATED.NORMALIZE_TEXT(si_marks_and_numbers),
         CURATED.NORMALIZE_TEXT(bl_marks_and_numbers),
         si_processing_status, bl_processing_status, si_source, bl_source
  FROM pairs
)
SELECT
  shipment_id,
  field_name,
  si_value,
  bl_value,
  normalized_si,
  normalized_bl,
  CASE
    WHEN si_processing_status <> 'PARSED' OR bl_processing_status <> 'PARSED'
      THEN 'NEEDS_REVIEW'
    WHEN normalized_si IS NULL OR normalized_bl IS NULL
      THEN 'NEEDS_REVIEW'
    WHEN field_name = 'GROSS_WEIGHT_KG'
      AND ABS(normalized_si::NUMBER(18, 3) - normalized_bl::NUMBER(18, 3))
        <= GREATEST(0.5, normalized_si::NUMBER(18, 3) * 0.001)
      THEN 'MATCH'
    WHEN normalized_si = normalized_bl THEN 'MATCH'
    ELSE 'MISMATCH'
  END AS comparison_status,
  si_source,
  bl_source
FROM unpivoted;

CREATE OR REPLACE VIEW CURATED.DOCUMENT_COMPARISON_SUMMARY AS
WITH processing AS (
  SELECT
    shipment_id,
    COUNT_IF(processing_status <> 'PARSED') AS failed_count,
    MIN(min_confidence) AS min_confidence,
    LISTAGG(DISTINCT error_details, '; ') AS error_details
  FROM CURATED.DOCUMENT_PROCESSING
  GROUP BY shipment_id
),
comparisons AS (
  SELECT
    shipment_id,
    COUNT_IF(comparison_status = 'MISMATCH') AS mismatch_count,
    COUNT_IF(comparison_status = 'NEEDS_REVIEW') AS unresolved_count
  FROM CURATED.DOCUMENT_FIELD_COMPARISONS
  GROUP BY shipment_id
)
SELECT
  c.shipment_id,
  c.si_count,
  c.bl_count,
  CASE
    WHEN c.si_count = 0 OR c.bl_count = 0 THEN 'MISSING_DOCUMENT'
    WHEN c.si_count > 1 OR c.bl_count > 1 THEN 'AMBIGUOUS'
    WHEN COALESCE(p.failed_count, 0) > 0 THEN 'UNREADABLE'
    WHEN COALESCE(x.mismatch_count, 0) > 0 THEN 'MISMATCH'
    WHEN COALESCE(x.unresolved_count, 0) > 0 THEN 'NEEDS_REVIEW'
    ELSE 'MATCH'
  END AS outcome,
  COALESCE(x.mismatch_count, 0) AS mismatch_count,
  COALESCE(x.unresolved_count, 0) AS unresolved_count,
  p.min_confidence,
  p.error_details
FROM CURATED.DOCUMENT_CARDINALITY c
LEFT JOIN processing p ON p.shipment_id = c.shipment_id
LEFT JOIN comparisons x ON x.shipment_id = c.shipment_id;

CREATE OR REPLACE VIEW CURATED.DOCUMENT_SEARCH_CORPUS AS
SELECT
  document_id,
  shipment_id,
  document_type,
  relative_path,
  processing_status,
  min_confidence,
  CONCAT(
    'Shipment: ', shipment_id, '\n',
    'Document type: ', document_type, '\n',
    'Source file: ', relative_path, '\n',
    'Minimum extraction confidence: ', COALESCE(min_confidence::STRING, 'unavailable'), '\n',
    'Extracted fields: ', COALESCE(TO_JSON(extraction_result), '{}'), '\n',
    'Parsed text: ', COALESCE(parse_result:content::STRING, '')
  ) AS content
FROM CURATED.DOCUMENT_PROCESSING
WHERE processing_status = 'PARSED';

CREATE OR REPLACE VIEW ANALYTICS.SHIPMENT_EXCEPTIONS AS
SELECT
  'DOC-' || shipment_id AS exception_id,
  shipment_id,
  'DOCUMENT' AS exception_type,
  IFF(outcome IN ('UNREADABLE', 'AMBIGUOUS'), 'HIGH', 'MEDIUM') AS severity,
  outcome AS reason,
  error_details,
  CURRENT_TIMESTAMP() AS detected_at
FROM CURATED.DOCUMENT_COMPARISON_SUMMARY
WHERE outcome <> 'MATCH'
UNION ALL
SELECT
  'DELIVERY-' || shipment_id,
  shipment_id,
  'DELIVERY',
  IFF(status = 'IN_TRANSIT', 'HIGH', 'MEDIUM'),
  IFF(status = 'IN_TRANSIT', 'PAST_PROMISE_DATE', 'DELIVERED_LATE'),
  NULL,
  CURRENT_TIMESTAMP()
FROM CURATED.SHIPMENT_METRICS
WHERE (status = 'DELIVERED' AND actual_delivery_date > promised_delivery_date)
   OR (status <> 'DELIVERED' AND promised_delivery_date < CURRENT_DATE());

CALL CURATED.PROCESS_DOCUMENTS();
