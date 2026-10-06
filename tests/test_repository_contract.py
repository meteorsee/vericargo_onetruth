from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class RepositoryContractTests(unittest.TestCase):
    def test_ordered_snowflake_deployment_is_complete(self) -> None:
        expected = {
            "00_bootstrap.sql",
            "01_raw_tables.sql",
            "02_load.sql",
            "03_marts.sql",
            "04_documents.sql",
            "04b_snowpark_features.sql",
            "05_semantic.sql",
            "06_actions_and_agent.sql",
            "06b_application_views.sql",
            "07_automation.sql",
            "08_validation.sql",
            "09_agent_smoke_tests.sql",
            "10_workflow_smoke_tests.sql",
        }
        actual = {path.name for path in (ROOT / "snowflake").glob("*.sql")}
        self.assertEqual(expected, actual)

    def test_governance_objects_and_guardrails_are_declared(self) -> None:
        semantic_sql = (ROOT / "snowflake" / "05_semantic.sql").read_text()
        action_sql = (ROOT / "snowflake" / "06_actions_and_agent.sql").read_text()
        bootstrap_sql = (ROOT / "snowflake" / "00_bootstrap.sql").read_text()
        document_sql = (ROOT / "snowflake" / "04_documents.sql").read_text()
        snowpark_sql = (ROOT / "snowflake" / "04b_snowpark_features.sql").read_text()
        application_sql = (ROOT / "snowflake" / "06b_application_views.sql").read_text()
        automation_sql = (ROOT / "snowflake" / "07_automation.sql").read_text()

        for metric in (
            "on_time_delivery_rate",
            "fill_rate",
            "days_of_inventory",
            "landed_cost",
        ):
            self.assertIn(metric, semantic_sql)
        self.assertIn("P_CONFIRMED", action_sql)
        self.assertIn("CURRENT_USER()", action_sql)
        self.assertIn("AI_PARSE_DOCUMENT", document_sql)
        self.assertIn("AI_EXTRACT", document_sql)
        self.assertNotIn("CREATE OR REPLACE CORTEX SEARCH SERVICE", action_sql)
        self.assertIn("documents AS CURATED.DOCUMENT_FIELDS", semantic_sql)
        self.assertIn("documents.relative_path", semantic_sql)
        self.assertIn("DOCUMENT_INTAKE_STAGE", bootstrap_sql)
        self.assertIn("RECORD_DOCUMENT_INTAKE", action_sql)
        self.assertIn("DOCUMENT_INTAKE_EVENTS", action_sql)
        self.assertNotIn("ADD COLUMN IF NOT EXISTS VIEWER_IDENTITY", action_sql)
        self.assertIn("clean_viewer_identity := COALESCE", action_sql)
        self.assertIn(":clean_viewer_identity,", action_sql)
        self.assertNotIn(
            "COALESCE(NULLIF(LEFT(TRIM(:P_VIEWER_IDENTITY)",
            action_sql,
        )
        self.assertIn("snowflake.snowpark", snowpark_sql)
        self.assertIn("SHIPMENT_RISK_FEATURES", snowpark_sql)
        for view in (
            "VW_CONTROL_TOWER",
            "VW_SHIPMENT_360",
            "VW_SHIPMENT_TIMELINE",
            "VW_DOCUMENT_COMPARISON",
            "VW_EXCEPTION_DETAIL",
            "VW_REVIEW_QUEUE",
            "VW_AUDIT_HISTORY",
            "VW_GOVERNANCE_STATUS",
            "VW_DOCUMENT_INTAKE",
        ):
            self.assertIn(view, application_sql)
        self.assertIn("VW_AUTOMATION_STATUS", automation_sql)
        self.assertIn("attention_items", automation_sql)

    def test_hackathon_repo_does_not_import_extension_runtime(self) -> None:
        source_files = list((ROOT / "src").rglob("*.py")) + list((ROOT / "app").rglob("*.py"))
        for path in source_files:
            self.assertNotIn("vericargo_extension", path.read_text(encoding="utf-8").lower())

    def test_embedded_snowpark_handler_compiles(self) -> None:
        sql = (ROOT / "snowflake" / "04b_snowpark_features.sql").read_text()
        handler = sql.split("AS\n$$\n", maxsplit=1)[1].rsplit("\n$$;", maxsplit=1)[0]
        compile(handler, "04b_snowpark_features.sql::<handler>", "exec")


if __name__ == "__main__":
    unittest.main()
