# Submission and go-live checklist

Unchecked items are genuine blockers or pending external actions; do not relabel them as
complete without evidence.

## Hard gates - September 27

- [ ] Register every team member before September 30, 2026.
- [ ] Send `ORGANIZER_EMAIL.md` to `cococlihackgcc-support@hack2skill.com`.
- [ ] Receive written Malaysia GCC eligibility confirmation.
- [ ] Receive written background-IP / prior-submission reuse confirmation.
- [ ] Obtain the dedicated hackathon Snowflake account and connection details.
- [x] Install CoCo CLI locally (`Cortex Code v1.1.87`).
- [x] Install Snowflake CLI in the project `.venv` (`3.28.0`).
- [x] Initialize this folder as a separate Git repository.

Stop the submission if Malaysian participation is ruled ineligible. If reuse is rejected,
remove the VeriCargo name and prior UI/assets; retain only general logistics knowledge and
the independently implemented Snowflake solution.

## CoCo lifecycle

- [x] Start standard-mode CoCo with `--plan` from a clean baseline.
- [x] Record and approve the architecture plan in CoCo.
- [x] Invoke `vericargo-supply-chain-governance` and retain the transcript.
- [x] Have CoCo review and materially revise the scaffold.
- [x] Run generation, deployment, and validation through CoCo.
- [x] Capture one real failed-then-fixed example.
- [x] Run the four agent smoke tests and retain response/query IDs.
- [x] Attempt hosted CoCo automation and record the unavailable endpoint; execute and
  inspect the declared Snowflake Task fallback.
- [x] Complete every required field in `COCO_USAGE.md` with real evidence; cross-surface
  demonstration is explicitly optional and not run.

## Product acceptance

- [ ] Snowflake deployment completes from a clean database.
- [x] All FK and duplicate-key checks pass.
- [x] Four governed metrics match independent fixtures.
- [x] Three persona versions of OTD return the same definition and value.
- [x] Match, mismatch, missing, unreadable, ambiguous, and low-confidence cases route safely.
- [x] Document answers cite source filenames.
- [x] Unconfirmed and unknown-shipment paths fail safely; local guardrail tests and the
  Snowflake blocked-write check pass.
- [x] Confirmed action records the complete audit trail.
- [x] All six decision-first pages render in the local Streamlit smoke harness against the
  stable application contracts.
- [ ] Streamlit completes staged-file -> chat -> review-case flow.
- [x] Secrets scan is clean and only synthetic data is committed.

## Submission package - internal deadline October 4, 8:00 PM MYT

- [x] English README and setup instructions reviewed.
- [ ] Repository access granted to judges.
- [ ] Working Streamlit URL tested with judge permissions.
- [ ] Deck completed from `docs/submission-deck.md`.
- [ ] Demo recorded and timed to four minutes.
- [x] `BACKGROUND_IP.md` and `DATASETS.md` included in the submission.
- [ ] Final commit/tag created before the internal deadline.
- [ ] Submission form confirmation saved outside the repository.
