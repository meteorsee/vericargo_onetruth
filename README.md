# VeriCargo OneTruth

**Governed Supply Chain Ontology and Exception Copilot**

VeriCargo OneTruth is a Snowflake-native hackathon project for Challenge 5: Supply Chain
Ontology and Governed Conversational Analytics. It connects suppliers, parts, plants,
orders, shipments, ports, inventory, landed costs, and shipping documents through one
governed semantic layer.

The working MVP contains:

- deterministic, referentially consistent synthetic supply-chain data;
- Snowflake raw, curated, analytics, and application schemas;
- dynamic-table pipelines, a Snowpark shipment-risk transform, and four canonical metrics;
- SI versus Draft BL parsing, extraction, normalization, comparison, and exception routing;
- `SUPPLY_CHAIN_SEMANTIC_VIEW` with verified persona questions;
- `VERICARGO_AGENT` combining Cortex Analyst, Cortex Search, and a guarded review action;
- a Streamlit control tower and human-review queue;
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
  tables, semantic views, Cortex Search services, agents, procedures, tasks, and Streamlit
  applications
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

Use the opening prompt in [`COCO_USAGE.md`](COCO_USAGE.md), approve the implementation
plan, then switch to Agent mode and have CoCo inspect, revise, execute, and test the
project. Record real session IDs, screenshots, commands, failures, fixes, and query IDs.

## 3. Deploy the Snowflake objects

The deployment helper generates the data, creates Snowflake objects, uploads CSV/PDF
fixtures, processes documents, builds the semantic layer and agent, runs validation, and
deploys Streamlit:

```powershell
.\scripts\deploy.ps1 -Connection YOUR_HACKATHON_CONNECTION
```

The helper is intentionally explicit: it stops on the first failed Snowflake command and
does not hide partially deployed state. Run it from CoCo so execution evidence is captured.

To deploy step-by-step instead, run the SQL files in numeric order. Upload generated CSVs
to `@VERICARGO_ONETRUTH.RAW.CSV_STAGE`, upload documents to
`@VERICARGO_ONETRUTH.RAW.DOCUMENT_STAGE`, and run `02_load.sql` after both uploads.

Create the read-only hosted CoCo automation after the core deployment:

```powershell
.\scripts\create_coco_automation.ps1 -Connection YOUR_HACKATHON_CONNECTION
```

Run it once manually, inspect its transcript with `cortex automation doctor`, and record
the real run/query ID. `07_automation.sql` also installs a Snowflake Task fallback.

## 4. Exercise the demo

Ask these three equivalent questions and verify that they return the same governed value:

1. Planning: "What percentage of delivered shipments arrived on or before promise?"
2. Procurement: "What is supplier delivery compliance against promised dates?"
3. Logistics: "Show our on-time delivery rate for completed shipments."

Then ask:

> Why is shipment SHP-1002 an exception? Cite the shipping-document evidence.

Create a review case only after explicitly confirming the shipment, reason, and severity.
The stored procedure independently blocks unconfirmed actions and unknown shipment IDs.

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

Before submission, complete every unchecked item in `COCO_USAGE.md`, attach organizer
eligibility/reuse confirmation, replace placeholder evidence with genuine CoCo captures,
and ensure judges can access the repository and deployed Streamlit application.

Use [`docs/submission-checklist.md`](docs/submission-checklist.md) for the hard gates and
[`docs/submission-deck.md`](docs/submission-deck.md) for the judge-facing English deck copy.

