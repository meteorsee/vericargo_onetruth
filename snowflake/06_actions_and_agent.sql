USE WAREHOUSE VERICARGO_WH;
USE DATABASE VERICARGO_ONETRUTH;

CREATE SEQUENCE IF NOT EXISTS APP.REVIEW_CASE_SEQUENCE START = 1 INCREMENT = 1;

CREATE TABLE IF NOT EXISTS APP.REVIEW_CASES (
  CASE_ID VARCHAR NOT NULL,
  SHIPMENT_ID VARCHAR NOT NULL,
  REASON VARCHAR NOT NULL,
  SEVERITY VARCHAR NOT NULL,
  STATUS VARCHAR NOT NULL DEFAULT 'PENDING',
  SOURCE_QUESTION VARCHAR NOT NULL,
  CREATED_BY VARCHAR NOT NULL,
  CREATED_AT TIMESTAMP_LTZ NOT NULL,
  CONFIRMATION_RECORDED BOOLEAN NOT NULL,
  CONSTRAINT REVIEW_CASES_PK PRIMARY KEY (CASE_ID)
);

-- Remove the legacy creation interface because it bypassed exception links and audit.
DROP PROCEDURE IF EXISTS APP.CREATE_REVIEW_CASE(VARCHAR, VARCHAR, VARCHAR, BOOLEAN, VARCHAR);

ALTER TABLE APP.REVIEW_CASES ADD COLUMN IF NOT EXISTS ASSIGNED_TO VARCHAR;
ALTER TABLE APP.REVIEW_CASES ADD COLUMN IF NOT EXISTS RESOLUTION_NOTE VARCHAR;
ALTER TABLE APP.REVIEW_CASES ADD COLUMN IF NOT EXISTS RESOLVED_AT TIMESTAMP_LTZ;
ALTER TABLE APP.REVIEW_CASES ADD COLUMN IF NOT EXISTS RESOLVED_BY VARCHAR;
ALTER TABLE APP.REVIEW_CASES ADD COLUMN IF NOT EXISTS UPDATED_AT TIMESTAMP_LTZ;
ALTER TABLE APP.REVIEW_CASES ADD COLUMN IF NOT EXISTS UPDATED_BY VARCHAR;

CREATE TABLE IF NOT EXISTS APP.REVIEW_CASE_EXCEPTIONS (
  CASE_ID VARCHAR NOT NULL,
  EXCEPTION_ID VARCHAR NOT NULL,
  LINKED_AT TIMESTAMP_LTZ NOT NULL,
  LINKED_BY VARCHAR NOT NULL
);

CREATE TABLE IF NOT EXISTS APP.REVIEW_AUDIT_EVENTS (
  AUDIT_EVENT_ID VARCHAR NOT NULL,
  CASE_ID VARCHAR NOT NULL,
  EVENT_TYPE VARCHAR NOT NULL,
  FROM_STATUS VARCHAR,
  TO_STATUS VARCHAR,
  EVENT_NOTE VARCHAR,
  ACTOR VARCHAR NOT NULL,
  EVENT_AT TIMESTAMP_LTZ NOT NULL
);

CREATE SEQUENCE IF NOT EXISTS APP.REVIEW_AUDIT_SEQUENCE START = 1 INCREMENT = 1;

CREATE SEQUENCE IF NOT EXISTS APP.DOCUMENT_INTAKE_SEQUENCE START = 1 INCREMENT = 1;

