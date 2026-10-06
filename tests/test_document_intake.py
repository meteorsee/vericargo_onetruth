from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_DIR = ROOT / "app"
if str(APP_DIR) not in sys.path:
    sys.path.insert(0, str(APP_DIR))

from services import MAX_DOCUMENT_UPLOAD_BYTES, OneTruthService, inspect_pdf_upload


class _FakeFileOperation:
    def __init__(self) -> None:
        self.stage_location = None

    def put_stream(self, _stream, stage_location: str, **_kwargs):
        self.stage_location = stage_location


class _FakeSession:
    def __init__(self) -> None:
        self.file = _FakeFileOperation()
        self.call_args = None

    def call(self, *args):
        self.call_args = args
        return {
            "status": "RECORDED",
            "intake_id": "INT-00000001",
            "verification_status": "VERIFIED_REGISTERED",
            "message": "Verified.",
        }


class DocumentIntakeValidationTests(unittest.TestCase):
    def test_valid_pdf_is_hashed_and_sanitized(self) -> None:
        payload = b"%PDF-1.4\nsynthetic test\n%%EOF\n"
        result = inspect_pdf_upload("../Unsafe SI (final).pdf", "application/pdf", payload)
        self.assertEqual("VALID_PDF", result["client_validation"])
        self.assertEqual("Unsafe_SI_final_.pdf", result["safe_filename"])
        self.assertEqual(64, len(result["sha256"]))
        self.assertEqual(len(payload), result["size_bytes"])

    def test_non_pdf_and_incomplete_pdf_are_rejected(self) -> None:
        text = inspect_pdf_upload("document.pdf", "application/pdf", b"plain text")
        self.assertEqual("INVALID_PDF_SIGNATURE", text["client_validation"])
        incomplete = inspect_pdf_upload(
            "document.pdf", "application/pdf", b"%PDF-1.4\nincomplete"
        )
        self.assertEqual("MISSING_PDF_EOF", incomplete["client_validation"])

    def test_governed_size_limit_is_enforced(self) -> None:
        payload = b"%PDF-" + (b"x" * MAX_DOCUMENT_UPLOAD_BYTES) + b"%%EOF"
        result = inspect_pdf_upload("large.pdf", "application/pdf", payload)
        self.assertEqual("TOO_LARGE", result["client_validation"])

    def test_valid_upload_is_quarantine_staged_and_audited(self) -> None:
        session = _FakeSession()
        payload = b"%PDF-1.4\nsynthetic test\n%%EOF\n"
        result = OneTruthService(session).upload_and_verify_document(
            "SHP-1001", "SI", "sample.pdf", "application/pdf", payload
        )
        self.assertEqual("VERIFIED_REGISTERED", result["verification_status"])
        self.assertIn("DOCUMENT_INTAKE_STAGE/SHP-1001/SI/", session.file.stage_location)
        self.assertEqual(
            "VERICARGO_ONETRUTH.APP.RECORD_DOCUMENT_INTAKE",
            session.call_args[0],
        )
        self.assertEqual("STAGED", session.call_args[9])
        self.assertEqual("VALID_PDF", session.call_args[10])
        self.assertEqual("UNKNOWN_VIEWER", session.call_args[12])
        self.assertEqual("STAGED", result["stage_status"])
        self.assertIsNone(result["stage_error"])


if __name__ == "__main__":
    unittest.main()
