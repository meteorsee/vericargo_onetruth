"""Typed Snowflake service boundary for the VeriCargo Streamlit application."""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from io import BytesIO
from typing import Any

import streamlit as st

AGENT_NAME = "VERICARGO_ONETRUTH.APP.VERICARGO_AGENT"
DB = "VERICARGO_ONETRUTH"
READ_CACHE_TTL_SECONDS = 45
MAX_DOCUMENT_UPLOAD_BYTES = 10 * 1024 * 1024
ALLOWED_PDF_CONTENT_TYPES = {"", "application/pdf", "application/octet-stream"}


def inspect_pdf_upload(filename: str, content_type: str | None, payload: bytes) -> dict[str, Any]:
    """Perform deterministic file-level validation without claiming content extraction."""

    original_name = str(filename or "")
    basename = original_name.replace("\\", "/").rsplit("/", maxsplit=1)[-1]
    safe_name = re.sub(r"[^A-Za-z0-9._-]+", "_", basename).strip("._")
    safe_name = (safe_name or "upload.pdf")[:255]
    digest = hashlib.sha256(payload).hexdigest()
    media_type = str(content_type or "").lower().split(";", maxsplit=1)[0].strip()

    validation = "VALID_PDF"
    message = "PDF signature and end marker are valid."
    if not payload:
        validation, message = "EMPTY_FILE", "The uploaded file is empty."
    elif len(payload) > MAX_DOCUMENT_UPLOAD_BYTES:
        validation, message = "TOO_LARGE", "The upload exceeds the governed 10 MB intake limit."
    elif not basename.lower().endswith(".pdf"):
        validation, message = "INVALID_EXTENSION", "Only PDF files are accepted."
    elif media_type not in ALLOWED_PDF_CONTENT_TYPES:
        validation, message = "INVALID_CONTENT_TYPE", "The browser did not identify this as a PDF."
    elif not payload.startswith(b"%PDF-"):
        validation, message = "INVALID_PDF_SIGNATURE", "The file does not contain a PDF signature."
    elif b"%%EOF" not in payload[-4096:]:
        validation, message = "MISSING_PDF_EOF", "The PDF is incomplete or unreadable."

    return {
        "original_filename": original_name,
        "safe_filename": safe_name,
        "content_type": media_type,
        "size_bytes": len(payload),
        "sha256": digest,
        "client_validation": validation,
        "message": message,
    }


@st.cache_data(ttl=READ_CACHE_TTL_SECONDS, show_spinner=False)
def _cached_frame(_session: Any, sql: str, params: tuple[Any, ...]):
    """Cache stable, read-only application views between Streamlit reruns."""

    return _session.sql(sql, params=list(params)).to_pandas()


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

    def frame(
        self,
        sql: str,
        params: list[Any] | None = None,
        *,
        cache: bool = False,
    ):
        normalized = tuple(params or [])
        if cache:
            return _cached_frame(self.session, sql, normalized)
        return self.session.sql(sql, params=list(normalized)).to_pandas()

    def control_tower(self):
        return self.frame(
            f"SELECT * FROM {DB}.APP.VW_CONTROL_TOWER ORDER BY attention_rank",
            cache=True,
        )

    def shipment_ids(self) -> list[str]:
        frame = self.frame(
            f"SELECT shipment_id FROM {DB}.APP.VW_SHIPMENT_360 ORDER BY shipment_id",
            cache=True,
        )
        return frame["SHIPMENT_ID"].tolist()

    def shipment(self, shipment_id: str):
        return self.frame(
            f"SELECT * FROM {DB}.APP.VW_SHIPMENT_360 WHERE shipment_id = ?",
            [shipment_id],
            cache=True,
        )

    def timeline(self, shipment_id: str):
        return self.frame(
            f"SELECT * FROM {DB}.APP.VW_SHIPMENT_TIMELINE "
            "WHERE shipment_id = ? ORDER BY event_sequence",
            [shipment_id],
            cache=True,
        )

    def document_evidence(self, shipment_id: str):
        return self.frame(
            f"SELECT * FROM {DB}.APP.VW_DOCUMENT_COMPARISON "
            "WHERE shipment_id = ? ORDER BY display_order, field_name",
            [shipment_id],
            cache=True,
        )

    def document_intake(self, shipment_id: str | None = None):
        if shipment_id:
            return self.frame(
                f"SELECT * FROM {DB}.APP.VW_DOCUMENT_INTAKE "
                "WHERE shipment_id = ? ORDER BY created_at DESC",
                [shipment_id],
            )
        return self.frame(
            f"SELECT * FROM {DB}.APP.VW_DOCUMENT_INTAKE ORDER BY created_at DESC"
        )

    def upload_and_verify_document(
        self,
        shipment_id: str,
        document_type: str,
        filename: str,
        content_type: str | None,
        payload: bytes,
        viewer_identity: str = "UNKNOWN_VIEWER",
    ) -> dict[str, Any]:
        """Validate, quarantine-stage, and audit an uploaded PDF."""

        inspection = inspect_pdf_upload(filename, content_type, payload)
        stage_path: str | None = None
        stage_status = "NOT_STAGED"
        error_details: str | None = None
        client_validation = str(inspection["client_validation"])

        if client_validation == "VALID_PDF":
            stage_filename = (
                f"{inspection['sha256'][:16]}_{inspection['safe_filename']}"
            )
            stage_path = (
                f"@{DB}.RAW.DOCUMENT_INTAKE_STAGE/"
                f"{shipment_id}/{document_type}/{stage_filename}"
            )
            try:
                self.session.file.put_stream(
                    BytesIO(payload),
                    stage_path,
                    auto_compress=False,
                    source_compression="NONE",
                    overwrite=False,
                )
                stage_status = "STAGED"
            except Exception as exc:  # noqa: BLE001
                stage_status = "FAILED"
                client_validation = "STAGE_FAILED"
                error_details = f"{type(exc).__name__}: {exc}"[:2000]

        result = parse_variant(
            self.session.call(
                f"{DB}.APP.RECORD_DOCUMENT_INTAKE",
                shipment_id,
                document_type,
                inspection["original_filename"],
                inspection["safe_filename"],
                inspection["content_type"],
                inspection["size_bytes"],
                inspection["sha256"],
                stage_path,
                stage_status,
                client_validation,
                error_details or inspection["message"],
                viewer_identity,
            )
        )
        result["inspection"] = inspection
        result["stage_status"] = stage_status
        result["stage_error"] = error_details
        return result

    def exceptions(self, shipment_id: str | None = None):
        if shipment_id:
            return self.frame(
                f"SELECT * FROM {DB}.APP.VW_EXCEPTION_DETAIL "
                "WHERE shipment_id = ? ORDER BY severity, exception_id",
                [shipment_id],
                cache=True,
            )
        return self.frame(
            f"SELECT * FROM {DB}.APP.VW_EXCEPTION_DETAIL ORDER BY detected_at DESC",
            cache=True,
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

    def automation_status(self):
        return self.frame(
            f"SELECT * FROM {DB}.APP.VW_AUTOMATION_STATUS",
            cache=True,
        )

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