CREATE TABLE IF NOT EXISTS APP.DOCUMENT_INTAKE_EVENTS (
  INTAKE_ID VARCHAR NOT NULL,
  SHIPMENT_ID VARCHAR NOT NULL,
  DECLARED_DOCUMENT_TYPE VARCHAR NOT NULL,
  ORIGINAL_FILENAME VARCHAR NOT NULL,
  SAFE_FILENAME VARCHAR NOT NULL,
  CONTENT_TYPE VARCHAR,
  SIZE_BYTES NUMBER(38, 0) NOT NULL,
  SHA256 VARCHAR NOT NULL,
  STAGE_PATH VARCHAR,
  STAGE_STATUS VARCHAR NOT NULL,
  CLIENT_VALIDATION VARCHAR NOT NULL,
  VERIFICATION_STATUS VARCHAR NOT NULL,
  MATCHED_DOCUMENT_ID VARCHAR,
  MATCHED_SHIPMENT_ID VARCHAR,
  MATCHED_DOCUMENT_TYPE VARCHAR,
  PROCESSING_MODE VARCHAR NOT NULL,
  STATUS_NOTE VARCHAR NOT NULL,
  ERROR_DETAILS VARCHAR,
  VIEWER_IDENTITY VARCHAR NOT NULL,
  CREATED_BY VARCHAR NOT NULL,
  CREATED_AT TIMESTAMP_LTZ NOT NULL,
  CONSTRAINT DOCUMENT_INTAKE_EVENTS_PK PRIMARY KEY (INTAKE_ID)
);

-- Make upgrades safe for cases created before the append-only audit contract existed,
-- or by an interrupted deployment immediately before its audit insert.
INSERT INTO APP.REVIEW_AUDIT_EVENTS
SELECT
  'AUD-' || LPAD(APP.REVIEW_AUDIT_SEQUENCE.NEXTVAL::VARCHAR, 8, '0'),
  review.case_id, 'CASE_CREATED', NULL, review.status,
  'Audit event backfilled during governed workflow migration.',
  review.created_by, review.created_at
FROM APP.REVIEW_CASES review
WHERE NOT EXISTS (
  SELECT 1 FROM APP.REVIEW_AUDIT_EVENTS audit
  WHERE audit.case_id = review.case_id AND audit.event_type = 'CASE_CREATED'
);

CREATE OR REPLACE PROCEDURE APP.PROPOSE_REVIEW_CASE(
  P_SHIPMENT_ID VARCHAR,
  P_EXCEPTION_IDS ARRAY,
  P_REASON VARCHAR,
  P_SEVERITY VARCHAR,
  P_SOURCE_QUESTION VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
  known_shipment_count INTEGER;
  known_exception_count INTEGER;
BEGIN
  IF (LENGTH(TRIM(COALESCE(P_REASON, ''))) < 5 OR LENGTH(P_REASON) > 1000) THEN
    RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'Reason must contain 5 to 1000 characters.');
  END IF;
  IF (LENGTH(TRIM(COALESCE(P_SOURCE_QUESTION, ''))) < 3 OR LENGTH(P_SOURCE_QUESTION) > 2000) THEN
    RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'Source question must contain 3 to 2000 characters.');
  END IF;
  IF (P_EXCEPTION_IDS IS NULL OR ARRAY_SIZE(P_EXCEPTION_IDS) = 0) THEN
    RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'At least one exception ID is required.');
  END IF;
  SELECT COUNT(*) INTO :known_shipment_count
  FROM RAW.SHIPMENTS WHERE shipment_id = :P_SHIPMENT_ID;
  IF (known_shipment_count <> 1) THEN
    RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'Unknown shipment ID.');
  END IF;
  IF (UPPER(COALESCE(P_SEVERITY, '')) NOT IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')) THEN
    RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'Invalid severity.');
  END IF;
  SELECT COUNT(*) INTO :known_exception_count
  FROM ANALYTICS.SHIPMENT_EXCEPTIONS e
  WHERE e.shipment_id = :P_SHIPMENT_ID
    AND e.exception_id IN (SELECT value::STRING FROM TABLE(FLATTEN(INPUT => :P_EXCEPTION_IDS)));
  IF (known_exception_count <> ARRAY_SIZE(P_EXCEPTION_IDS)) THEN
    RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'One or more exception IDs are invalid.');
  END IF;
  RETURN OBJECT_CONSTRUCT(
    'status', 'PROPOSED', 'shipment_id', P_SHIPMENT_ID,
    'exception_ids', P_EXCEPTION_IDS, 'reason', TRIM(P_REASON),
    'severity', UPPER(P_SEVERITY), 'source_question', TRIM(P_SOURCE_QUESTION)
  );
