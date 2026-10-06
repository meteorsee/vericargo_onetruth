# VeriCargo OneTruth

**Governed Supply Chain Ontology and Exception Copilot**

VeriCargo OneTruth is a Snowflake-native hackathon project for Challenge 5: Supply Chain
Ontology and Governed Conversational Analytics. It connects suppliers, parts, plants,
orders, shipments, ports, inventory, landed costs, and shipping documents through one
governed semantic layer.

The judge-first product story is: **one shipment, two destinations, one governed truth**.
For `SHP-1002`, the application connects a one-day delivery delay to conflicting SI and
Draft BL destination/weight evidence, obtains a governed Agent explanation, and turns the
finding into an explicitly confirmed, auditable human-review workflow.

The working MVP contains:

- deterministic, referentially consistent synthetic supply-chain data;
- Snowflake raw, curated, analytics, and application schemas;
- dynamic-table pipelines, a Snowpark shipment-risk transform, and four canonical metrics;
- SI versus Draft BL parsing, extraction, normalization, comparison, and exception routing;
- `SUPPLY_CHAIN_SEMANTIC_VIEW` with verified persona questions;
- `VERICARGO_AGENT` combining Cortex Analyst over governed metrics and structured document evidence with a non-mutating review proposal tool;
- a six-page connected Streamlit control tower with persistent shipment context;
- explicit review confirmation, exception links, legal state transitions, and append-only audit;
- a daily exception digest implemented as a Snowflake Task, plus a CoCo automation prompt;
- local unit tests and in-Snowflake validation queries.

## Important provenance boundary

This is a new repository and product core. The earlier VeriCargo Gmail extension is
team-owned background IP and is not the source of truth or runtime for this entry. See
[`BACKGROUND_IP.md`](BACKGROUND_IP.md) for the exact boundary.

## Prerequisites

- Python 3.11+
- Snowflake CLI (`snow`), either on `PATH` or installed in this repository's `.venv`
- Snowflake CoCo CLI (`cortex`) with hackathon account access
- A Snowflake role allowed to create databases, schemas, warehouses, stages, dynamic
  tables, semantic views, agents, procedures, tasks, and Streamlit applications. Cortex
  Search privileges and AI-model entitlement are optional enhancements.
- `SNOWFLAKE.CORTEX_USER` or `SNOWFLAKE.CORTEX_AGENT_USER` access as required by the
  account

Do not put credentials in this repository. Use a named Snowflake connection.

## 1. Generate and test the synthetic fixture

```powershell
python .\scripts\generate_data.py
python -m unittest discover -s tests -v
```

The generator is deterministic and writes only to `data/generated/`. It includes matched,
mismatched, missing, unreadable, and ambiguous SI/Draft BL scenarios.

## 2. Start the required CoCo planning session

This repository was scaffolded before hackathon CoCo access was available. It must not be
represented as CoCo-generated evidence. Before changing or deploying it, run a genuine
CoCo planning and review session:

```powershell
cortex -w . -c YOUR_HACKATHON_CONNECTION --plan
```

If Windows has not refreshed `PATH`, or if this is the first connection setup, use the
repository launcher instead:

```powershell
# First run: opens CoCo's connection picker/setup wizard.
.\scripts\start_coco.cmd --check
.\scripts\start_coco.cmd

# Later runs: replace the value with the real connection name selected in the wizard.
.\scripts\start_coco.cmd YOUR_REAL_CONNECTION_NAME
```

`YOUR_HACKATHON_CONNECTION` is documentation notation, not a literal connection name.

Use the opening prompt in [`COCO_USAGE.md`](COCO_USAGE.md), approve the implementation
plan, then switch to Agent mode and have CoCo inspect, revise, execute, and test the
project. Record real session IDs, screenshots, commands, failures, fixes, and query IDs.

## 3. Deploy the Snowflake objects

The deployment helper generates the data, creates Snowflake objects, uploads CSV/PDF
fixtures, processes documents, builds the semantic layer and agent, runs validation, and
deploys Streamlit:

The event trial account rejects `AI_PARSE_DOCUMENT` and `AI_EXTRACT`. For that account,
`RAW.RUNTIME_CONFIG` defaults to the transparent `FIXTURE` processing mode, which loads
deterministic fields generated from the team-authored synthetic PDFs. The original native
`AI` procedure remains available in source for entitled Snowflake accounts; the deployed
runtime must be described according to the configured mode shown on the Governance page.
The same account also rejects the embedding model used by Cortex Search. The default
deployment therefore exposes structured SI/Draft BL evidence and source filenames through
`SUPPLY_CHAIN_SEMANTIC_VIEW` and Cortex Analyst. It does not create a Search service, so it
does not call `EMBED_TEXT_768`.

