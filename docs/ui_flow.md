# Connected UI flow

The Streamlit application is one connected investigation surface, not six independent
dashboards. `st.session_state.selected_shipment_id` carries the active shipment through
every page. `SHP-1002` is the default demonstration context.

```text
Control Tower / Decision Brief
        |
        +--> Shipment Intelligence
        |       |
        |       +--> Document Evidence
        |       +--> OneTruth Copilot
        |       +--> Human Review
        |
        +--> Document Evidence --> OneTruth Copilot --> Human Review
        |
        +--> OneTruth Copilot --> Human Review
                                   |
                                   +--> case lifecycle and audit
                                   +--> Shipment Intelligence
```

## Shared investigation state

| State | Purpose |
|---|---|
| `selected_shipment_id` | Active shipment across investigation, evidence, Copilot and review |
| `selected_exception_id` | Reserved selected finding context |
| `selected_document_field` | Field displayed in the side-by-side evidence inspector |
| `pending_review_action` | Validated proposal that has not been confirmed or written |
| `last_copilot_question` | Most recent genuine Agent request |
| `last_copilot_response` | Response retained for the current shipment session |
| `selected_case_id` | Review case displayed in the lifecycle and audit section |

Changing the active shipment clears pending proposal and selected evidence state. It does
not create, update, or delete a review case.

## Page contracts

| Page | Primary read contract | Primary action |
|---|---|---|
| Control Tower | `APP.VW_CONTROL_TOWER`, document comparison and exception views | Select a shipment and open investigation/evidence/Copilot |
| Shipment Intelligence | `APP.VW_SHIPMENT_360`, timeline, exceptions, review/audit views | Continue to evidence, Copilot or review |
| Document Evidence | `APP.VW_DOCUMENT_COMPARISON` | Inspect raw/normalized evidence, then ask or review |
| OneTruth Copilot | `APP.VERICARGO_AGENT` | Ask a real governed question; open review only through UI |
| Human Review | review queue, exceptions and audit views | Propose, cancel, explicitly confirm, transition and inspect audit |
| Governance | governance, Control Tower and audit views | Verify health, canonical metrics, boundaries and auditability |

## Action boundary

The Agent may call `PROPOSE_REVIEW_CASE`, which validates context without writing. The
application calls `CREATE_REVIEW_CASE` only after the user presses **Confirm & create one
case**. Cancel clears the pending proposal and performs no mutation.

