---
name: vericargo-supply-chain-governance
description: Validate or extend the VeriCargo OneTruth supply-chain ontology, canonical metrics, semantic view, verified queries, and exception-routing guardrails. Use for changes to supplier, part, plant, order, shipment, inventory, landed-cost, or SI/BL analytics. Do not use for unrelated infrastructure or visual-only edits.
---

# VeriCargo supply-chain governance

Preserve one governed definition for every business concept. Before editing, inspect the
physical schema, curated marts, semantic view, relevant verified queries, and SQL
validation tests together.

## Invariants

- Keep the relationship path traceable from supplier and part through plant, order,
  shipment, port, and customer. Use bridge entities where the relationship is many-to-many.
- On-time delivery rate is on-time delivered shipments divided by delivered shipments.
  Exclude undelivered shipments from both numerator and denominator.
- Fill rate is `SUM(LEAST(shipped_qty, ordered_qty)) / SUM(ordered_qty)` so over-shipment
  cannot inflate the result.
- Days of inventory uses the latest on-hand snapshot and trailing-30-day average daily
  shipped quantity. Return null when demand is zero.
- Landed cost is product, freight, duty, insurance, and handling cost in USD.
- Missing, ambiguous, unreadable, or low-confidence document values remain unresolved and
  route to Human Review. Never synthesize a value to make documents agree.
- A state-changing review action requires explicit confirmation, a known shipment,
  validated severity, and an audit record.

## Workflow

1. State which entities, relationships, metrics, questions, or guardrails are affected.
2. Check for fanout, grain changes, denominator drift, ambiguous relationship paths, and
   stale verified queries.
3. Make the smallest coherent update across transformations, semantic definitions,
   application labels, and tests.
4. Run local tests and Snowflake validation queries. Compare equivalent persona questions
   and require identical results.
5. Report actual evidence: changed files, queries run, query IDs, failures, fixes, and any
   untested account-dependent behavior.

Do not mark a change complete when Snowflake execution was skipped. Label it
`locally validated; Snowflake validation pending` instead.

