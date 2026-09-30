"""Typed Snowflake service boundary for the VeriCargo Streamlit application."""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

AGENT_NAME = "VERICARGO_ONETRUTH.APP.VERICARGO_AGENT"
DB = "VERICARGO_ONETRUTH"


def parse_variant(value: Any) -> dict[str, Any]:
    """Normalize Snowflake VARIANT return values into a mapping."""

    if isinstance(value, dict):
        return value
    if isinstance(value, str):
        parsed = json.loads(value)
        return parsed if isinstance(parsed, dict) else {"content": parsed}
    return {"content": value}


def agent_text(response: dict[str, Any]) -> str:
    """Extract the human-readable text blocks from a Cortex Agent response."""

    messages: list[str] = []
    for item in response.get("content", []):
        if isinstance(item, dict) and item.get("type") == "text" and item.get("text"):
            messages.append(str(item["text"]))
    return "\n\n".join(messages) or "The agent returned no displayable text."


@dataclass
class OneTruthService:
    """All application reads and governed workflow calls pass through this class."""

    session: Any

    def frame(self, sql: str, params: list[Any] | None = None):
        return self.session.sql(sql, params=params or []).to_pandas()

    def control_tower(self):
        return self.frame(f"SELECT * FROM {DB}.APP.VW_CONTROL_TOWER ORDER BY attention_rank")

    def shipment_ids(self) -> list[str]:
        rows = self.session.sql(
            f"SELECT shipment_id FROM {DB}.APP.VW_SHIPMENT_360 ORDER BY shipment_id"
        ).collect()
        return [row["SHIPMENT_ID"] for row in rows]

    def shipment(self, shipment_id: str):
        return self.frame(
            f"SELECT * FROM {DB}.APP.VW_SHIPMENT_360 WHERE shipment_id = ?",
            [shipment_id],
        )

    def timeline(self, shipment_id: str):
        return self.frame(
            f"SELECT * FROM {DB}.APP.VW_SHIPMENT_TIMELINE "
            "WHERE shipment_id = ? ORDER BY event_sequence",
            [shipment_id],
        )

    def document_evidence(self, shipment_id: str):
        return self.frame(
            f"SELECT * FROM {DB}.APP.VW_DOCUMENT_COMPARISON "
            "WHERE shipment_id = ? ORDER BY display_order, field_name",
            [shipment_id],
        )

    def exceptions(self, shipment_id: str | None = None):
        if shipment_id:
            return self.frame(
                f"SELECT * FROM {DB}.APP.VW_EXCEPTION_DETAIL "
                "WHERE shipment_id = ? ORDER BY severity, exception_id",
                [shipment_id],
            )
        return self.frame(
            f"SELECT * FROM {DB}.APP.VW_EXCEPTION_DETAIL ORDER BY detected_at DESC"
        )

    def review_queue(self, shipment_id: str | None = None):
        if shipment_id:
            return self.frame(
                f"SELECT * FROM {DB}.APP.VW_REVIEW_QUEUE "
                "WHERE shipment_id = ? ORDER BY created_at DESC",
                [shipment_id],
            )
        return self.frame(f"SELECT * FROM {DB}.APP.VW_REVIEW_QUEUE ORDER BY created_at DESC")

    def audit_history(self, case_id: str | None = None):
        if case_id:
            return self.frame(
                f"SELECT * FROM {DB}.APP.VW_AUDIT_HISTORY "
                "WHERE case_id = ? ORDER BY event_at DESC",
                [case_id],
            )
        return self.frame(
            f"SELECT * FROM {DB}.APP.VW_AUDIT_HISTORY ORDER BY event_at DESC LIMIT 50"
        )

    def governance_status(self):
        return self.frame(f"SELECT * FROM {DB}.APP.VW_GOVERNANCE_STATUS ORDER BY check_name")

    def run_agent(self, question: str, shipment_id: str | None = None) -> dict[str, Any]:
        context = (
            f"Current application shipment context: {shipment_id}. "
            "Restrict shipment-specific evidence to this shipment unless the user explicitly asks otherwise.\n\n"
            if shipment_id
            else ""
        )
        request = json.dumps(
            {
                "messages": [
                    {
                        "role": "user",
                        "content": [{"type": "text", "text": context + question}],
                    }
                ],
                "background": False,
                "stream": False,
            }
        )
        row = self.session.sql(
            "SELECT TRY_PARSE_JSON(SNOWFLAKE.CORTEX.DATA_AGENT_RUN(?, ?, TRUE)) AS RESPONSE",
            params=[AGENT_NAME, request],
        ).collect()[0]
        return parse_variant(row["RESPONSE"])

    def propose_review_case(
        self,
        shipment_id: str,
        exception_ids: list[str],
        reason: str,
        severity: str,
        source_question: str,
    ) -> dict[str, Any]:
        return parse_variant(
            self.session.call(
                f"{DB}.APP.PROPOSE_REVIEW_CASE",
                shipment_id,
                exception_ids,
                reason,
                severity,
                source_question,
            )
        )

    def create_review_case(self, proposal: dict[str, Any]) -> dict[str, Any]:
        return parse_variant(
            self.session.call(
                f"{DB}.APP.CREATE_REVIEW_CASE",
                proposal["shipment_id"],
                proposal["exception_ids"],
                proposal["reason"],
                proposal["severity"],
                True,
                proposal["source_question"],
            )
        )

    def update_review_case(
        self, case_id: str, new_status: str, assigned_to: str, resolution_note: str
    ) -> dict[str, Any]:
        return parse_variant(
            self.session.call(
                f"{DB}.APP.UPDATE_REVIEW_CASE",
                case_id,
                new_status,
                assigned_to,
                resolution_note,
            )
        )
