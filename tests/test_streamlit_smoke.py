from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import patch

import pandas as pd
from streamlit.testing.v1 import AppTest

ROOT = Path(__file__).resolve().parents[1]
APP_DIR = ROOT / "app"
if str(APP_DIR) not in sys.path:
    sys.path.insert(0, str(APP_DIR))


class FakeQuery:
    def __init__(self, session: FakeSession, sql: str, params: list | None = None) -> None:
        self.session = session
        self.sql = sql
        self.params = params or []

    def collect(self):
        if "SELECT shipment_id FROM" in self.sql:
            return [{"SHIPMENT_ID": shipment_id} for shipment_id in self.session.shipment_ids]
        return []

    def to_pandas(self) -> pd.DataFrame:
        if "VW_CONTROL_TOWER" in self.sql:
            return self.session.control.copy()
        if "SELECT shipment_id FROM" in self.sql:
            return pd.DataFrame({"SHIPMENT_ID": self.session.shipment_ids})
        if "VW_SHIPMENT_360" in self.sql:
            frame = self.session.control.copy()
            if self.params:
                frame = frame[frame["SHIPMENT_ID"] == self.params[0]]
            return frame
        if "VW_SHIPMENT_TIMELINE" in self.sql:
            return self.session.timeline.copy()
        if "VW_DOCUMENT_COMPARISON" in self.sql:
            if self.params and self.params[0] != "SHP-1002":
                return self.session.evidence.iloc[0:0].copy()
            return self.session.evidence.copy()
        if "VW_EXCEPTION_DETAIL" in self.sql:
            if self.params and self.params[0] != "SHP-1002":
                return self.session.exceptions.iloc[0:0].copy()
            return self.session.exceptions.copy()
        if "VW_REVIEW_QUEUE" in self.sql:
            return self.session.review_queue.copy()
        if "VW_AUDIT_HISTORY" in self.sql:
            return self.session.audit.copy()
        if "VW_GOVERNANCE_STATUS" in self.sql:
            return self.session.governance.copy()
        if "VW_AUTOMATION_STATUS" in self.sql:
            return self.session.automation.copy()
        return pd.DataFrame()


