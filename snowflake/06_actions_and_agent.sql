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

CREATE OR REPLACE PROCEDURE APP.CREATE_REVIEW_CASE(
  P_SHIPMENT_ID VARCHAR,
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
  known_shipment_count INTEGER;
  new_case_id VARCHAR;
BEGIN
  IF (NOT COALESCE(P_CONFIRMED, FALSE)) THEN
    RETURN OBJECT_CONSTRUCT(
      'status', 'BLOCKED',
      'message', 'Explicit user confirmation is required; no case was created.'
    );
  END IF;

  IF (UPPER(COALESCE(P_SEVERITY, '')) NOT IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')) THEN
    RETURN OBJECT_CONSTRUCT(
      'status', 'REJECTED',
      'message', 'Severity must be LOW, MEDIUM, HIGH, or CRITICAL.'
    );
  END IF;

  IF (LENGTH(TRIM(COALESCE(P_REASON, ''))) < 5 OR LENGTH(P_REASON) > 1000) THEN
    RETURN OBJECT_CONSTRUCT(
      'status', 'REJECTED',
      'message', 'Reason must contain 5 to 1000 characters.'
    );
  END IF;

  IF (LENGTH(TRIM(COALESCE(P_SOURCE_QUESTION, ''))) < 3
      OR LENGTH(P_SOURCE_QUESTION) > 2000) THEN
    RETURN OBJECT_CONSTRUCT(
      'status', 'REJECTED',
      'message', 'Source question must contain 3 to 2000 characters.'
    );
  END IF;

  SELECT COUNT(*) INTO :known_shipment_count
  FROM RAW.SHIPMENTS
  WHERE shipment_id = :P_SHIPMENT_ID;

  IF (known_shipment_count <> 1) THEN
    RETURN OBJECT_CONSTRUCT(
      'status', 'REJECTED',
      'message', 'Shipment ID is unknown or ambiguous; no case was created.'
    );
  END IF;

  SELECT 'RC-' || LPAD(APP.REVIEW_CASE_SEQUENCE.NEXTVAL::VARCHAR, 6, '0')
    INTO :new_case_id;

  INSERT INTO APP.REVIEW_CASES (
    case_id,
    shipment_id,
    reason,
    severity,
    status,
    source_question,
    created_by,
    created_at,
    confirmation_recorded
  ) VALUES (
    :new_case_id,
    :P_SHIPMENT_ID,
    TRIM(:P_REASON),
    UPPER(:P_SEVERITY),
    'PENDING',
    TRIM(:P_SOURCE_QUESTION),
    CURRENT_USER(),
    CURRENT_TIMESTAMP(),
    TRUE
  );

  RETURN OBJECT_CONSTRUCT(
    'status', 'CREATED',
    'case_id', new_case_id,
    'shipment_id', P_SHIPMENT_ID
  );
END;
$$;

CREATE OR REPLACE CORTEX SEARCH SERVICE CURATED.DOCUMENT_SEARCH
  ON content
  ATTRIBUTES shipment_id, document_type, relative_path
  WAREHOUSE = VERICARGO_WH
  TARGET_LAG = '1 minute'
AS
SELECT
  document_id,
  shipment_id,
  document_type,
  relative_path,
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
    orchestration: "Use SupplyChainAnalyst for governed KPI and entity questions. Use DocumentEvidence for SI or bill-of-lading content and explanations. Use CreateReviewCase only after the user has explicitly confirmed case creation in the current request. Never infer confirmation. Pass the exact source question into source_question."
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
        name: "CreateReviewCase"
        description: "Creates an auditable pending human-review case only after explicit user confirmation."
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
            p_confirmed:
              type: "boolean"
              description: "True only when the user explicitly confirmed creation in the current request."
            p_source_question:
              type: "string"
              description: "The exact user request that led to case creation."
          required:
            - "p_shipment_id"
            - "p_reason"
            - "p_severity"
            - "p_confirmed"
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
    CreateReviewCase:
      type: "procedure"
      identifier: "VERICARGO_ONETRUTH.APP.CREATE_REVIEW_CASE"
      execution_environment:
        type: "warehouse"
        warehouse: "VERICARGO_WH"
        query_timeout: 30
  $$;
