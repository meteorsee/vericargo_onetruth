import tempfile
import unittest
from pathlib import Path

from vericargo_onetruth.synthetic_data import generate_dataset


class SyntheticDataTests(unittest.TestCase):
    def test_generation_is_referentially_consistent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            datasets = generate_dataset(directory)
            supplier_ids = {row["supplier_id"] for row in datasets["suppliers"]}
            part_ids = {row["part_id"] for row in datasets["parts"]}
            order_ids = {row["order_id"] for row in datasets["orders"]}
            shipment_ids = {row["shipment_id"] for row in datasets["shipments"]}

            self.assertTrue(all(row["supplier_id"] in supplier_ids for row in datasets["parts"]))
            self.assertTrue(all(row["part_id"] in part_ids for row in datasets["order_lines"]))
            self.assertTrue(all(row["order_id"] in order_ids for row in datasets["shipments"]))
            self.assertTrue(all(row["shipment_id"] in shipment_ids for row in datasets["document_manifest"]))

            documents = Path(directory) / "documents"
            self.assertTrue(all((documents / row["relative_path"]).exists() for row in datasets["document_manifest"]))

    def test_all_required_document_scenarios_exist(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            datasets = generate_dataset(directory)
            outcomes = {row["expected_outcome"] for row in datasets["document_scenarios"]}
            self.assertEqual(
                outcomes,
                {"MATCH", "MISMATCH", "MISSING_DOCUMENT", "UNREADABLE", "AMBIGUOUS"},
            )

    def test_generated_readable_pdfs_have_valid_cross_reference_offsets(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            datasets = generate_dataset(directory)
            documents = Path(directory) / "documents"
            for row in datasets["document_manifest"]:
                if row["shipment_id"] == "SHP-1004" and row["document_type"] == "DRAFT_BL":
                    continue
                payload = (documents / row["relative_path"]).read_bytes()
                xref_offset = int(payload.rsplit(b"startxref\n", maxsplit=1)[1].splitlines()[0])
                self.assertEqual(payload[xref_offset : xref_offset + 4], b"xref")


if __name__ == "__main__":
    unittest.main()

