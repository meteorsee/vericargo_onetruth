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

CREATE OR REPLACE CORTEX SEARCH SERVICE CURATED.DOCUMENT_SEARCH
  ON content
  ATTRIBUTES document_id, shipment_id, document_type, relative_path, source_location
  WAREHOUSE = VERICARGO_WH
  TARGET_LAG = '1 minute'
AS
SELECT
  document_id,
  shipment_id,
  document_type,
  relative_path,
  source_location,
  content
FROM CURATED.DOCUMENT_SEARCH_CORPUS;

CREATE OR REPLACE AGENT APP.VERICARGO_AGENT
  COMMENT = 'Governed supply-chain analytics and evidence agent for VeriCargo OneTruth'
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
    orchestration: "Use SupplyChainAnalyst for governed KPI and entity questions. Use DocumentEvidence for SI or bill-of-lading content and explanations. Use ProposeReviewCase only to validate a review recommendation; it never writes data. Never claim that a case was created. The Streamlit application alone obtains explicit confirmation and performs the mutating call. Pass the exact source question into source_question."
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
        type: "cortex_search"
        name: "DocumentEvidence"
        description: "Searches parsed Shipping Instruction and Draft Bill of Lading evidence."
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
    DocumentEvidence:
      search_service: "VERICARGO_ONETRUTH.CURATED.DOCUMENT_SEARCH"
      max_results: "5"
      title_column: "RELATIVE_PATH"
      id_column: "DOCUMENT_ID"
      stage_path: "@VERICARGO_ONETRUTH.RAW.DOCUMENT_STAGE"
      relative_path_column: "RELATIVE_PATH"
    ProposeReviewCase:
      type: "procedure"
      identifier: "VERICARGO_ONETRUTH.APP.PROPOSE_REVIEW_CASE"
      execution_environment:
        type: "warehouse"
        warehouse: "VERICARGO_WH"
        query_timeout: 30
  $$;
