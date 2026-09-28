import unittest

from vericargo_onetruth.review import (
    ReviewCaseRequest,
    ReviewNotConfirmed,
    ReviewValidationError,
    ensure_no_active_duplicate,
    validate_case_transition,
    validate_review_case,
)


class ReviewGuardrailTests(unittest.TestCase):
    def setUp(self) -> None:
        self.known = {"SHP-1001", "SHP-1002"}

    def test_confirmation_is_required(self) -> None:
        request = ReviewCaseRequest("SHP-1002", "Document mismatch", "HIGH", False, "Why?")
        with self.assertRaises(ReviewNotConfirmed):
            validate_review_case(request, self.known)

    def test_unknown_shipment_is_rejected(self) -> None:
        request = ReviewCaseRequest("SHP-9999", "Document mismatch", "HIGH", True, "Why?")
        with self.assertRaises(ReviewValidationError):
            validate_review_case(request, self.known)

    def test_valid_request_is_normalized(self) -> None:
        request = ReviewCaseRequest(" shp-1002 ", " Port mismatch ", " high ", True, "Why?")
        validated = validate_review_case(request, self.known)
        self.assertEqual(validated.shipment_id, "SHP-1002")
        self.assertEqual(validated.severity, "HIGH")
        self.assertEqual(validated.reason, "Port mismatch")

    def test_duplicate_active_case_is_rejected(self) -> None:
        with self.assertRaises(ReviewValidationError):
            ensure_no_active_duplicate("shp-1002", {"SHP-1002"})

    def test_legal_review_transitions(self) -> None:
        self.assertEqual(validate_case_transition("PENDING", "IN_REVIEW"), ("IN_REVIEW", ""))
        self.assertEqual(
            validate_case_transition("IN_REVIEW", "RESOLVED", "Documents corrected."),
            ("RESOLVED", "Documents corrected."),
        )

    def test_illegal_transition_and_missing_resolution_are_rejected(self) -> None:
        with self.assertRaises(ReviewValidationError):
            validate_case_transition("PENDING", "RESOLVED", "Skipped review")
        with self.assertRaises(ReviewValidationError):
            validate_case_transition("IN_REVIEW", "REJECTED", "")


if __name__ == "__main__":
    unittest.main()