The judged Streamlit application intentionally does not expose arbitrary document upload.
The event trial cannot extract and validate a newly supplied PDF, so the visible workflow
uses the staged, team-authored synthetic SI / Draft BL scenarios and makes that boundary
explicit. A quarantine-intake backend remains in source as future, non-demonstrated work.

```powershell
.\scripts\deploy.ps1 -Connection YOUR_HACKATHON_CONNECTION
```

On a non-trial account entitled to Cortex Search, install the optional retrieval service
and Search-enabled Agent only after the core deployment succeeds:

```powershell
.\.venv\Scripts\snow.exe sql -c YOUR_ENTITLED_CONNECTION `
  -f .\snowflake\optional\06_search_and_agent_entitled.sql
```

If PowerShell reports that script execution is disabled, invoke it without changing the
machine-wide policy:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 `
  -Connection YOUR_REAL_CONNECTION_NAME -RunAgentTests
```

The helper is intentionally explicit: it stops on the first failed Snowflake command and
does not hide partially deployed state. Run it from CoCo so execution evidence is captured.

For external-browser OAuth environments that cannot cache credentials between Snow CLI
processes, the equivalent one-login data-layer deployment is:

```powershell
python .\scripts\deploy_live.py --connection YOUR_REAL_CONNECTION_NAME
```

Use `--start-at 06b_application_views.sql` to resume safely after a repaired step, and
`--only 09_agent_smoke_tests.sql` or `--only 10_workflow_smoke_tests.sql` for the optional
Cortex and mutating workflow acceptance suites.

To deploy step-by-step instead, run the SQL files in numeric order. Upload generated CSVs
to `@VERICARGO_ONETRUTH.RAW.CSV_STAGE`, upload documents to
`@VERICARGO_ONETRUTH.RAW.DOCUMENT_STAGE`, and run `02_load.sql` after both uploads.

Create the read-only hosted CoCo automation after the core deployment:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\scripts\create_coco_automation.ps1 -Connection YOUR_REAL_CONNECTION_NAME
```

If the installed CoCo build exposes hosted Automations, run it once manually, inspect its
transcript with `cortex automation doctor`, and record the real run/query ID. If the trial
account cannot reach or authorize the Automations endpoint, record the real error and use
the Snowflake Task installed by `07_automation.sql`; do not enable an experimental feature
flag only for the submission demo.

The fallback can be exercised without changing its schedule:

```sql
EXECUTE TASK VERICARGO_ONETRUTH.APP.DAILY_EXCEPTION_DIGEST;
SELECT *
FROM VERICARGO_ONETRUTH.APP.EXCEPTION_DIGEST_RUNS
ORDER BY RUN_AT DESC
LIMIT 1;
```

## 4. Exercise the demo

Ask these three equivalent questions and verify that they return the same governed value:

1. Planning: "What percentage of delivered shipments arrived on or before promise?"
2. Procurement: "What is supplier delivery compliance against promised dates?"
3. Logistics: "Show our on-time delivery rate for completed shipments."

Then ask:

> Why is shipment SHP-1002 an exception? Cite the shipping-document evidence.

The agent can propose but cannot create a review case. Create one only after explicitly
confirming the shipment, linked exceptions, reason, and severity in Streamlit. The stored
procedure independently blocks unconfirmed actions, unknown IDs, duplicates, and illegal
state transitions.

## Repository map

```text
app/                         Streamlit control tower
automations/                 CoCo automation prompt
data/generated/              Synthetic CSV and PDF fixtures
docs/                        Architecture, demo, and CoCo evidence ledger
scripts/                     Data generation and deployment helpers
snowflake/                   Ordered Snowflake deployment SQL
src/vericargo_onetruth/      Deterministic domain logic
tests/                       Local acceptance tests
.snowflake/cortex/skills/    Reusable CoCo governance skill
```

## Submission readiness

Before submission, complete every required item in `COCO_USAGE.md`, keep organizer
eligibility/reuse correspondence outside the public repository, and ensure judges can
access the repository and deployed Streamlit application.

Use [`docs/submission-deck.md`](docs/submission-deck.md) for the judge-facing English deck
copy. The latest executed checks are in [`docs/test-results.md`](docs/test-results.md), and
the credential-free access instructions are in [`docs/judge-access.md`](docs/judge-access.md).

The public product and demonstration documentation includes:

- [`docs/ui_flow.md`](docs/ui_flow.md): shared context and connected actions;
- [`docs/demo_flow.md`](docs/demo_flow.md): complete judge journey and safe repeatability;
- [`docs/known_limitations.md`](docs/known_limitations.md): honest integration/runtime boundary.

