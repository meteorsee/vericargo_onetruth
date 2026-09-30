# Decision-first UI regression results

Status date: 2026-09-30 (Asia/Kuala_Lumpur)

## Result

- PASS: 30/30 local unit, contract, UI and Streamlit smoke tests.
- PASS: all six pages render against application-view-shaped data with no visible
  Streamlit exception.
- PASS: Python compilation for `components.py`, `services.py` and `streamlit_app.py`.
- PASS: repository secret scan across 92 tracked and unignored files.
- PASS: `git diff --check`.
- NO CHANGE: Snowflake SQL, schema, semantic view, Agent tools, procedures, fixtures,
  canonical metrics and review/audit contracts.

## Added regression coverage

`tests/test_ui_contract.py` verifies:

- shared shipment/evidence/review state and all six routes;
- the Decision Brief appears before KPI analytics;
- destination, weight and 60% are read from governed data instead of hard-coded UI facts;
- compact evidence and genuine trust-prompt UX exists;
- the explicit confirmation/audit boundary remains visible;
- all eight application views and three procedures remain the service contracts.

`tests/test_streamlit_smoke.py` supplies contract-shaped, synthetic in-memory frames and
renders Control Tower, Shipment Intelligence, Document Evidence, OneTruth Copilot, Human
Review and Governance through Streamlit's official test harness.

The first smoke attempt failed because the test runner did not add `app/` to its module
search path. The harness was corrected to mirror Snowflake's artifact directory, after
which all six pages passed. No application or backend defect was hidden by this repair.

## Live environment status

The existing deployed application passed `snow streamlit execute` before this UI pass. A
Streamlit-only replacement deployment was attempted after the pass, but external-browser
OAuth did not return its callback before timeout. The CLI stopped before deployment; no
Snowflake object or data was changed.

The updated artifact therefore still requires:

1. interactive OAuth authentication;
2. `snow streamlit deploy --replace --prune` from `app/`;
3. `snow streamlit execute`;
4. a clean-browser, all-six-page rehearsal;
5. the three genuine Agent prompts and confirmed/cancelled workflow test.

