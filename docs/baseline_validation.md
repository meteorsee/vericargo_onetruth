# Baseline validation before the decision-first UI pass

Status date: 2026-09-30 (Asia/Kuala_Lumpur)

The baseline was captured before editing the Streamlit presentation. No Snowflake object,
semantic definition, Agent tool, stored procedure, fixture, or canonical metric changed.

## Executed locally

| Check | Result | Evidence |
|---|---|---|
| Existing unit/contract suite | PASS, 23/23 | `.venv/Scripts/python -m unittest discover -s tests -v` |
| Streamlit Python compilation | PASS | `python -m py_compile app/components.py app/services.py app/streamlit_app.py` |
| Repository secret scan | PASS, 84 tracked and unignored files | `scripts/scan_secrets.ps1` |
| Deployed Streamlit execution | PASS | `snow streamlit execute VERICARGO_ONETRUTH.APP.VERICARGO_ONETRUTH_APP` |

## Retained Snowflake acceptance baseline

The latest completed read-only Snowflake acceptance session remains CoCo session
`fb9d4d4d-ec13-4d7d-bc9b-426c5cfa14d4`:

- 28/28 validation checks passed.
- Canonical KPI query: `01c76055-3203-73c7-0018-686a000833b6`.
- Document outcome query: `01c76055-3203-73ca-0018-686a0008561a`.
- Application-view and `SHP-1002` query: `01c76055-3203-7357-0018-686a000804b2`.
- `SHP-1002` combined Agent response:
  `01c76058-3203-73c7-0018-686a000833d2`.
- Review workflow: `01c76060-3203-73c7-0018-686a00083422`.
- Linked exceptions: `01c76061-3203-7366-0018-686a000815da`.
- Three-event audit history: `01c76061-3203-7357-0018-686a000804e6`.

Expected governed values at this baseline:

- OTD is 60.0%: three of five delivered shipments were on time.
- `SHP-1002` was promised on 2026-09-09 and delivered on 2026-09-10.
- Its document comparison contains destination and gross-weight mismatches and matching
  origin and container-count values.
- The Agent explains both operational and document findings and cites
  `doc-shp-1002-si.pdf` and `doc-shp-1002-bl.pdf`.
- Confirmed case creation links `DOC-SHP-1002` and `DELIVERY-SHP-1002`; the accepted case
  `RC-000201` reached `RESOLVED` with three audit events.

## Environment note

A fresh read-only Snow CLI query attempted during this baseline could not complete because
the external-browser OAuth redirect was not returned before timeout. This was an
authentication-session limitation, not a SQL or application failure. No database write was
attempted. Post-change live queries remain pending until an interactive Snowflake login is
available; the local regression suite and deployed Streamlit execution are not blocked.
