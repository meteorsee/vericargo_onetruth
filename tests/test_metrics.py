import unittest
from decimal import Decimal

from vericargo_onetruth.metrics import canonical_metrics, fill_rate
from vericargo_onetruth.synthetic_data import (
    INVENTORY_SNAPSHOTS,
    LANDED_COSTS,
    ORDER_LINES,
    SHIPMENTS,
    shipped_lines_with_dates,
)


class CanonicalMetricTests(unittest.TestCase):
    def test_fixture_metrics_are_stable(self) -> None:
        metrics = canonical_metrics(
            shipments=SHIPMENTS,
            order_lines=ORDER_LINES,
            inventory_snapshots=INVENTORY_SNAPSHOTS,
            shipped_lines=shipped_lines_with_dates(),
            landed_costs=LANDED_COSTS,
        )
        self.assertEqual(metrics["on_time_delivery_rate"], Decimal("0.6"))
        self.assertEqual(metrics["fill_rate"], Decimal(590) / Decimal(610))
        self.assertEqual(metrics["days_of_inventory"], Decimal(1280) / (Decimal(590) / Decimal(30)))
        self.assertEqual(metrics["landed_cost_usd"], Decimal("68392.50"))

    def test_fill_rate_caps_over_shipment(self) -> None:
        self.assertEqual(
            fill_rate([{"ordered_qty": 10, "shipped_qty": 12}]),
            Decimal(1),
        )

    def test_fill_rate_rejects_negative_quantities(self) -> None:
        with self.assertRaises(ValueError):
            fill_rate([{"ordered_qty": 10, "shipped_qty": -1}])


if __name__ == "__main__":
    unittest.main()

