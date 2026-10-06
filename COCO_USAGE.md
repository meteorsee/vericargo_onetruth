# CoCo lifecycle evidence ledger

This file is a checklist and index. Never invent session IDs, screenshots, query IDs, or
claims. Unavailable and optional evidence is labelled explicitly instead of being presented
as completed work.

## Opening planning prompt

Start Plan mode with `./scripts/start_coco.cmd`. Omit the connection on the first run to
open CoCo's connection picker; after setup, pass the real configured connection name as
the first argument.

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

- Status: COMPLETE
- CoCo surface: CLI Plan mode
- Session ID/title: `4ce0a356-74a1-401e-aa0b-998211484090` (2026-09-27)
- Evidence files: `.cortex/plans/plan_2026-09-27_1231.md`
- Decisions and changes to the initial scaffold:
  - Ontology validated (PASS): Supplier → Part → Plant → Order → Shipment → Port → Customer
  - Four canonical metrics verified consistent across Python, SQL marts, and semantic view
  - Document exception workflow validated across all 5 scenarios
  - Six issues noted in Snowflake object graph (AI_EXTRACT format, LEAST_IGNORE_NULLS, DT chaining, risk table not DT, Cortex Search on view, agent YAML field) — all acceptable
  - Three test gaps noted (port alias parity, source_question min-length, NORMALIZE_PORT SQL test)
  - Scope recommendation: keep all objects, nothing cut

## Development

- Status: COMPLETE
- CoCo surface: CLI Agent mode
- Session ID/title: `b46b47a1-4baa-44dc-aeb8-0091f741b386` (2026-09-28)
- Commits or files changed by CoCo:
  - `snowflake/04_documents.sql` — added KRPUS/BUSAN/PUSAN Korean port aliases to `NORMALIZE_PORT` UDF to achieve Python/SQL parity
- Evidence files: this session transcript

Required development prompts should include semantic-view validation, document-pipeline
review, Streamlit integration, and least-privilege action-tool review.

## Execution

- Status: COMPLETE
- CoCo surface: CLI
- Session ID/title: `b46b47a1-4baa-44dc-aeb8-0091f741b386` (2026-09-28)
- Snowflake query IDs:
  - Context setup: `01c75eee-3203-736a-0018-686a000731f2`
  - FK integrity (9 checks PASS): `01c75eee-3203-7356-0018-686a0006f176`
  - Duplicate keys (6 checks PASS): `01c75eee-3203-736a-0018-686a000731fa`
  - Risk features grain (PASS): `01c75eee-3203-736a-0018-686a000731fe`
  - Canonical metrics (4 checks PASS): `01c75eee-3203-736a-0018-686a00073206`
  - Document outcomes (6 checks PASS): `01c75eef-3203-735c-0018-686a0007422a`
  - App view grain + SHP-1002 findings (PASS): `01c75eef-3203-7356-0018-686a0006f182`
  - Guardrail proof — unconfirmed BLOCKED: `01c75ef1-3203-7356-0018-686a0006f18a`
  - Governance status view: `01c75ef1-3203-736a-0018-686a00073232`
- Streamlit URL: already deployed (pre-existing)
- Evidence files: this session transcript

## Testing and repair

- Status: COMPLETE
- CoCo surface: CLI
- Session ID/title: `b46b47a1-4baa-44dc-aeb8-0091f741b386` (2026-09-28)
- Local and Snowflake test results:
  - Local: 23/23 tests pass (`python -m unittest discover -s tests -v`)
  - Snowflake: all 28 validation checks pass (FK, duplicates, metrics, documents, grain, guardrail)
- Failed-then-fixed example:
  - **Issue**: SQL `NORMALIZE_PORT` UDF missing Korean port aliases (BUSAN/PUSAN/KRPUS) present in Python `document_comparison.py`
  - **Failed query** (`01c75ef2-3203-736a-0018-686a0007323a`): `NORMALIZE_PORT('Busan')` returned `BUSAN` instead of `KRPUS`
  - **Fix**: added `WHEN UPPER(VALUE) RLIKE '.*(KRPUS|BUSAN|PUSAN).*' THEN 'KRPUS'` to `snowflake/04_documents.sql`
  - **Fix deployed** (`01c75ef6-3203-7356-0018-686a0006f1c2`): function recreated
  - **Verified** (`01c75ef6-3203-7356-0018-686a0006f1ca`): all three aliases now return `KRPUS`
  - **Regression check** (`01c75ef6-3203-736a-0018-686a00073266`): all 6 document outcomes unchanged
  - **Local re-test**: 23/23 pass
- Evidence files: this session transcript

## Ingenuity evidence

- Reusable project skill invocation: explicitly invoked in CoCo session
  `fb9d4d4d-ec13-4d7d-bc9b-426c5cfa14d4`; the skill audited the deployed solution in
  read-only mode against its ontology, metric, evidence, guardrail, and audit invariants.
- Hosted CoCo automation: UNAVAILABLE in the current trial environment. On 2026-09-29,
  `create_coco_automation.ps1` returned: "Could not confirm whether automations are enabled
  for this account (the Cortex Agent endpoint was unreachable)." No experimental feature
  flag was enabled for the submission build.
