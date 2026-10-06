# Known limitations

## Demonstration data

- All operational records and SI / Draft BL files are deterministic, team-authored
  synthetic fixtures.
- The six-shipment dataset is designed to prove matched, mismatched, missing, unreadable
  and ambiguous scenarios; it is not a volume or performance benchmark.
- Source page/location is nullable because the current document APIs do not persist a
  reliable page coordinate for every extracted field.
- The event-provided `WH80281` account is classified by Snowflake as a trial account and
  rejects both `AI_PARSE_DOCUMENT` and `AI_EXTRACT`. The deployment therefore uses the
  disclosed `FIXTURE` document-processing mode: deterministic extracted fields generated
  from the same team-authored synthetic PDFs. The native `AI` procedure remains in source
  for entitled accounts, but it is not claimed as the runtime used by this deployment.
- The same event trial rejects `EMBED_TEXT_768`, which Cortex Search invokes while indexing.
  The submitted runtime therefore uses `EVIDENCE_RETRIEVAL_MODE=SEMANTIC_VIEW`: Cortex
  Analyst queries governed structured document fields, confidence, errors and source
  filenames. The optional Search-enabled Agent is retained under `snowflake/optional/` for
  an entitled account and is not claimed as active in this trial deployment.

## Current integration boundary

The submission is not currently connected to:

- Gmail or Outlook;
- the pre-existing VeriCargo Chrome extension;
- Google Cloud Run or Firestore;
- live ERP, TMS or WMS platforms;
- carrier APIs;
- customer production data.

These are future integration possibilities, not demonstrated capabilities.

## Document intake boundary

- The judged Streamlit interface does not expose arbitrary PDF upload because the event
  account cannot complete field extraction for a new document.
- A governed quarantine-intake backend remains in source for future integration testing. It
  can validate file structure, calculate SHA-256, stage bytes and append an audit event, but
  it is not presented as a completed analysis capability.
- The event trial still cannot perform native field extraction for an unknown upload because
  both document-AI functions are blocked. Production promotion would require entitlement,
  malware/content scanning, authorization policy, and an approved manifest-promotion step.
- Snowflake documents a 200 MB default upload limit for warehouse-runtime Streamlit apps:
  https://docs.snowflake.com/en/developer-guide/streamlit/limitations

## Runtime and automation

- Judges require access to the hackathon Snowflake account; there is no public hosted copy.
- The organizer event account exposes hosted CoCo Automations. Creation and a manual run
  still require completion evidence; `APP.DAILY_EXCEPTION_DIGEST` remains the deterministic
  Snowflake Task fallback.
- Live Agent responses depend on Cortex service availability and may be slower than the
  deterministic application views.
- Stable read-only application views use a 45-second, single-session cache to make repeated
  page and shipment switches faster. Review queues and audit history remain uncached so a
  confirmed action appears immediately. The Refresh data button invalidates the read cache.
- The updated decision-first Streamlit artifact is deployed and passes headless execution.

## Workflow

- There is intentionally no destructive demo reset. Active cases must be resolved or
  rejected through legal transitions before a new case can be created for the shipment.
- The Agent cannot create or update a review case. It can only answer and submit a
  non-mutating proposal; Streamlit performs the confirmed mutation.
