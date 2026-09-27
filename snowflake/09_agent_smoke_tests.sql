USE WAREHOUSE VERICARGO_WH;
USE DATABASE VERICARGO_ONETRUTH;

-- Run this separately after base validation. It incurs Cortex usage and its
-- query IDs should be retained as CoCo testing evidence.
SELECT TRY_PARSE_JSON(SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'VERICARGO_ONETRUTH.APP.VERICARGO_AGENT',
  $${"messages":[{"role":"user","content":[{"type":"text","text":"Operations: what is our on-time delivery rate? State the grain and window."}]}]}$$,
  TRUE
)) AS operations_response;

SELECT TRY_PARSE_JSON(SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'VERICARGO_ONETRUTH.APP.VERICARGO_AGENT',
  $${"messages":[{"role":"user","content":[{"type":"text","text":"Procurement: what percentage of delivered supplier shipments met promise? State the grain and window."}]}]}$$,
  TRUE
)) AS procurement_response;

SELECT TRY_PARSE_JSON(SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'VERICARGO_ONETRUTH.APP.VERICARGO_AGENT',
  $${"messages":[{"role":"user","content":[{"type":"text","text":"Planning: show delivery reliability against promised dates. State the grain and window."}]}]}$$,
  TRUE
)) AS planning_response;

SELECT TRY_PARSE_JSON(SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'VERICARGO_ONETRUTH.APP.VERICARGO_AGENT',
  $${"messages":[{"role":"user","content":[{"type":"text","text":"Why is SHP-1002 in exception? Cite the SI and Draft BL filenames, and do not create a review case."}]}]}$$,
  TRUE
)) AS evidence_response;
