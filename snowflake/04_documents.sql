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
    WHEN UPPER(VALUE) RLIKE '.*(KRPUS|BUSAN|PUSAN).*' THEN 'KRPUS'
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

CREATE OR REPLACE PROCEDURE CURATED.PROCESS_DOCUMENTS_AI()
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

  RETURN 'AI processed ' || processed_count || ' document(s).';
END;
$$;

CREATE OR REPLACE PROCEDURE CURATED.PROCESS_DOCUMENTS_FIXTURE()
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
  SELECT
    manifest.document_id,
    manifest.shipment_id,
    manifest.document_type,
    manifest.relative_path,
    IFF(
      fixture.processing_status = 'PARSED',
      OBJECT_CONSTRUCT('content', fixture.parse_content),
      OBJECT_CONSTRUCT('errorInformation', fixture.error_details)
    ),
    IFF(
      fixture.processing_status = 'PARSED',
      OBJECT_CONSTRUCT(
        'response',
        OBJECT_CONSTRUCT_KEEP_NULL(
          'consignee', fixture.consignee,
          'port_of_loading', fixture.port_of_loading,
          'port_of_discharge', fixture.port_of_discharge,
          'container_number', fixture.container_number,
          'container_count', fixture.container_count,
          'gross_weight_kg', fixture.gross_weight_kg,
          'marks_and_numbers', fixture.marks_and_numbers
        )
      ),
      OBJECT_CONSTRUCT('errorInformation', fixture.error_details)
    ),
    fixture.min_confidence,
    fixture.processing_status,
    fixture.error_details,
    CURRENT_TIMESTAMP()
  FROM RAW.DOCUMENT_MANIFEST manifest
  JOIN RAW.DOCUMENT_EXTRACTION_FIXTURES fixture
    ON fixture.document_id = manifest.document_id;

  SELECT COUNT(*) INTO :processed_count
  FROM CURATED.DOCUMENT_PROCESSING;

  RETURN 'Fixture processed ' || processed_count || ' document(s).';
END;
$$;

CREATE OR REPLACE PROCEDURE CURATED.PROCESS_DOCUMENTS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  processing_mode VARCHAR;
  processed_count INTEGER;
BEGIN
  SELECT config_value INTO :processing_mode
  FROM RAW.RUNTIME_CONFIG
  WHERE config_key = 'DOCUMENT_PROCESSING_MODE';

  IF (UPPER(COALESCE(processing_mode, 'FIXTURE')) = 'AI') THEN
    CALL CURATED.PROCESS_DOCUMENTS_AI();
  ELSE
    CALL CURATED.PROCESS_DOCUMENTS_FIXTURE();
  END IF;

  SELECT COUNT(*) INTO :processed_count
  FROM CURATED.DOCUMENT_PROCESSING;

  RETURN UPPER(COALESCE(processing_mode, 'FIXTURE'))
    || ' mode processed ' || processed_count || ' document(s).';
END;
$$;

-- Refresh the persisted processing result before any downstream evidence,
-- comparison, exception, search, or risk object is materialized.
CALL CURATED.PROCESS_DOCUMENTS();

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

CREATE TABLE IF NOT EXISTS CURATED.DOCUMENT_FIELD_EVIDENCE (
  DOCUMENT_ID VARCHAR NOT NULL,
  SHIPMENT_ID VARCHAR NOT NULL,
  DOCUMENT_TYPE VARCHAR NOT NULL,
  FIELD_NAME VARCHAR NOT NULL,
  RAW_VALUE VARCHAR,
  NORMALIZED_VALUE VARCHAR,
  CONFIDENCE FLOAT,
  SOURCE_FILE VARCHAR NOT NULL,
  SOURCE_LOCATION VARCHAR,
  PROCESSING_STATUS VARCHAR NOT NULL,
  ERROR_DETAILS VARCHAR,
  RECORDED_AT TIMESTAMP_LTZ NOT NULL
);

