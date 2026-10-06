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
            fixture_ids = {
                row["document_id"] for row in datasets["document_extraction_fixtures"]
            }
            self.assertEqual(
                fixture_ids,
                {row["document_id"] for row in datasets["document_manifest"]},
            )
            registry = datasets["document_file_registry"]
            self.assertEqual(
                {row["document_id"] for row in registry},
                {row["document_id"] for row in datasets["document_manifest"]},
            )
            self.assertTrue(all(len(row["sha256"]) == 64 for row in registry))
            self.assertTrue(all(int(row["size_bytes"]) > 0 for row in registry))

            documents = Path(directory) / "documents"
            self.assertTrue(all((documents / row["relative_path"]).exists() for row in datasets["document_manifest"]))

    def test_all_required_document_scenarios_exist(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            datasets = generate_dataset(directory)
            outcomes = {row["expected_outcome"] for row in datasets["document_scenarios"]}
            self.assertEqual(
                outcomes,
                {"MATCH", "MISMATCH", "MISSING", "UNRESOLVED"},
            )
            reasons = {row["expected_reason"] for row in datasets["document_scenarios"]}
            self.assertIn("MISSING_DOCUMENT", reasons)
            self.assertIn("PARSE_FAILURE", reasons)
            self.assertIn("AMBIGUOUS_PAIR", reasons)

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

    def test_trial_extraction_fixtures_preserve_document_failure(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            datasets = generate_dataset(directory)
            fixtures = {
                row["document_id"]: row
                for row in datasets["document_extraction_fixtures"]
            }
            self.assertEqual(fixtures["DOC-SHP-1004-BL"]["processing_status"], "FAILED")
            self.assertEqual(fixtures["DOC-SHP-1002-SI"]["processing_status"], "PARSED")
            self.assertEqual(
                fixtures["DOC-SHP-1002-SI"]["port_of_discharge"],
                "Ho Chi Minh City / VNSGN",
            )

    def test_document_registry_hashes_match_generated_files(self) -> None:
        import hashlib

        with tempfile.TemporaryDirectory() as directory:
            datasets = generate_dataset(directory)
            documents = Path(directory) / "documents"
            for row in datasets["document_file_registry"]:
                payload = (documents / row["relative_path"]).read_bytes()
                self.assertEqual(hashlib.sha256(payload).hexdigest(), row["sha256"])
                self.assertEqual(len(payload), int(row["size_bytes"]))


if __name__ == "__main__":
    unittest.main()