- Fallback Snowflake Task: `APP.DAILY_EXCEPTION_DIGEST` is started. A manual execution
  succeeded with query ID `01c762ea-3203-7595-0018-686a000af0c6` and produced: "7 open
  exception(s), 3 high/critical, 0 pending human-review case(s)."
- Guarded review-case action proof: query `01c75ef1-3203-7356-0018-686a0006f18a` — `CREATE_REVIEW_CASE` with `P_CONFIRMED=FALSE` returned `BLOCKED`
- Cross-surface demonstration: NOT RUN (optional bonus; excluded from the frozen scope)

## Submission acceptance - 2026-09-29

- CoCo surface: CLI, resumed session
- Session ID/title: `fb9d4d4d-ec13-4d7d-bc9b-426c5cfa14d4`
  (`Submission acceptance 2026-09-29`)
- Fresh Snowflake validation: 28/28 checks PASS
  - Foreign keys: `01c76055-3203-73ca-0018-686a00085612`
  - Duplicate keys: `01c76055-3203-73ca-0018-686a00085616`
  - Shipment risk grain: `01c76055-3203-7366-0018-686a00081536`
  - Canonical KPIs: `01c76055-3203-73c7-0018-686a000833b6`
  - Document outcomes: `01c76055-3203-73ca-0018-686a0008561a`
  - Application views and `SHP-1002`: `01c76055-3203-7357-0018-686a000804b2`
- Agent acceptance:
  - Operations OTD: `01c76057-3203-7366-0018-686a0008153e`
  - Procurement OTD: `01c76057-3203-73c7-0018-686a000833be`
  - Planning OTD: `01c76058-3203-7357-0018-686a000804be`
  - `SHP-1002` combined evidence: `01c76058-3203-73c7-0018-686a000833d2`
  - Unsupported metric / unknown shipment fallback:
    `01c7605e-3203-7366-0018-686a00081596`
  - All three persona questions returned 60% (3 of 5 delivered shipments), shipment grain,
    and the governed all-delivered window. The combined answer cited
    `doc-shp-1002-si.pdf` and `doc-shp-1002-bl.pdf` and made no write.
- Review workflow acceptance:
  - Main workflow block: `01c76060-3203-73c7-0018-686a00083422`
  - Case details: `01c76061-3203-7366-0018-686a000815d2`
  - Exception links: `01c76061-3203-7366-0018-686a000815da`
  - Audit events: `01c76061-3203-7357-0018-686a000804e6`
  - Result: `RC-000201` resolved; two linked exceptions; duplicate active case rejected;
    three audit events for creation, review start, and resolution.
- Streamlit acceptance: `snow streamlit execute
  VERICARGO_ONETRUTH.APP.VERICARGO_ONETRUTH_APP -c <private_connection_name>` completed
  successfully. The local connection alias is intentionally redacted from this public ledger.
- Full destructive redeployment: NOT RUN. The helper truncates deployed tables and would
  overwrite live review/audit evidence. The validated live deployment was preserved; a
  clean-database redeployment remains a pre-freeze rehearsal requiring explicit approval.

Create the hosted read-only digest only after the core objects validate:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\scripts\create_coco_automation.ps1 -Connection YOUR_REAL_CONNECTION_NAME
& "$env:LOCALAPPDATA\cortex\bin\cortex.cmd" -c YOUR_REAL_CONNECTION_NAME `
  automation execute vericargo_daily_exception_digest --wait
& "$env:LOCALAPPDATA\cortex\bin\cortex.cmd" -c YOUR_REAL_CONNECTION_NAME `
  automation doctor vericargo_daily_exception_digest
```

## Suggested evidence filename convention

`YYYYMMDD-HHMM_phase_short-description.png`

Store public-safe screenshots and summaries under `docs/coco-evidence/`. Keep screenshots
containing account identifiers, email addresses, credentials, or private URLs outside the
repository.

## Event-account migration note - 2026-10-05

- The organizer-provided `WH80281` Enterprise trial account accepts hosted CoCo
  Automations, but Snowflake returned error `399258` for `AI_PARSE_DOCUMENT`, legacy
  `SNOWFLAKE.CORTEX.PARSE_DOCUMENT`, and `AI_EXTRACT`: these AI functions are not
  available for trial accounts.
- Native document-AI execution evidence and query IDs above came from the original
  `EL85412` deployment. The migrated event-account runtime uses the explicitly disclosed
  `FIXTURE` processing mode generated from the same synthetic PDFs; it must not be
  presented as fresh model inference.
- The native `AI` procedure remains in source for entitled accounts. Governance exposes
  the active processing mode so judges can distinguish runtime behaviour from the
  portable architecture.
- Cortex Search creation in the event account also failed with Snowflake error `399258`
  because `EMBED_TEXT_768` is unavailable for trial accounts. The core deployment now uses
  `EVIDENCE_RETRIEVAL_MODE=SEMANTIC_VIEW`: Cortex Analyst can query structured document
  fields, confidence, processing status, errors, and source filenames without embeddings.
  `snowflake/optional/06_search_and_agent_entitled.sql` retains the Search-enabled path for
  an entitled account; it is not executed or claimed for the event trial runtime.

