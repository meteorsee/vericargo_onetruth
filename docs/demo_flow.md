# Decision-first demonstration flow

## Demo preparation

1. Use a clean browser session and open the Snowflake Streamlit application.
2. Confirm the warehouse and Agent are available.
3. Resolve any active `SHP-1002` rehearsal case through the legal UI transitions. Do not
   truncate review or audit tables. Resolved cases do not block a new demonstration case.
4. Refresh the app and keep `SHP-1002` selected.
5. Pre-run the three genuine Agent trust questions and retain screenshots in case the live
   model is slow. Do not substitute a screenshot for untested behaviour.

## Complete judge journey

1. Open **Control Tower**.
2. Show the hero: “One shipment. Two destinations. One governed truth.”
3. In the Decision Brief show one-day late delivery, the SI and Draft BL destination and
   weight contradiction, risk, linked findings and the confirmation boundary.
4. Click **Investigate shipment**.
5. Confirm `SHP-1002` persists and show commercial context, route, actual events, risk
   contributors, governed findings and the evidence-to-action trace.
6. Click **Inspect evidence**.
7. Show destination and gross-weight mismatches first. Show matching origin and container
   count below them.
8. Select a mismatching field and show raw value, normalized value, confidence, source
   filename, nullable source location and processing status side by side.
9. Click **Ask OneTruth about this evidence**.
10. Run the grounded question and confirm the answer includes operational delay, document
    discrepancy, and both filenames.
11. Run the action-guardrail question and confirm no case was written.
12. If time permits, run the unknown carbon/`SHP-9999` question and confirm no value is
    fabricated.
13. Open **Human Review** and validate the two-exception proposal.
14. Show the read-only confirmation boundary. Click **Cancel · write nothing** and confirm
    the case count does not change.
15. Validate again and click **Confirm & create one case**.
16. Show case ID, shipment, two links, `PENDING`, actor, timestamp and initial audit event.
17. Move the case to `IN_REVIEW`, then `RESOLVED` with a resolution note.
18. Show the three-event lifecycle and return to Shipment Intelligence.
19. Open **Governance** and show persona consistency, Agent boundaries, data health and
    recent audit evidence.

## Safe repeatability

There is deliberately no destructive “reset demo” button. To prepare another run, finish
the active case through `PENDING -> IN_REVIEW -> RESOLVED`. The duplicate guardrail applies
only to active cases, so a new confirmed case can then be created without deleting history.

