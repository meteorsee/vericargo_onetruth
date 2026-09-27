# Background IP and Hackathon Contribution

## Pre-existing team-owned work

The team previously built the VeriCargo Gmail Shipping Assistant, a Chrome extension and
Cloud Run service for Gmail triage and Shipping Instruction versus Draft Bill of Lading
verification. It uses Google Cloud, Firestore, Gmail APIs, Gemini, JavaScript, and Node.js.

That repository, its existing deployed services, its Chrome Web Store package, and its
pre-hackathon commit history are background IP. They are not included in this repository
and must not be presented as work produced by Snowflake CoCo.

## New work in this entry

VeriCargo OneTruth is a separate Snowflake-native implementation containing a new:

- synthetic multi-domain supply-chain dataset;
- ontology and governed metric definitions;
- Snowflake ingestion and transformation pipeline;
- native semantic view and verified questions;
- Cortex Search document corpus and Cortex Agent;
- guarded review-case procedure;
- Streamlit application;
- CoCo skill, automation prompt, validation suite, and evidence process.

The seven shipping fields and deterministic normalization concepts are derived from the
team's domain experience. Their Python and Snowflake implementations in this repository
are new. No production Gmail data, credentials, customer records, or confidential
documents are included.

## Disclosure for judges

The submission deck and README must distinguish the background product from the new
hackathon contribution. If the prior extension is shown, label it “pre-existing operational
surface” and make the Snowflake architecture the judged end-to-end system.

