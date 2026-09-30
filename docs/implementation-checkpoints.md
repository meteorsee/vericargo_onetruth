# Decision-first implementation checkpoints

Status date: 2026-09-30 (Asia/Kuala_Lumpur)

| Phase | Status | Files / evidence | Backend contract changed? |
|---:|---|---|---|
| 0 Current-state audit | Complete | `docs/current_state_audit.md` | No |
| 1 Baseline | Complete | `docs/baseline_validation.md`; 23/23 pre-change tests | No |
| 2 Shared state | Complete | `app/streamlit_app.py`, `app/components.py` | No |
| 3 Reusable components | Complete, adapted to existing two-file organization | `app/components.py` | No |
| 4 Decision-first Control Tower | Complete locally | Hero, data-backed Decision Brief, KPIs and three useful charts | No |
| 5 Shipment Intelligence | Complete locally | Header, actual-event journey, risk and review state | No |
| 6 Evidence-to-action trace | Complete locally | Actual document, Agent-session, case and audit state | No |
| 7 Visual evidence | Complete locally | Problem-first comparison, selected-field inspector, technical expander | No |
| 8 Persona consistency | Complete locally | Governance page derives current value and 3-of-5 counts from Control Tower view | No |
| 9 Copilot UX | Complete locally | Context, three prompts, answer/findings/sources/action sections | No |
| 10 Trust validation | Partial live | Grounded and unknown-data checks retained; new unauthorized-action prompt awaits authenticated live rerun | No |
| 11 Confirmation climax | Complete locally | Read-only boundary, Cancel and Confirm presentation | No |
| 12 Success/audit presentation | Complete locally | Created-case summary and event timeline | No |
| 13 Governance cleanup | Complete locally | Data health, semantic governance, Agent guardrails, auditability | No |
| 14 CTA connectivity | Complete locally | Every core page has an onward or return action | No |
| 15 Empty/failure states | Implemented; manual live scenarios pending | Human messages plus progressive technical details | No |
| 16 Responsive/usability | Implemented in code; physical viewport review pending | Responsive CSS, three-column trace rows, problem-first tables | No |
| 17 Visual consistency | Complete locally | One text-and-symbol status system and consistent containers/buttons | No |
| 18 End-to-end test | Partial | Six-page AppTest PASS; live browser mutation journey pending OAuth deployment | No |
| 19 Automated regression | Complete locally | 30/30, compilation, secrets and diff checks | No |
| 20 Demo hardening | Documented | `docs/demo_flow.md`; no destructive reset | No |
| 21 Final demo script | Complete | `docs/demo-script.md` | No |
| 22 Documentation | Complete | Audit, baseline, UI/demo flow, regression and limitations | No |

## Current blocking condition

The updated Streamlit artifact has not replaced the deployed app because the Snowflake CLI
external-browser OAuth callback timed out before connecting. The attempted command stopped
before deployment and changed no Snowflake object. Complete the authenticated deployment,
live Agent trust question, full UI workflow, and physical viewport checks before declaring
the entire plan finished.
