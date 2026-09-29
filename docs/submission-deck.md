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
- `VERICARGO_AGENT`: Cortex Analyst + Cortex Search + non-mutating review proposal
- Six connected Streamlit pages with persistent shipment context and guarded review writes

## Slide 5 - One metric, three personas

Show the three persona prompts and their actual responses side by side. All must resolve to
the same governed on-time-delivery definition, grain, filters, and window.

Fixture target: `60.0%` (3 on-time shipments / 5 delivered shipments).

Evidence query IDs:

- Operations: `01c76057-3203-7366-0018-686a0008153e`
- Procurement: `01c76057-3203-73c7-0018-686a000833be`
- Planning: `01c76058-3203-7357-0018-686a000804be`

Each returned 60% (3 on time / 5 delivered), shipment grain, and the same governed
all-delivered window. Add the three final screenshots during recording.

## Slide 6 - Evidence-backed exception and action

Show `SHP-1002`: the SI and Draft BL disagree, and the response cites both filenames and
confidence. Then show missing, corrupted, and ambiguous documents routing to review. An
unconfirmed action is blocked; a confirmed action records case ID, shipment, actor,
timestamp, reason, severity, source question, and confirmation.

Evidence:

- Combined agent answer: `01c76058-3203-73c7-0018-686a000833d2`
- Unconfirmed action blocked: `01c75ef1-3203-7356-0018-686a0006f18a`
- Confirmed workflow and duplicate protection: `01c76060-3203-73c7-0018-686a00083422`
- Linked exceptions: `01c76061-3203-7366-0018-686a000815da`
- Three-event audit trail: `01c76061-3203-7357-0018-686a000804e6`
- Resolved acceptance case: `RC-000201`

## Slide 7 - CoCo across the full lifecycle

| Phase | Evidence |
|---|---|
| Planning | Session `4ce0a356-74a1-401e-aa0b-998211484090`; approved plan in `.cortex/plans/plan_2026-09-27_1231.md` |
| Development | Session `b46b47a1-4baa-44dc-aeb8-0091f741b386`; Korean port-alias parity fix; checkpoint commit `1b248fe` |
| Execution | Sessions `b46b47a1-4baa-44dc-aeb8-0091f741b386` and `fb9d4d4d-ec13-4d7d-bc9b-426c5cfa14d4`; deployed app FQN `VERICARGO_ONETRUTH.APP.VERICARGO_ONETRUTH_APP` |
| Testing and repair | 23/23 local tests; 28/28 Snowflake checks; failed `01c75ef2-3203-736a-0018-686a0007323a`, fixed and verified `01c75ef6-3203-7356-0018-686a0006f1ca` |
| Ingenuity | Governance skill invoked in session `fb9d4d4d-ec13-4d7d-bc9b-426c5cfa14d4`; fallback Task run `01c762ea-3203-7595-0018-686a000af0c6` |

Do not use the initial Codex scaffold as CoCo evidence.

## Slide 8 - Provenance, privacy, and outcome

- All submitted business data and documents are synthetic and team-authored.
- The prior Chrome extension is disclosed team-owned background IP and is outside the new
  runtime; the Snowflake data, ontology, semantic, agent, app, and evidence layers are new.
- VeriCargo OneTruth turns fragmented operational data into consistent answers, cited
  exceptions, and controlled human action.

Organizer eligibility/reuse confirmation: pending external written confirmation; do not
remove this warning or submit as confirmed until the organizer reply is received.
