# CoCo lifecycle evidence ledger

This file is a checklist and index. Never invent session IDs, screenshots, query IDs, or
claims. Replace each `PENDING` entry only after the action actually occurs in Snowflake
CoCo CLI or Desktop.

## Opening planning prompt

```text
You are planning VeriCargo OneTruth for Challenge 5 of the Snowflake CoCo CLI Hackathon.
Inspect this repository and the generated synthetic data without editing files. Validate
the Supplier -> Part -> Plant -> Order -> Shipment -> Port -> Customer ontology, the four
canonical metric definitions, the document exception workflow, the Snowflake object graph,
and the acceptance tests. Identify invalid Snowflake syntax, unsafe action paths, missing
edge cases, and scope that should be cut. Produce a decision-complete plan and do not begin
implementation until I approve it.
```

## Planning

- Status: PENDING
- CoCo surface: CLI Plan mode
- Session ID/title: PENDING
- Evidence files: PENDING
- Decisions and changes to the initial scaffold: PENDING

## Development

- Status: PENDING
- CoCo surface: CLI or Desktop Agent mode
- Session ID/title: PENDING
- Commits or files changed by CoCo: PENDING
- Evidence files: PENDING

Required development prompts should include semantic-view validation, document-pipeline
review, Streamlit integration, and least-privilege action-tool review.

## Execution

- Status: PENDING
- CoCo surface: CLI
- Session ID/title: PENDING
- Snowflake query IDs: PENDING
- Streamlit URL: PENDING
- Evidence files: PENDING

## Testing and repair

- Status: PENDING
- CoCo surface: CLI or Desktop
- Session ID/title: PENDING
- Local and Snowflake test results: PENDING
- Failed-then-fixed example: PENDING
- Evidence files: PENDING

## Ingenuity evidence

- Reusable project skill invocation: PENDING
- CoCo automation name/run ID: PENDING
- Fallback Snowflake Task run ID: PENDING
- Guarded review-case action proof: PENDING
- Cross-surface demonstration: PENDING

Create the hosted read-only digest only after the core objects validate:

```powershell
.\scripts\create_coco_automation.ps1 -Connection YOUR_HACKATHON_CONNECTION
cortex -c YOUR_HACKATHON_CONNECTION automation execute vericargo_daily_exception_digest --wait
cortex -c YOUR_HACKATHON_CONNECTION automation doctor vericargo_daily_exception_digest
```

## Suggested evidence filename convention

`YYYYMMDD-HHMM_phase_short-description.png`

Store public-safe screenshots and summaries under `docs/coco-evidence/`. Keep screenshots
containing account identifiers, email addresses, credentials, or private URLs outside the
repository.