END;
$$;

CREATE OR REPLACE PROCEDURE APP.CREATE_REVIEW_CASE(
  P_SHIPMENT_ID VARCHAR,
  P_EXCEPTION_IDS ARRAY,
  P_REASON VARCHAR,
  P_SEVERITY VARCHAR,
  P_CONFIRMED BOOLEAN,
  P_SOURCE_QUESTION VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
  proposal VARIANT;
  duplicate_count INTEGER;
  new_case_id VARCHAR;
  new_audit_event_id VARCHAR;
  clean_reason VARCHAR;
  clean_severity VARCHAR;
  clean_source_question VARCHAR;
BEGIN
  IF (NOT COALESCE(P_CONFIRMED, FALSE)) THEN
    RETURN OBJECT_CONSTRUCT('status', 'BLOCKED', 'message', 'Explicit confirmation is required.');
  END IF;
  CALL APP.PROPOSE_REVIEW_CASE(:P_SHIPMENT_ID, :P_EXCEPTION_IDS, :P_REASON,
    :P_SEVERITY, :P_SOURCE_QUESTION) INTO :proposal;
  IF (proposal:status::STRING <> 'PROPOSED') THEN RETURN proposal; END IF;
  clean_reason := TRIM(P_REASON);
  clean_severity := UPPER(P_SEVERITY);
  clean_source_question := TRIM(P_SOURCE_QUESTION);

  SELECT COUNT(*) INTO :duplicate_count FROM APP.REVIEW_CASES
  WHERE shipment_id = :P_SHIPMENT_ID AND status IN ('PENDING', 'IN_REVIEW');
  IF (duplicate_count > 0) THEN
    RETURN OBJECT_CONSTRUCT('status', 'DUPLICATE', 'message', 'An active case already exists for this shipment.');
  END IF;

  SELECT 'RC-' || LPAD(APP.REVIEW_CASE_SEQUENCE.NEXTVAL::VARCHAR, 6, '0') INTO :new_case_id;
  INSERT INTO APP.REVIEW_CASES (
    case_id, shipment_id, reason, severity, status, source_question,
    created_by, created_at, confirmation_recorded, updated_at, updated_by
  ) VALUES (
    :new_case_id, :P_SHIPMENT_ID, :clean_reason, :clean_severity, 'PENDING',
    :clean_source_question, CURRENT_USER(), CURRENT_TIMESTAMP(), TRUE,
    CURRENT_TIMESTAMP(), CURRENT_USER()
  );
  INSERT INTO APP.REVIEW_CASE_EXCEPTIONS
  SELECT :new_case_id, value::STRING, CURRENT_TIMESTAMP(), CURRENT_USER()
  FROM TABLE(FLATTEN(INPUT => :P_EXCEPTION_IDS));
  SELECT 'AUD-' || LPAD(APP.REVIEW_AUDIT_SEQUENCE.NEXTVAL::VARCHAR, 8, '0')
    INTO :new_audit_event_id;
  INSERT INTO APP.REVIEW_AUDIT_EVENTS VALUES (
    :new_audit_event_id,
    :new_case_id, 'CASE_CREATED', NULL, 'PENDING', :clean_reason,
    CURRENT_USER(), CURRENT_TIMESTAMP()
  );
  RETURN OBJECT_CONSTRUCT('status', 'CREATED', 'case_id', new_case_id,
    'shipment_id', P_SHIPMENT_ID);
END;
$$;

CREATE OR REPLACE PROCEDURE APP.UPDATE_REVIEW_CASE(
  P_CASE_ID VARCHAR,
  P_NEW_STATUS VARCHAR,
  P_ASSIGNED_TO VARCHAR,
  P_RESOLUTION_NOTE VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
  old_status VARCHAR;
  new_audit_event_id VARCHAR;
  target_status VARCHAR;
  clean_assigned_to VARCHAR;
  clean_resolution_note VARCHAR;
BEGIN
  target_status := UPPER(P_NEW_STATUS);
  clean_assigned_to := NULLIF(TRIM(P_ASSIGNED_TO), '');
  clean_resolution_note := NULLIF(TRIM(P_RESOLUTION_NOTE), '');
  SELECT status INTO :old_status FROM APP.REVIEW_CASES WHERE case_id = :P_CASE_ID;
  IF (old_status IS NULL) THEN RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'Unknown case ID.'); END IF;
  IF (NOT ((old_status = 'PENDING' AND UPPER(P_NEW_STATUS) IN ('IN_REVIEW', 'REJECTED'))
      OR (old_status = 'IN_REVIEW' AND UPPER(P_NEW_STATUS) IN ('RESOLVED', 'REJECTED')))) THEN
    RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'Illegal status transition.');
  END IF;
  IF (UPPER(P_NEW_STATUS) IN ('RESOLVED', 'REJECTED')
      AND LENGTH(TRIM(COALESCE(P_RESOLUTION_NOTE, ''))) < 5) THEN
    RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'A resolution note is required.');
  END IF;
  UPDATE APP.REVIEW_CASES SET status = :target_status, assigned_to = :clean_assigned_to,
    resolution_note = :clean_resolution_note, updated_at = CURRENT_TIMESTAMP(), updated_by = CURRENT_USER(),
    resolved_at = IFF(:target_status IN ('RESOLVED', 'REJECTED'), CURRENT_TIMESTAMP(), NULL),
    resolved_by = IFF(:target_status IN ('RESOLVED', 'REJECTED'), CURRENT_USER(), NULL)
  WHERE case_id = :P_CASE_ID;
  SELECT 'AUD-' || LPAD(APP.REVIEW_AUDIT_SEQUENCE.NEXTVAL::VARCHAR, 8, '0')
    INTO :new_audit_event_id;
  INSERT INTO APP.REVIEW_AUDIT_EVENTS VALUES (
    :new_audit_event_id,
    :P_CASE_ID, 'STATUS_CHANGED', :old_status, :target_status,
    :clean_resolution_note, CURRENT_USER(), CURRENT_TIMESTAMP()
  );
  RETURN OBJECT_CONSTRUCT('status', 'UPDATED', 'case_id', P_CASE_ID, 'new_status', target_status);