class FakeSession:
    def __init__(self) -> None:
        self.shipment_ids = [f"SHP-100{i}" for i in range(1, 7)]
        rows = []
        for index, shipment_id in enumerate(self.shipment_ids, start=1):
            delivered = 0 if shipment_id == "SHP-1004" else 1
            on_time = 1 if shipment_id in {"SHP-1001", "SHP-1003", "SHP-1005"} else 0
            rows.append(
                {
                    "SHIPMENT_ID": shipment_id,
                    "ORDER_ID": f"ORD-100{index}",
                    "SUPPLIER_NAME": "Atlas Components",
                    "SUPPLIER_RISK_TIER": "MEDIUM",
                    "CUSTOMER_NAME": "Pacific Assembly",
                    "PLANT_NAME": "Penang Plant",
                    "PART_IDS": "PART-001",
                    "CONTAINER_ID": f"CONT-00{index}",
                    "ORIGIN_PORT_CODE": "MYPKG",
                    "ORIGIN_PORT_NAME": "Port Klang",
                    "DESTINATION_PORT_CODE": "VNSGN",
                    "DESTINATION_PORT_NAME": "Ho Chi Minh City",
                    "SHIP_DATE": pd.Timestamp("2026-09-01").date(),
                    "PROMISED_DELIVERY_DATE": pd.Timestamp("2026-09-09").date(),
                    "ACTUAL_DELIVERY_DATE": (
                        None if not delivered else pd.Timestamp("2026-09-10").date()
                    ),
                    "STATUS": "IN_TRANSIT" if not delivered else "DELIVERED",
                    "DELIVERED_FLAG": delivered,
                    "ON_TIME_DELIVERED_FLAG": on_time,
                    "DELIVERY_DAYS_LATE": 1 if shipment_id == "SHP-1002" else 0,
                    "DELIVERY_RISK_SCORE": 20,
                    "DOCUMENT_RISK_SCORE": 25 if shipment_id == "SHP-1002" else 0,
                    "INVENTORY_RISK_SCORE": 5,
                    "COST_RISK_SCORE": 5,
                    "DATA_QUALITY_RISK_SCORE": 0,
                    "OVERALL_RISK_SCORE": 55 if shipment_id == "SHP-1002" else 10,
                    "RISK_SEVERITY": "HIGH" if shipment_id == "SHP-1002" else "LOW",
                    "RISK_CONTRIBUTORS": "Late delivery; document mismatch",
                    "DOCUMENT_OUTCOME": "MISMATCH" if shipment_id == "SHP-1002" else "MATCH",
                    "DOCUMENT_OUTCOME_REASON": (
                        "FIELD_MISMATCH" if shipment_id == "SHP-1002" else "COMPLETE_MATCH"
                    ),
                    "DOCUMENT_MIN_CONFIDENCE": 0.94,
                    "OPEN_EXCEPTION_COUNT": 2 if shipment_id == "SHP-1002" else 0,
                    "HIGH_EXCEPTION_COUNT": 1 if shipment_id == "SHP-1002" else 0,
                    "EXCEPTION_IDS": (
                        "DELIVERY-SHP-1002, DOC-SHP-1002"
                        if shipment_id == "SHP-1002"
                        else None
                    ),
                    "ON_TIME_DELIVERY_RATE": 0.6,
                    "FILL_RATE": 0.967,
                    "PORTFOLIO_DAYS_OF_INVENTORY": 65.1,
                    "PORTFOLIO_LANDED_COST_USD": 68392.5,
                    "DELAYED_SHIPMENT_COUNT": 2,
                    "EXCEPTION_COUNT": 7,
                    "ATTENTION_RANK": 1 if shipment_id == "SHP-1002" else index,
                    "ATTENTION_REASON": "Late delivery; document mismatch",
                }
            )
        self.control = pd.DataFrame(rows)
        self.timeline = pd.DataFrame(
            [
                {
                    "EVENT_SEQUENCE": 1,
                    "EVENT_TS": pd.Timestamp("2026-09-08 13:10"),
                    "EVENT_TYPE": "PORT_HOLD",
                    "LOCATION_CODE": "VNSGN",
                    "TEMPERATURE_C": 31.8,
                },
                {
                    "EVENT_SEQUENCE": 2,
                    "EVENT_TS": pd.Timestamp("2026-09-10 16:45"),
                    "EVENT_TYPE": "DELIVERED",
                    "LOCATION_CODE": "VNSGN",
                    "TEMPERATURE_C": 29.1,
                },
            ]
        )
        evidence_rows = []
        values = [
            ("PORT_OF_DISCHARGE", "Ho Chi Minh City / VNSGN", "VNSGN", "Laem Chabang / THLCH", "THLCH", "MISMATCH"),
            ("GROSS_WEIGHT_KG", "8 MT", "8000", "7,800 KG", "7800", "MISMATCH"),
            ("CONTAINER_COUNT", "1 container", "1", "1", "1", "MATCH"),
            ("PORT_OF_LOADING", "Port Klang / MYPKG", "MYPKG", "Port Klang / MYPKG", "MYPKG", "MATCH"),
        ]
        for order, (field, si, nsi, bl, nbl, status) in enumerate(values, start=1):
            evidence_rows.append(
                {
                    "FIELD_NAME": field,
                    "COMPARISON_STATUS": status,
                    "SI_VALUE": si,
                    "NORMALIZED_SI": nsi,
                    "SI_CONFIDENCE": 0.95,
                    "SI_SOURCE": "doc-shp-1002-si.pdf",
                    "SI_SOURCE_LOCATION": None,
                    "SI_PROCESSING_STATUS": "PARSED",
                    "BL_VALUE": bl,
                    "NORMALIZED_BL": nbl,
                    "BL_CONFIDENCE": 0.94,
                    "BL_SOURCE": "doc-shp-1002-bl.pdf",
                    "BL_SOURCE_LOCATION": None,
                    "BL_PROCESSING_STATUS": "PARSED",
                    "ERROR_DETAILS": None,
                    "DISPLAY_ORDER": order,
                }
            )
        self.evidence = pd.DataFrame(evidence_rows)
        self.exceptions = pd.DataFrame(
            [
                {
                    "EXCEPTION_ID": "DOC-SHP-1002",
                    "EXCEPTION_CATEGORY": "DOCUMENT",
                    "SEVERITY": "MEDIUM",
                    "REASON": "FIELD_MISMATCH",
                    "DESCRIPTION": "Document fields disagree.",
                },
                {
                    "EXCEPTION_ID": "DELIVERY-SHP-1002",
                    "EXCEPTION_CATEGORY": "OPERATIONAL",
                    "SEVERITY": "MEDIUM",
                    "REASON": "DELIVERED_LATE",
                    "DESCRIPTION": "Shipment missed its promise date.",
                },
            ]
        )
        self.review_queue = pd.DataFrame(
            columns=[
                "CASE_ID", "SHIPMENT_ID", "REASON", "SEVERITY", "STATUS",
                "ASSIGNED_TO", "SOURCE_QUESTION", "CREATED_BY", "CREATED_AT",
                "UPDATED_BY", "UPDATED_AT", "RESOLUTION_NOTE", "RESOLVED_BY",
                "RESOLVED_AT", "CONFIRMATION_RECORDED", "EXCEPTION_IDS",
                "LINKED_EXCEPTION_COUNT",
            ]
        )
        self.audit = pd.DataFrame(
            columns=[
                "AUDIT_EVENT_ID", "CASE_ID", "EVENT_TYPE", "FROM_STATUS", "TO_STATUS",
                "EVENT_NOTE", "ACTOR", "EVENT_AT",
            ]
        )
        now = pd.Timestamp("2026-09-30 09:00")
        self.governance = pd.DataFrame(
            [
                {"CHECK_NAME": "DATA_FRESHNESS", "STATUS": "HEALTHY", "CHECK_VALUE": str(now), "DETAILS": "Latest refresh", "CHECKED_AT": now},
                {"CHECK_NAME": "DOCUMENT_HEALTH", "STATUS": "ATTENTION", "CHECK_VALUE": "11/12 parsed", "DETAILS": "Failures stay unresolved", "CHECKED_AT": now},
                {"CHECK_NAME": "EVIDENCE_RETRIEVAL_MODE", "STATUS": "GOVERNED", "CHECK_VALUE": "SEMANTIC_VIEW", "DETAILS": "Trial-safe structured evidence retrieval", "CHECKED_AT": now},
                {"CHECK_NAME": "EVIDENCE_CORPUS", "STATUS": "HEALTHY", "CHECK_VALUE": "11 governed evidence rows", "DETAILS": "Evidence available through Analyst", "CHECKED_AT": now},
                {"CHECK_NAME": "REVIEW_GUARDRAIL", "STATUS": "ENFORCED", "CHECK_VALUE": "0 confirmed case(s)", "DETAILS": "Confirmation required", "CHECKED_AT": now},
                {"CHECK_NAME": "KPI:ON_TIME_DELIVERY_RATE", "STATUS": "GOVERNED", "CHECK_VALUE": "Delivered on/before promise / delivered", "DETAILS": "Shipment grain", "CHECKED_AT": now},
                {"CHECK_NAME": "KPI:FILL_RATE", "STATUS": "GOVERNED", "CHECK_VALUE": "Capped shipped / ordered", "DETAILS": "Order-line grain", "CHECKED_AT": now},
                {"CHECK_NAME": "KPI:DAYS_OF_INVENTORY", "STATUS": "GOVERNED", "CHECK_VALUE": "On-hand / demand", "DETAILS": "Plant-part grain", "CHECKED_AT": now},
                {"CHECK_NAME": "KPI:LANDED_COST", "STATUS": "GOVERNED", "CHECK_VALUE": "Cost components", "DETAILS": "Shipment grain; USD", "CHECKED_AT": now},
            ]
        )
        self.automation = pd.DataFrame(
            [
                {
                    "RUN_AT": now,
                    "OPEN_EXCEPTION_COUNT": 7,
                    "HIGH_SEVERITY_COUNT": 3,
                    "PENDING_REVIEW_COUNT": 0,
                    "DIGEST_TEXT": (
                        "VeriCargo OneTruth daily digest: 7 open exception(s), "
                        "3 high/critical, 0 pending human-review case(s)."
                    ),
                    "AUTOMATION_STATUS": "HEALTHY",
                }
            ]
        )

    def sql(self, sql: str, params: list | None = None) -> FakeQuery:
        return FakeQuery(self, sql, params)

    def call(self, *_args, **_kwargs):
        return {"status": "PROPOSED"}


