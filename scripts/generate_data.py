from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from vericargo_onetruth.synthetic_data import generate_dataset

if __name__ == "__main__":
    destination = ROOT / "data" / "generated"
    datasets = generate_dataset(destination)
    row_count = sum(len(rows) for rows in datasets.values())
    print(f"Generated {len(datasets)} datasets with {row_count} rows in {destination}")

