import unittest

from vericargo_onetruth.risk import calculate_risk


class RiskPolicyTests(unittest.TestCase):
    def test_boundary_scores_are_deterministic(self) -> None:
        result = calculate_risk(
            days_late=2,
            document_outcome="MISMATCH",
            document_reason="FIELD_MISMATCH",
            days_of_inventory=20,
            landed_cost=111,
            route_average_cost=100,
        )
        self.assertEqual((result.delivery, result.documents, result.inventory, result.cost), (15, 30, 8, 8))
        self.assertEqual((result.overall, result.severity), (61, "HIGH"))

    def test_data_quality_reason_scores_separately(self) -> None:
        result = calculate_risk(
            days_late=0,
            document_outcome="UNRESOLVED",
            document_reason="PARSE_FAILURE",
            days_of_inventory=None,
            landed_cost=100,
            route_average_cost=100,
        )
        self.assertEqual(result.data_quality, 10)
        self.assertEqual((result.overall, result.severity), (30, "MEDIUM"))

    def test_overall_score_is_capped(self) -> None:
        result = calculate_risk(
            days_late=10,
            document_outcome="MISMATCH",
            document_reason="PARSE_FAILURE",
            days_of_inventory=1,
            landed_cost=200,
            route_average_cost=100,
        )
        self.assertLessEqual(result.overall, 100)
