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

## Runtime and automation

- Judges require access to the hackathon Snowflake account; there is no public hosted copy.
- Hosted CoCo Automations were unavailable in the current trial environment. The verified
  fallback is `APP.DAILY_EXCEPTION_DIGEST`, a Snowflake Task.
- Live Agent responses depend on Cortex service availability and may be slower than the
  deterministic application views.
- The updated decision-first Streamlit artifact is locally verified but its replacement
  deployment is pending an interactive external-browser OAuth completion.

## Workflow

- There is intentionally no destructive demo reset. Active cases must be resolved or
  rejected through legal transitions before a new case can be created for the shipment.
- The Agent cannot create or update a review case. It can only answer and submit a
  non-mutating proposal; Streamlit performs the confirmed mutation.