class StreamlitPageSmokeTests(unittest.TestCase):
    def test_all_connected_pages_render_against_stable_contracts(self) -> None:
        app_path = ROOT / "app" / "streamlit_app.py"
        fake_session = FakeSession()
        with patch(
            "snowflake.snowpark.context.get_active_session", return_value=fake_session
        ):
            app = AppTest.from_file(str(app_path), default_timeout=20).run()
            self.assertEqual([], list(app.exception))
            for page in (
                "Shipment Intelligence",
                "Document Evidence",
                "OneTruth Copilot",
                "Human Review",
                "Governance",
                "Control Tower",
            ):
                app.session_state["current_page"] = page
                app.run()
                self.assertEqual([], list(app.exception), page)

    def test_control_tower_preview_follows_selected_shipment(self) -> None:
        app_path = ROOT / "app" / "streamlit_app.py"
        fake_session = FakeSession()
        with patch(
            "snowflake.snowpark.context.get_active_session", return_value=fake_session
        ):
            app = AppTest.from_file(str(app_path), default_timeout=20).run()
            self.assertEqual("SHP-1001", app.session_state["selected_shipment_id"])
            selector = next(
                element
                for element in app.selectbox
                if element.label == "Active shipment context"
            )
            selector.select("SHP-1002").run()
            self.assertEqual([], list(app.exception))
            self.assertEqual("SHP-1002", app.session_state["selected_shipment_id"])
            self.assertEqual(
                "SHP-1002",
                next(
                    element.value
                    for element in app.selectbox
                    if element.label == "Active shipment context"
                ),
            )
            self.assertIn(
                "SHP-1002 · Selected shipment",
                [element.value for element in app.subheader],
            )


if __name__ == "__main__":
    unittest.main()
