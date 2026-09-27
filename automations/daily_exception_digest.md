This is an unattended run. Complete it autonomously and do not ask follow-up questions.

Query `VERICARGO_ONETRUTH.ANALYTICS.SHIPMENT_EXCEPTIONS`,
`VERICARGO_ONETRUTH.CURATED.DOCUMENT_COMPARISON_SUMMARY`,
`VERICARGO_ONETRUTH.CURATED.DOCUMENT_FIELDS`, and
`VERICARGO_ONETRUTH.APP.REVIEW_CASES`. Validate that source data is fresh, count open
exceptions by type and severity, and identify critical or high-severity items. Produce a
concise Markdown digest containing shipment IDs, reasons, document outcomes, minimum
confidence, evidence paths, and pending case IDs.

This automation is read-only: do not create, update, or close review cases and do not
modify any Snowflake object. If data is stale, inaccessible, missing, ambiguous, unreadable,
or internally inconsistent, report the limitation and do not infer values. End with exactly
one status line: `STATUS: SUCCESS`, `STATUS: PARTIAL`, or `STATUS: FAILED`, followed by a
short reason when the status is not success.

