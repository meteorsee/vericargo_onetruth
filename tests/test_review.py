import unittest

from vericargo_onetruth.review import (
    ReviewCaseRequest,
    ReviewNotConfirmed,
    ReviewValidationError,
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


if __name__ == "__main__":
    unittest.main()