END;
$$;

CREATE OR REPLACE PROCEDURE APP.RECORD_DOCUMENT_INTAKE(
  P_SHIPMENT_ID VARCHAR,
  P_DOCUMENT_TYPE VARCHAR,
  P_ORIGINAL_FILENAME VARCHAR,
  P_SAFE_FILENAME VARCHAR,
  P_CONTENT_TYPE VARCHAR,
  P_SIZE_BYTES NUMBER,
  P_SHA256 VARCHAR,
  P_STAGE_PATH VARCHAR,
  P_STAGE_STATUS VARCHAR,
  P_CLIENT_VALIDATION VARCHAR,
  P_ERROR_DETAILS VARCHAR,
  P_VIEWER_IDENTITY VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
  known_shipment_count INTEGER;
  matched_count INTEGER;
  matched_document_id VARCHAR;
  matched_shipment_id VARCHAR;
  matched_document_type VARCHAR;
  existing_intake_id VARCHAR;
  new_intake_id VARCHAR;
  verification_status VARCHAR;
  status_note VARCHAR;
  clean_viewer_identity VARCHAR;
BEGIN
  clean_viewer_identity := COALESCE(
    NULLIF(LEFT(TRIM(P_VIEWER_IDENTITY), 255), ''),
    'UNKNOWN_VIEWER'
  );
  SELECT COUNT(*) INTO :known_shipment_count
  FROM RAW.SHIPMENTS WHERE shipment_id = :P_SHIPMENT_ID;
  IF (known_shipment_count <> 1) THEN
    RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'Unknown shipment ID.');
  END IF;
  IF (UPPER(COALESCE(P_DOCUMENT_TYPE, '')) NOT IN ('SI', 'DRAFT_BL')) THEN
    RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'Document type must be SI or DRAFT_BL.');
  END IF;
  IF (P_SIZE_BYTES < 0 OR P_SIZE_BYTES > 209715200) THEN
    RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'Invalid uploaded file size.');
  END IF;
  IF (UPPER(COALESCE(P_CLIENT_VALIDATION, '')) = 'VALID_PDF'
      AND (P_SIZE_BYTES < 1 OR P_SIZE_BYTES > 10485760)) THEN
    RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'Valid PDFs must be between 1 byte and 10 MB.');
  END IF;
  IF (NOT REGEXP_LIKE(LOWER(COALESCE(P_SHA256, '')), '^[0-9a-f]{64}$')) THEN
    RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'Invalid SHA-256 digest.');
  END IF;
  IF (LENGTH(COALESCE(P_SAFE_FILENAME, '')) < 5 OR LENGTH(P_SAFE_FILENAME) > 255) THEN
    RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'Invalid safe filename.');
  END IF;
  IF (UPPER(COALESCE(P_STAGE_STATUS, '')) NOT IN ('STAGED', 'NOT_STAGED', 'FAILED')) THEN
    RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'Invalid stage status.');
  END IF;
  IF (UPPER(COALESCE(P_CLIENT_VALIDATION, '')) NOT IN (
      'VALID_PDF', 'EMPTY_FILE', 'TOO_LARGE', 'INVALID_EXTENSION',
      'INVALID_CONTENT_TYPE', 'INVALID_PDF_SIGNATURE', 'MISSING_PDF_EOF', 'STAGE_FAILED')) THEN
    RETURN OBJECT_CONSTRUCT('status', 'REJECTED', 'message', 'Invalid client validation status.');
  END IF;

  SELECT COUNT(*), MAX(document_id), MAX(shipment_id), MAX(document_type)
    INTO :matched_count, :matched_document_id, :matched_shipment_id, :matched_document_type
  FROM RAW.DOCUMENT_FILE_REGISTRY
  WHERE sha256 = LOWER(:P_SHA256);

  SELECT MAX(intake_id) INTO :existing_intake_id
  FROM APP.DOCUMENT_INTAKE_EVENTS
  WHERE shipment_id = :P_SHIPMENT_ID
    AND declared_document_type = UPPER(:P_DOCUMENT_TYPE)
    AND sha256 = LOWER(:P_SHA256)
    AND stage_status = 'STAGED';
  IF (existing_intake_id IS NOT NULL) THEN
    RETURN OBJECT_CONSTRUCT(
      'status', 'DUPLICATE', 'intake_id', existing_intake_id,
      'message', 'This exact file is already staged for the selected shipment and document type.'
    );
  END IF;

  IF (UPPER(P_CLIENT_VALIDATION) <> 'VALID_PDF' OR UPPER(P_STAGE_STATUS) <> 'STAGED') THEN
    verification_status := 'REJECTED';
    status_note := 'File-level validation or Snowflake staging failed; governed evidence was not changed.';
  ELSEIF (matched_count = 0) THEN
    verification_status := 'VALID_UNREGISTERED';
    status_note := 'Structurally valid PDF staged in quarantine; content verification is unavailable on this trial account.';
  ELSEIF (matched_count = 1 AND matched_shipment_id = P_SHIPMENT_ID
      AND matched_document_type = UPPER(P_DOCUMENT_TYPE)) THEN
    verification_status := 'VERIFIED_REGISTERED';
    status_note := 'Checksum, shipment binding, and document type match a registered synthetic demonstration file.';
  ELSE
    verification_status := 'CONTEXT_MISMATCH';
    status_note := 'Checksum matches a registered file, but the selected shipment or document type does not match.';
  END IF;

  SELECT 'INT-' || LPAD(APP.DOCUMENT_INTAKE_SEQUENCE.NEXTVAL::VARCHAR, 8, '0')
    INTO :new_intake_id;
  INSERT INTO APP.DOCUMENT_INTAKE_EVENTS (
    intake_id, shipment_id, declared_document_type, original_filename, safe_filename,
    content_type, size_bytes, sha256, stage_path, stage_status, client_validation,
    verification_status, matched_document_id, matched_shipment_id,
    matched_document_type, processing_mode, status_note, error_details,
    viewer_identity, created_by, created_at
  ) VALUES (
    :new_intake_id, :P_SHIPMENT_ID, UPPER(:P_DOCUMENT_TYPE), :P_ORIGINAL_FILENAME,
    :P_SAFE_FILENAME, :P_CONTENT_TYPE, :P_SIZE_BYTES, LOWER(:P_SHA256), :P_STAGE_PATH,
    UPPER(:P_STAGE_STATUS), UPPER(:P_CLIENT_VALIDATION), :verification_status,
    :matched_document_id, :matched_shipment_id, :matched_document_type,
    'INTAKE_ONLY', :status_note, LEFT(:P_ERROR_DETAILS, 2000),
    :clean_viewer_identity,
    CURRENT_USER(), CURRENT_TIMESTAMP()
  );
  RETURN OBJECT_CONSTRUCT_KEEP_NULL(
    'status', 'RECORDED', 'intake_id', new_intake_id,
    'verification_status', verification_status, 'message', status_note,
    'matched_document_id', matched_document_id,
    'matched_shipment_id', matched_shipment_id,
    'matched_document_type', matched_document_type,
    'stage_path', P_STAGE_PATH
  );
