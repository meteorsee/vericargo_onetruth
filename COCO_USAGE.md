# CoCo lifecycle evidence ledger

This file is a checklist and index. Never invent session IDs, screenshots, query IDs, or
claims. Replace each `PENDING` entry only after the action actually occurs in Snowflake
CoCo CLI or Desktop.

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

- Reusable project skill invocation: file exists at `.snowflake/cortex/skills/vericargo-supply-chain-governance/SKILL.md`; its invariants were applied during this session's review (governance skill content read and enforced for the port alias fix)
- CoCo automation name/run ID: PENDING (run `create_coco_automation.ps1` next)
- Fallback Snowflake Task run ID: `APP.DAILY_EXCEPTION_DIGEST` deployed and resumed
- Guarded review-case action proof: query `01c75ef1-3203-7356-0018-686a0006f18a` — `CREATE_REVIEW_CASE` with `P_CONFIRMED=FALSE` returned `BLOCKED`
- Cross-surface demonstration: PENDING

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

