# VeriCargo OneTruth 4K architecture-diagram prompt

Create a polished, presentation-ready enterprise architecture infographic for a Snowflake hackathon project.

## Output and composition

- Exact target canvas: 3840 x 2400 pixels, landscape 16:10.
- Full-bleed dark navy background, generous margins, crisp flat-vector styling, high contrast, readable at full-screen and when placed on a presentation slide.
- Title at top: "VeriCargo OneTruth — Governed Evidence-to-Action Architecture"
- Subtitle: "From conflicting supply-chain data to one governed decision"
- Use four horizontal swimlanes with clear lane titles, a left-to-right flow, orthogonal arrows, and no crossing arrows.
- Every numbered stage must be connected. Put the stage number in a highly visible circular badge: 01 through 14.
- Use compact but legible sans-serif text. Preserve the exact spelling of the labels below. No logos, no watermark, no decorative stock imagery.
- Color system: source/cyan, transformation/blue, governance/purple, intelligence/teal, action/amber, audit/green. Use the same color consistently for each category.
- Make boxes large enough for their detail text. Use small simple line icons only as secondary cues.
- All arrows must have arrowheads. Solid arrows mean runtime data/action flow. Dashed orange arrows mean CoCo build-time activity.
- Clearly distinguish current runtime from future integrations.

## Top build-time band

A thin orange dashed band across the width titled:

"CoCo DELIVERY LIFECYCLE — BUILD-TIME, NOT RUNTIME"

Inside the band, connected steps:

"PLAN → DEVELOP → EXECUTE → TEST & REPAIR → GOVERNANCE SKILL → AUTOMATION EVIDENCE"

Use dashed downward connectors from this band to stages 03, 04, 05, 08, 10, 11, and 14.

## Swimlane 1 — Data sources and ingestion

Stage 01 — "Synthetic Structured Sources"

- "ERP: suppliers, parts, plants, customers"
- "Orders and order lines"
- "Shipments, containers, ports, events"
- "Inventory snapshots"
- "Landed-cost components — USD"

Stage 02 — "Synthetic Document Sources"

- "Shipping Instructions"
- "Draft Bills of Lading"
- "Match, mismatch, missing, unreadable"
- "Ambiguous and low-confidence cases"

Connect both Stage 01 and Stage 02 into Stage 03.

Stage 03 — "Snowflake Ingestion & RAW"

- "Internal CSV and PDF stages"
- "RAW tables"
- "Referentially consistent shipment IDs"
- "Synthetic data only"

## Swimlane 2 — Curation, document intelligence and risk

From Stage 03 split into two parallel branches.

Stage 04 — "Governed Transformations"

- "Dynamic tables"
- "Shipment and order-line marts"
- "Inventory and cost marts"
- "Canonical USD landed cost"

Stage 05 — "Document Intelligence"

- "AI_PARSE_DOCUMENT"
- "AI_EXTRACT"
- "Field evidence: raw + normalized value"
- "Confidence, filename, location, errors"

Connect Stage 04 and Stage 05 to Stage 06.

Stage 06 — "Deterministic Comparison & Exceptions"

- "Port, container-count and weight rules"
- "MATCH • MISMATCH • MISSING"
- "UNRESOLVED • NOT_APPLICABLE"
- "One operational + document exception contract"

Connect Stage 04 and Stage 06 into Stage 07.

Stage 07 — "Snowpark Risk & Application Views"

- "Delivery • document • inventory"
- "Cost • data-quality components"
- "Overall risk: 0–100 + severity"
- "Stable APP.VW_* contracts"

## Swimlane 3 — Governed intelligence

Stage 08 — "Semantic Governance"

- "SUPPLY_CHAIN_SEMANTIC_VIEW"
- "Supplier → Part → Plant → Order"
- "Shipment → Container / Port → Customer"
- "OTD • fill rate • days inventory • landed cost"

Stage 09 — "Evidence Retrieval"

- "DOCUMENT_SEARCH"
- "Shipment-scoped document corpus"
- "Filename and source metadata"
- "Parsed content with evidence"

Connect Stage 07 to Stage 08. Connect Stage 06 to Stage 09. Connect Stage 08 and Stage 09 into Stage 10.

Stage 10 — "VERICARGO_AGENT"

- "Cortex Analyst + Cortex Search"
- "PROPOSE_REVIEW_CASE — read only"
- "Grounded answer + citations + warnings"
- "Never claims an unconfirmed write"

## Swimlane 4 — Decision experience and controlled action

Connect Stage 10 into Stage 11.

Stage 11 — "Six-Page Streamlit Decision Experience"

- "Control Tower / Decision Brief"
- "Shipment Intelligence • Document Evidence"
- "OneTruth Copilot • Human Review • Governance"
- "Shared selected_shipment_id context"

Stage 12 — "Human Confirmation Boundary"

- "Validate proposal"
- "Cancel = zero writes"
- "Confirm = one intended mutation"
- "Human remains accountable"

Stage 13 — "Review Workflow"

- "CREATE_REVIEW_CASE"
- "Exception links + duplicate protection"
- "PENDING → IN_REVIEW"
- "RESOLVED / REJECTED with note"

Stage 14 — "Audit & Unattended Operations"

- "Append-only actor, time, reason, question"
- "Status-transition history"
- "DAILY_EXCEPTION_DIGEST task"
- "Safe CoCo automation fallback"

Connect Stage 11 → 12 → 13 → 14. Add a green feedback arrow from Stage 14 back to Stage 11 labelled "queue and audit refresh". Add a smaller feedback arrow from Stage 13 back to Stage 07 labelled "governed case status".

## Center highlight callout

Place a compact highlighted callout attached to stages 06, 10, and 13:

"SHP-1002 PROOF"

- "1 day late"
- "SI: VNSGN / 8,000 kg"
- "Draft BL: THLCH / 7,800 kg"
- "2 governed exceptions → confirmed review case → audit"

## Bottom governance-contract strip

Title: "GOVERNANCE CONTRACT"

Five evenly spaced checks:

- "One definition per KPI"
- "USD-only landed cost"
- "Every evidence answer cites a source"
- "Failed or ambiguous extraction stays unresolved"
- "Agent proposes • Human confirms • Every mutation is audited"

## Future boundary

At bottom-right, outside the current runtime boundary, show a subdued dashed grey box:

"FUTURE CONNECTORS — NOT IN CURRENT MVP"

"Gmail • Chrome extension • live ERP / TMS / WMS • carrier APIs"

Connect it with one dashed grey arrow toward Stage 03 labelled "future ingestion only".

Ensure all boxes, callouts, and bands are visibly connected or explicitly labelled as outside the current runtime. Prioritize logical clarity and accurate readable text over decoration.