TRUNCATE TABLE CURATED.DOCUMENT_FIELD_EVIDENCE;
INSERT INTO CURATED.DOCUMENT_FIELD_EVIDENCE
WITH fields AS (
  SELECT document_id, shipment_id, document_type,
    field_values.key::VARCHAR AS field_name,
    field_values.value::VARCHAR AS raw_value,
    min_confidence, relative_path, processing_status, error_details
  FROM CURATED.DOCUMENT_FIELDS,
  LATERAL FLATTEN(INPUT => OBJECT_CONSTRUCT_KEEP_NULL(
    'CONSIGNEE', consignee,
    'PORT_OF_LOADING', port_of_loading,
    'PORT_OF_DISCHARGE', port_of_discharge,
    'CONTAINER_COUNT', container_count,
    'GROSS_WEIGHT_KG', gross_weight_kg,
    'MARKS_AND_NUMBERS', marks_and_numbers
  )) field_values
)
SELECT document_id, shipment_id, document_type, field_name, raw_value,
  CASE
    WHEN field_name IN ('PORT_OF_LOADING', 'PORT_OF_DISCHARGE') THEN CURATED.NORMALIZE_PORT(raw_value)
    WHEN field_name IN ('CONTAINER_COUNT', 'GROSS_WEIGHT_KG') THEN CURATED.NORMALIZE_NUMBER(raw_value)::VARCHAR
    ELSE CURATED.NORMALIZE_TEXT(raw_value)
  END,
  min_confidence, relative_path, NULL, processing_status, error_details, CURRENT_TIMESTAMP()
FROM fields;

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
      THEN 'UNRESOLVED'
    WHEN normalized_si IS NULL OR normalized_bl IS NULL
      THEN 'MISSING'
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
    COUNT_IF(comparison_status = 'UNRESOLVED') AS unresolved_count,
    COUNT_IF(comparison_status = 'MISSING') AS missing_count
  FROM CURATED.DOCUMENT_FIELD_COMPARISONS
  GROUP BY shipment_id
)
SELECT
  c.shipment_id,
  c.si_count,
  c.bl_count,
  CASE
    WHEN c.si_count = 0 OR c.bl_count = 0 THEN 'MISSING'
    WHEN c.si_count > 1 OR c.bl_count > 1 THEN 'UNRESOLVED'
    WHEN COALESCE(p.failed_count, 0) > 0 THEN 'UNRESOLVED'
    WHEN COALESCE(x.mismatch_count, 0) > 0 THEN 'MISMATCH'
    WHEN COALESCE(x.unresolved_count, 0) > 0 THEN 'UNRESOLVED'
    WHEN COALESCE(x.missing_count, 0) > 0 THEN 'MISSING'
    ELSE 'MATCH'
  END AS outcome,
  CASE
    WHEN c.si_count = 0 OR c.bl_count = 0 THEN 'MISSING_DOCUMENT'
    WHEN c.si_count > 1 OR c.bl_count > 1 THEN 'AMBIGUOUS_PAIR'
    WHEN COALESCE(p.failed_count, 0) > 0 THEN 'PARSE_FAILURE'
    WHEN COALESCE(x.mismatch_count, 0) > 0 THEN 'FIELD_MISMATCH'
    WHEN COALESCE(x.unresolved_count, 0) > 0 THEN 'LOW_CONFIDENCE'
    WHEN COALESCE(x.missing_count, 0) > 0 THEN 'MISSING_FIELD'
    ELSE 'COMPLETE_MATCH'
  END AS outcome_reason,
  COALESCE(x.mismatch_count, 0) AS mismatch_count,
  COALESCE(x.missing_count, 0) AS missing_count,
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
  NULL::VARCHAR AS source_location,
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
  'DOCUMENT_' || outcome_reason AS exception_type,
  'DOCUMENT' AS exception_category,
  IFF(outcome = 'UNRESOLVED', 'HIGH', 'MEDIUM') AS severity,
  'OPEN' AS status,
  outcome_reason AS reason,
  'Document comparison outcome: ' || outcome || ' (' || outcome_reason || ')' AS description,
  'DOCUMENT_COMPARISON_SUMMARY' AS source_type,
  shipment_id AS source_reference,
  TRUE AS evidence_required,
  error_details,
  CURRENT_TIMESTAMP() AS detected_at
FROM CURATED.DOCUMENT_COMPARISON_SUMMARY
WHERE outcome <> 'MATCH'
UNION ALL
SELECT
  'DELIVERY-' || shipment_id,
  shipment_id,
  'DELIVERY_DELAY',
  'OPERATIONAL',
  IFF(status = 'IN_TRANSIT', 'HIGH', 'MEDIUM'),
  'OPEN',
  IFF(status = 'IN_TRANSIT', 'PAST_PROMISE_DATE', 'DELIVERED_LATE'),
  'Shipment missed its governed promised-delivery date.',
  'SHIPMENT_METRICS',
  shipment_id,
  FALSE,
  NULL,
  CURRENT_TIMESTAMP()
FROM CURATED.SHIPMENT_METRICS
WHERE (status = 'DELIVERED' AND actual_delivery_date > promised_delivery_date)
   OR (status <> 'DELIVERED' AND promised_delivery_date < CURRENT_DATE());