END;
$$;

CREATE OR REPLACE AGENT APP.VERICARGO_AGENT
  COMMENT = 'Governed supply-chain analytics and structured evidence agent for VeriCargo OneTruth'
  PROFILE = '{"display_name":"VeriCargo OneTruth","color":"blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  orchestration:
    capabilities:
      analytical_search: true
    tool_not_accessible: reject
    budget:
      seconds: 60
      tokens: 12000

  instructions:
    response: "Answer concisely. Name the governed metric, grain, filters, time window, and USD currency assumption when relevant. Cite document source filenames. If evidence is missing, ambiguous, or unreadable, say so and recommend human review; never invent a value."
    orchestration: "Use SupplyChainAnalyst for governed KPI, entity, exception, and structured SI or bill-of-lading evidence questions. For document evidence, query the documents table and cite relative_path. Use ProposeReviewCase only to validate a review recommendation; it never writes data. Never claim that a case was created. The Streamlit application alone obtains explicit confirmation and performs the mutating call. Pass the exact source question into source_question."
    sample_questions:
      - question: "What is our on-time delivery rate?"
      - question: "Why is SHP-1002 in exception? Cite the source documents."
      - question: "Show unresolved document exceptions."

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "SupplyChainAnalyst"
        description: "Queries governed supply-chain entities and canonical metrics."
    - tool_spec:
        type: "generic"
        name: "ProposeReviewCase"
        description: "Validates and proposes a human-review case without writing data. The UI must obtain confirmation before creation."
        input_schema:
          type: "object"
          properties:
            p_shipment_id:
              type: "string"
              description: "Known shipment identifier."
            p_reason:
              type: "string"
              description: "Evidence-grounded reason for human review."
            p_severity:
              type: "string"
              description: "LOW, MEDIUM, HIGH, or CRITICAL."
            p_exception_ids:
              type: "array"
              items:
                type: "string"
              description: "Known exception identifiers associated with the shipment."
            p_source_question:
              type: "string"
              description: "The exact user request that led to case creation."
          required:
            - "p_shipment_id"
            - "p_reason"
            - "p_severity"
            - "p_exception_ids"
            - "p_source_question"

  tool_resources:
    SupplyChainAnalyst:
      semantic_view: "VERICARGO_ONETRUTH.ANALYTICS.SUPPLY_CHAIN_SEMANTIC_VIEW"
      execution_environment:
        type: "warehouse"
        warehouse: "VERICARGO_WH"
        query_timeout: 60
    ProposeReviewCase:
      type: "procedure"
      identifier: "VERICARGO_ONETRUTH.APP.PROPOSE_REVIEW_CASE"
      execution_environment:
        type: "warehouse"
        warehouse: "VERICARGO_WH"
        query_timeout: 30
  $$;
