-- Optional enhancement for Snowflake accounts entitled to Cortex Search embeddings.
-- Do not include this file in the default trial-account deployment.
USE WAREHOUSE VERICARGO_WH;
USE DATABASE VERICARGO_ONETRUTH;

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
  COMMENT = 'Governed supply-chain analytics and Cortex Search evidence agent for VeriCargo OneTruth'
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
    orchestration: "Use SupplyChainAnalyst for governed KPI, entity, exception, and structured document questions. Use DocumentEvidence when retrieval across document content is needed. Use ProposeReviewCase only to validate a review recommendation; it never writes data. Never claim that a case was created. The Streamlit application alone obtains explicit confirmation and performs the mutating call. Pass the exact source question into source_question."
    sample_questions:
      - question: "What is our on-time delivery rate?"
      - question: "Why is SHP-1002 in exception? Cite the source documents."
      - question: "Show unresolved document exceptions."

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "SupplyChainAnalyst"
        description: "Queries governed supply-chain entities, document fields, exceptions, and canonical metrics."
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

UPDATE RAW.RUNTIME_CONFIG
SET config_value = 'CORTEX_SEARCH',
    config_note = 'Entitled-account retrieval through Cortex Search with Semantic View support.',
    updated_at = CURRENT_TIMESTAMP()
WHERE config_key = 'EVIDENCE_RETRIEVAL_MODE';
