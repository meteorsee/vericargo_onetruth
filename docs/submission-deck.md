# Submission deck copy

Use this as the English copy deck. Replace every bracketed evidence field only with a
real link, session ID, query ID, screenshot, or result.

## Slide 1 - VeriCargo OneTruth

**Governed Supply Chain Ontology and Exception Copilot**

One shared definition of delivery, fulfilment, inventory, cost, and document truth for
planning, procurement, and logistics.

## Slide 2 - The operational problem

- ERP, logistics, supplier, inventory, cost, and shipping-document data disagree.
- Teams use different metric definitions and cannot trace answers to source evidence.
- Document failures and ambiguity are often converted into guesses instead of review work.

## Slide 3 - One governed ontology

Show the architecture diagram from `docs/architecture.md` and the relationship path:

`Supplier -> Part -> Plant -> Order -> Shipment -> Container / Port -> Customer`

Documents and review cases attach to shipments. The four canonical metrics are on-time
delivery rate, fill rate, days of inventory, and USD landed cost.

## Slide 4 - Snowflake-native implementation

- Internal stages and raw tables for structured CSV and synthetic SI / Draft BL PDFs
- Dynamic tables for shipment, order-line, inventory, and cost marts
- Snowpark Python transformation for joined delivery/document risk features
- `AI_PARSE_DOCUMENT` plus scored `AI_EXTRACT`, deterministic comparison, and safe failure
- Native `SUPPLY_CHAIN_SEMANTIC_VIEW` with synonyms and verified questions
- `VERICARGO_AGENT`: Cortex Analyst + Cortex Search + guarded stored-procedure action
- Streamlit KPI, copilot, evidence, and human-review experience

## Slide 5 - One metric, three personas

Show the three persona prompts and their actual responses side by side. All must resolve to
the same governed on-time-delivery definition, grain, filters, and window.

Fixture target: `60.0%` (3 on-time shipments / 5 delivered shipments).

Evidence: [INSERT SCREENSHOT AND QUERY IDs]

## Slide 6 - Evidence-backed exception and action

Show `SHP-1002`: the SI and Draft BL disagree, and the response cites both filenames and
confidence. Then show missing, corrupted, and ambiguous documents routing to review. An
unconfirmed action is blocked; a confirmed action records case ID, shipment, actor,
timestamp, reason, severity, source question, and confirmation.

Evidence: [INSERT SCREENSHOT AND QUERY IDs]

## Slide 7 - CoCo across the full lifecycle

| Phase | Evidence |
|---|---|
| Planning | [SESSION ID, APPROVED PLAN, SCREENSHOT] |
| Development | [SESSION ID, COMMIT(S), SCREENSHOT] |
| Execution | [SESSION ID, DEPLOYMENT QUERY IDs, APP URL] |
| Testing and repair | [SESSION ID, FAILED-THEN-FIXED CASE, TEST RESULTS] |
| Ingenuity | [SKILL INVOCATION, AUTOMATION RUN/THREAD ID] |

Do not use the initial Codex scaffold as CoCo evidence.

## Slide 8 - Provenance, privacy, and outcome

- All submitted business data and documents are synthetic and team-authored.
- The prior Chrome extension is disclosed team-owned background IP and is outside the new
  runtime; the Snowflake data, ontology, semantic, agent, app, and evidence layers are new.
- VeriCargo OneTruth turns fragmented operational data into consistent answers, cited
  exceptions, and controlled human action.

Organizer eligibility/reuse confirmation: [INSERT WRITTEN CONFIRMATION]
