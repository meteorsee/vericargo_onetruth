# Known limitations

## Demonstration data

- All operational records and SI / Draft BL files are deterministic, team-authored
  synthetic fixtures.
- The six-shipment dataset is designed to prove matched, mismatched, missing, unreadable
  and ambiguous scenarios; it is not a volume or performance benchmark.
- Source page/location is nullable because the current document APIs do not persist a
  reliable page coordinate for every extracted field.

## Current integration boundary

The submission is not currently connected to:

- Gmail or Outlook;
- the pre-existing VeriCargo Chrome extension;
- Google Cloud Run or Firestore;
- live ERP, TMS or WMS platforms;
- carrier APIs;
- customer production data.

These are future integration possibilities, not demonstrated capabilities.

## User-supplied files

- The submitted MVP does not currently expose an upload control. Its source documents are
  deployed synthetic fixtures so every judged scenario is deterministic and repeatable.
- A production extension is feasible with Streamlit's `st.file_uploader`, which is generally
  available in Streamlit in Snowflake. Uploaded bytes would be validated, checksummed and
  written to `RAW.DOCUMENT_STAGE`; a manifest row would bind the file to a known shipment;
  the existing parse, extract, compare, exception, Search and review pipeline would then run.
- The upload path requires explicit file-size/type limits, duplicate handling, malware/content
  controls, shipment authorization, audit events and a processing-status UI. It must not write
  directly to curated tables or bypass the existing unresolved-evidence guardrail.
- Snowflake documents a 200 MB default upload limit for warehouse-runtime Streamlit apps:
  https://docs.snowflake.com/en/developer-guide/streamlit/limitations

## Runtime and automation

- Judges require access to the hackathon Snowflake account; there is no public hosted copy.
- Hosted CoCo Automations were unavailable in the current trial environment. The verified
  fallback is `APP.DAILY_EXCEPTION_DIGEST`, a Snowflake Task.
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
