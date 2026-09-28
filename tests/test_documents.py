import unittest
from decimal import Decimal

from vericargo_onetruth.document_comparison import (
    compare_documents,
    normalize_port,
    normalize_weight_kg,
)


class DocumentComparisonTests(unittest.TestCase):
    def test_units_and_port_aliases_match(self) -> None:
        self.assertEqual(normalize_weight_kg("10 MT"), Decimal(10000))
        self.assertEqual(normalize_port("Cat Lai, Vietnam / VNSGN"), "VNSGN")

    def test_complete_match(self) -> None:
        si = {
            "shipper": "Nimbus Components",
            "consignee": "Orion Motors",
            "notify_party": "Orion Logistics",
            "port_of_loading": "Penang / MYPEN",
            "port_of_discharge": "Laem Chabang / THLCH",
            "container_count": "1 x 40HC",
            "gross_weight": "10,000 KG",
        }
        draft = {
            **si,
            "container_count": "1 container",
            "gross_weight": "10 MT",
        }
        self.assertEqual(compare_documents(si, draft)["overall_status"], "MATCH")

    def test_mismatch_wins_over_unresolved(self) -> None:
        si = {"port_of_discharge": "VNSGN", "gross_weight": "8,000 KG"}
        draft = {"port_of_discharge": "THLCH", "gross_weight": None}
        self.assertEqual(compare_documents(si, draft)["overall_status"], "MISMATCH")

    def test_missing_and_unreadable_values_are_standardized(self) -> None:
        missing = compare_documents({"gross_weight": None}, {"gross_weight": "10 KG"})
        self.assertEqual(missing["fields"]["gross_weight"]["status"], "MISSING")
        unreadable = compare_documents({"gross_weight": "not legible"}, {"gross_weight": "10 KG"})
        self.assertEqual(unreadable["fields"]["gross_weight"]["status"], "UNRESOLVED")


if __name__ == "__main__":
    unittest.main()

