# Acceptance test results

Status date: 2026-09-29 (Asia/Kuala_Lumpur)

This report records only executed checks. Query IDs are Snowflake evidence; the associated
CoCo transcript is session `fb9d4d4d-ec13-4d7d-bc9b-426c5cfa14d4`.

## Verified

| Area | Result | Evidence |
|---|---|---|
| Local unit tests | PASS, 23/23 | `python -m unittest discover -s tests -v` |
| Repository secret scan | PASS, 83 tracked and unignored files scanned | `scripts/scan_secrets.ps1` |
| Snowflake validation | PASS, 28/28 | Query IDs listed in `COCO_USAGE.md` |
| Persona OTD consistency | PASS | 60%, 3 of 5 delivered, shipment grain, same governed window |
| `SHP-1002` combined answer | PASS | `01c76058-3203-73c7-0018-686a000833d2` |
| Unsupported metric / unknown shipment | PASS, refused to invent data | `01c7605e-3203-7366-0018-686a00081596` |
| Review lifecycle | PASS | `01c76060-3203-73c7-0018-686a00083422` |
| Review exception links | PASS, 2 | `01c76061-3203-7366-0018-686a000815da` |
| Review audit events | PASS, 3 | `01c76061-3203-7357-0018-686a000804e6` |
| Streamlit headless execution | PASS | App FQN `VERICARGO_ONETRUTH.APP.VERICARGO_ONETRUTH_APP` |
| Digest fallback | PASS | Task query `01c762ea-3203-7595-0018-686a000af0c6` |

The accepted workflow case is `RC-000201`. It linked `DOC-SHP-1002` and
`DELIVERY-SHP-1002`, rejected a duplicate active case, transitioned through `PENDING`,
`IN_REVIEW`, and `RESOLVED`, and stored the required resolution note.

The agent cited `doc-shp-1002-si.pdf` and `doc-shp-1002-bl.pdf`. The fallback digest
reported 7 open exceptions, 3 high/critical, and 0 pending human-review cases.

## Honest failed-then-fixed evidence

- The SQL port normalizer initially returned `BUSAN` instead of canonical `KRPUS` for a
  Korean alias (`01c75ef2-3203-736a-0018-686a0007323a`).
- CoCo added the missing aliases and recreated the function
  (`01c75ef6-3203-7356-0018-686a0006f1c2`).
- Alias validation then passed (`01c75ef6-3203-7356-0018-686a0006f1ca`) and all six
  document outcomes remained correct (`01c75ef6-3203-736a-0018-686a00073266`).
- During workflow evidence inspection, CoCo tried two incorrect column names, read the
  actual table contracts, corrected the queries, and retrieved the final case and audit
  evidence. No production code or stored data required repair.

## Environment limitation and fallback

Hosted CoCo Automations could not be confirmed because the Automations endpoint was
unreachable from the current trial environment. The repository did not enable the CLI's
experimental override. The declared Snowflake Task fallback is active and its manual run
succeeded.

## Still requires human/external verification

- Open all six pages in a clean browser session and complete the timed UI rehearsal.
- Verify the app with the actual judge role/account; headless owner execution alone does
  not prove judge authorization.
- Perform a clean-database redeployment only in a disposable database/account. The current
  helper truncates tables, so it was not run against the validated live evidence database.
- Record screenshots/video and obtain organizer eligibility/background-IP confirmation.

