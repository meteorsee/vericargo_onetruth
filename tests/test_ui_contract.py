from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_SOURCE = (ROOT / "app" / "streamlit_app.py").read_text(encoding="utf-8")
COMPONENT_SOURCE = (ROOT / "app" / "components.py").read_text(encoding="utf-8")
SERVICE_SOURCE = (ROOT / "app" / "services.py").read_text(encoding="utf-8")


class DecisionFirstUiContractTests(unittest.TestCase):
    def test_connected_pages_and_shared_investigation_state_exist(self) -> None:
        for page in (
            "Control Tower",
            "Shipment Intelligence",
            "Document Evidence",
            "OneTruth Copilot",
            "Human Review",
            "Governance",
        ):
            self.assertIn(f'"{page}"', APP_SOURCE)
        for state_key in (
            "selected_shipment_id",
            "selected_exception_id",
            "selected_document_field",
            "pending_review_action",
            "last_copilot_question",
        ):
            self.assertIn(f'"{state_key}"', APP_SOURCE)

    def test_first_view_separates_portfolio_and_shipment_scope(self) -> None:
        self.assertIn("One shipment. Two destinations. One governed truth.", COMPONENT_SOURCE)
        self.assertIn("render_decision_brief", APP_SOURCE)
        self.assertIn("render_selected_shipment_preview", APP_SOURCE)
        self.assertIn("HOLD · correction required", COMPONENT_SOURCE)
        self.assertIn("CLEAR · documents aligned", COMPONENT_SOURCE)
        self.assertIn("UNRESOLVED · human check required", COMPONENT_SOURCE)
        self.assertLess(
            APP_SOURCE.index('st.subheader("Selected shipment preview")'),
            APP_SOURCE.index('st.subheader("Portfolio health")'),
        )
        control_page = APP_SOURCE.split("def control_tower_page()", 1)[1].split(
            "def shipment_page()", 1
        )[0]
        self.assertIn("render_selected_shipment_preview(", control_page)
        shipment_page = APP_SOURCE.split("def shipment_page()", 1)[1].split(
            "def evidence_page()", 1
        )[0]
        self.assertIn("render_decision_brief(", shipment_page)
        self.assertIn("show_investigate_action=False", shipment_page)

    def test_page_content_clears_fixed_snowflake_header(self) -> None:
        self.assertIn(".block-container {padding-top: 3rem", APP_SOURCE)
        self.assertIn("padding-top: 3.25rem", APP_SOURCE)
        self.assertNotIn(".block-container {padding-top: 1rem", APP_SOURCE)

    def test_decision_facts_are_read_from_views_not_embedded_in_ui(self) -> None:
        for forbidden_fact in ("Ho Chi Minh City", "Laem Chabang", "7,800 KG", "60.0%"):
            self.assertNotIn(forbidden_fact, APP_SOURCE + COMPONENT_SOURCE)
        self.assertIn("document_evidence(shipment_id)", APP_SOURCE)
        self.assertIn("service.control_tower()", APP_SOURCE)

    def test_control_tower_preview_uses_active_shipment_context(self) -> None:
        self.assertIn('"selected_shipment_id": "SHP-1001"', APP_SOURCE)
        self.assertIn('target = data[data["SHIPMENT_ID"] == current]', APP_SOURCE)
        self.assertIn('key="selected_shipment_id"', APP_SOURCE)
        self.assertIn("on_change=clear_shipment_context_drafts", APP_SOURCE)
        self.assertNotIn("shipment_context_selector", APP_SOURCE + COMPONENT_SOURCE)
        self.assertNotIn("control_tower_shipment", APP_SOURCE)
        self.assertNotIn('data["SHIPMENT_ID"] == "SHP-1002"', APP_SOURCE)
        self.assertIn("These values intentionally remain constant", APP_SOURCE)
        self.assertIn("active shipment context changes", APP_SOURCE)

    def test_read_only_views_are_cached_without_caching_review_mutations(self) -> None:
        self.assertIn("@st.cache_data", SERVICE_SOURCE)
        self.assertIn("READ_CACHE_TTL_SECONDS = 45", SERVICE_SOURCE)
        review_method = SERVICE_SOURCE.split("def review_queue", 1)[1].split(
            "def audit_history", 1
        )[0]
        self.assertNotIn("cache=True", review_method)

    def test_evidence_and_trust_experience_is_present(self) -> None:
        for required_text in (
            "Visual comparison · problems first",
            "Inspect field-level source evidence",
            "Test action guardrail",
            "Test unknown-data fallback",
            "No answer or action was fabricated",
        ):
            self.assertIn(required_text, APP_SOURCE)
    def test_incomplete_upload_preview_is_not_in_the_judge_facing_ui(self) -> None:
        sidebar = APP_SOURCE.split("with st.sidebar:", 1)[1].split(
            "def control_tower_page", 1
        )[0]
        self.assertNotIn("New document investigation", sidebar)
        self.assertNotIn("st.file_uploader", APP_SOURCE)
        self.assertNotIn('"Document Intake":', APP_SOURCE)

    def test_confirmation_and_audit_boundary_is_visible(self) -> None:
        self.assertIn("The Copilot has not written anything", COMPONENT_SOURCE)
        self.assertIn("Cancel · write nothing", APP_SOURCE)
        self.assertIn("Confirm & create one case", APP_SOURCE)
        self.assertIn("render_audit_timeline", APP_SOURCE)

    def test_ui_still_uses_stable_application_contracts(self) -> None:
        for view in (
            "VW_CONTROL_TOWER",
            "VW_SHIPMENT_360",
            "VW_SHIPMENT_TIMELINE",
            "VW_DOCUMENT_COMPARISON",
            "VW_EXCEPTION_DETAIL",
            "VW_REVIEW_QUEUE",
            "VW_AUDIT_HISTORY",
            "VW_GOVERNANCE_STATUS",
            "VW_AUTOMATION_STATUS",
            "VW_DOCUMENT_INTAKE",
        ):
            self.assertIn(view, SERVICE_SOURCE)
        for procedure in (
            "PROPOSE_REVIEW_CASE",
            "CREATE_REVIEW_CASE",
            "UPDATE_REVIEW_CASE",
        ):
            self.assertIn(procedure, SERVICE_SOURCE)


if __name__ == "__main__":
    unittest.main()
