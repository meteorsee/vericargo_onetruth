# Current-state implementation audit

Status date: 2026-09-30 (Asia/Kuala_Lumpur)

This audit freezes the working VeriCargo OneTruth implementation before the submission
presentation pass. The Snowflake objects remain the source of truth. Planned changes are
limited to presentation, navigation, progressive disclosure, and regression documentation.

## Entry points and application structure

| Component | Current file | Current status | Backend dependency | Safe to modify? | Planned change |
|---|---|---|---|---|---|
| Repository entry point | `README.md` | Working deployment and demo instructions | Ordered files in `snowflake/` | Documentation only | Add decision-first demo orientation |
| Streamlit entry point | `app/streamlit_app.py` | Working six-page application | `OneTruthService` | Yes - UI only | Add connected decision-first experience |
| Streamlit packaging | `app/snowflake.yml`, `app/environment.yml`, `app/pyproject.toml` | Deployed with warehouse runtime and Streamlit 1.49.1 | Snowflake Streamlit | No change planned | Preserve runtime contract |
| Shared UI helpers | `app/components.py` | Status labels and three next-step buttons | Streamlit session state | Yes | Add reusable presentation components and navigation actions |
| Service boundary | `app/services.py` | Typed reads and governed procedure calls | Eight `APP.VW_*` views, Agent, procedures | Additive helpers only | Preserve every existing public method |
| Navigation | `app/streamlit_app.py` | Sidebar buttons and `current_page` | Streamlit session state | Yes | Consolidate route helpers and remove dead ends |
| Shared shipment context | `app/streamlit_app.py` | `selected_shipment_id` defaults to `SHP-1002` and persists | `APP.VW_SHIPMENT_360` | Yes | Add exception, field, pending-action, and last-question state |

## Current pages

| Component | Current file | Current status | Backend dependency | Safe to modify? | Planned change |
|---|---|---|---|---|---|
| Control Tower | `app/streamlit_app.py` | KPI cards, OTD trend, risk severity, attention table | `APP.VW_CONTROL_TOWER` | Yes - UI only | Put an evidence-backed `SHP-1002` Decision Brief first; retain KPIs below |
| Shipment Intelligence | `app/streamlit_app.py` | Shipment grain, risk components, event table, findings | `APP.VW_SHIPMENT_360`, `APP.VW_SHIPMENT_TIMELINE`, `APP.VW_EXCEPTION_DETAIL` | Yes - UI only | Add shipment header, journey, evidence-to-action trace, review status |
| Document Evidence | `app/streamlit_app.py` | Full comparison table and document health | `APP.VW_DOCUMENT_COMPARISON`, `APP.VW_SHIPMENT_360` | Yes - UI only | Add compact problem-first comparison and expandable technical evidence |
| OneTruth Copilot | `app/streamlit_app.py` | Contextual Cortex Agent question and raw payload | `APP.VERICARGO_AGENT` | Yes - UI only | Add trust-challenge prompts, structured response framing, review CTA |
| Human Review | `app/streamlit_app.py` | Proposal, confirmation, queue, transitions, audit table | `PROPOSE_REVIEW_CASE`, `CREATE_REVIEW_CASE`, `UPDATE_REVIEW_CASE`, queue/audit views | Yes - UI only | Strengthen action boundary, success state, lifecycle timeline, return navigation |
| Governance | `app/streamlit_app.py` | Governance status, written guardrails, audit table | `APP.VW_GOVERNANCE_STATUS`, `APP.VW_AUDIT_HISTORY` | Yes - UI only | Organize data health, semantic governance, AI guardrails, auditability, persona proof |

## Frozen Snowflake contracts

| Component | Current file | Current status | Backend dependency | Safe to modify? | Planned change |
|---|---|---|---|---|---|
| Raw entities and stages | `snowflake/01_raw_tables.sql` | Working | Synthetic CSV/PDF fixtures | No | None |
| Curated marts and KPIs | `snowflake/03_marts.sql` | Working | Dynamic tables | No | None |
| Document processing | `snowflake/04_documents.sql` | Working parse, extract, evidence and comparison flow | `AI_PARSE_DOCUMENT`, `AI_EXTRACT` | No | None |
| Risk features and policy | `snowflake/04b_snowpark_features.sql` | Working deterministic component scores | Snowpark procedure and policy table | No | None |
| Native semantic view | `snowflake/05_semantic.sql` | Deployed with entities, relationships, metrics and verified questions | Curated/analytics objects | No | None |
| Review and agent objects | `snowflake/06_actions_and_agent.sql` | Deployed Search, Agent and three guarded procedures | Semantic view, Search corpus, review tables | No | None |
| Application views | `snowflake/06b_application_views.sql` | Eight stable UI contracts | Curated, analytics and review objects | No | None |
| Scheduled digest | `snowflake/07_automation.sql` | Working Snowflake Task fallback | Exception and review tables | No | None |

## Governed truth that must not change

- Canonical metrics: on-time delivery rate, fill rate, days of inventory, and USD landed
  cost.
- `SHP-1002` operational fixture: Port Klang (`MYPKG`) to Ho Chi Minh City (`VNSGN`),
  promised 2026-09-09, delivered 2026-09-10.
- `SHP-1002` document fixture: SI and Draft BL exist and produce `MISMATCH` /
  `FIELD_MISMATCH`.
- Expected visible document differences: destination (`VNSGN` vs `THLCH`) and gross
  weight (`8000` vs `7800` after normalization).
- Expected matches include origin (`MYPKG`) and container count (`1`).
- Exceptions: `DOC-SHP-1002` and `DELIVERY-SHP-1002`.
- Agent: governed analytics through `SUPPLY_CHAIN_SEMANTIC_VIEW`, document evidence through
  `CURATED.DOCUMENT_SEARCH`, and non-mutating proposals through `PROPOSE_REVIEW_CASE`.
- Mutations: only `CREATE_REVIEW_CASE` after explicit confirmation and
  `UPDATE_REVIEW_CASE` through legal transitions.
- Audit: `APP.REVIEW_AUDIT_EVENTS` is append-only from the application workflow.

## Safe modification boundary

The presentation pass may modify `app/streamlit_app.py`, `app/components.py`, add UI-pure
helpers/tests, and update documentation. It must not change Snowflake schemas, semantic
definitions, Agent tools, stored-procedure signatures, review/audit semantics, synthetic
data, or canonical metric logic.
