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

    def test_first_view_is_decision_first(self) -> None:
        self.assertIn("One shipment. Two destinations. One governed truth.", COMPONENT_SOURCE)
        self.assertIn("render_decision_brief", APP_SOURCE)
        self.assertLess(
            APP_SOURCE.index("render_decision_brief(decision_row"),
            APP_SOURCE.index('st.subheader("Canonical portfolio metrics")'),
        )

    def test_decision_facts_are_read_from_views_not_embedded_in_ui(self) -> None:
        for forbidden_fact in ("Ho Chi Minh City", "Laem Chabang", "7,800 KG", "60.0%"):
            self.assertNotIn(forbidden_fact, APP_SOURCE + COMPONENT_SOURCE)
        self.assertIn("document_evidence(decision_id)", APP_SOURCE)
        self.assertIn("service.control_tower()", APP_SOURCE)

    def test_evidence_and_trust_experience_is_present(self) -> None:
        for required_text in (
            "Visual comparison · problems first",
            "Inspect field-level source evidence",
            "Test action guardrail",
            "Test unknown-data fallback",
            "No answer or action was fabricated",
        ):
            self.assertIn(required_text, APP_SOURCE)

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
