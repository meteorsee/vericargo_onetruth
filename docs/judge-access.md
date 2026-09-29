# Judge access runbook

VeriCargo OneTruth is intentionally Snowflake-native and is not published as a public
Google-hosted application. Do not place passwords, OAuth tokens, account locators, private
URLs, or invitation details in this repository.

## Application

1. Sign in to the hackathon Snowflake account using the access supplied privately by the
   team or organizer.
2. Select the role granted access to the submission and a usable warehouse.
3. In Snowsight, open **Projects**, then **Streamlit**.
4. Open **VeriCargo OneTruth**, whose object name is
   `VERICARGO_ONETRUTH.APP.VERICARGO_ONETRUTH_APP`.
5. Start with shipment `SHP-1002` and follow the flow in `docs/demo-script.md`.

The application uses warehouse runtime `SYSTEM$WAREHOUSE_RUNTIME` and query warehouse
`VERICARGO_WH`. Its package specification pins Streamlit 1.49.1.

## Repository orientation

- `README.md`: product, prerequisites, deployment, and demo entry point.
- `docs/architecture.md`: system and data-flow architecture.
- `COCO_USAGE.md`: genuine CoCo sessions and Snowflake query IDs.
- `docs/test-results.md`: acceptance status and known limitations.
- `BACKGROUND_IP.md`: boundary from the pre-existing Chrome extension.
- `DATASETS.md`: synthetic-data and licence inventory.

## Access-owner checklist

Before sharing privately with judges:

- confirm every judge can see the repository;
- confirm the judge role can use `VERICARGO_WH` and open the Streamlit object;
- open the app from a clean/non-owner session;
- verify all six pages and the `SHP-1002` evidence flow;
- share credentials or invitations only through the organizer-approved private channel;
- record the test date and tester outside the public repository.

Judge-role grants are account-specific and deliberately not hard-coded into the submission
SQL. The owner must complete this checklist in the actual hackathon account.

