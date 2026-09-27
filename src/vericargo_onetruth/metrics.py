"""Canonical supply-chain metrics shared by fixture validation and tests."""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from datetime import date, timedelta
from decimal import Decimal
from typing import Any

Number = int | float | Decimal


def _decimal(value: Number | str | None) -> Decimal:
    if value is None or value == "":
        return Decimal(0)
    return Decimal(str(value))


def _as_date(value: date | str | None) -> date | None:
    if value in (None, ""):
        return None
    if isinstance(value, date):
        return value
    return date.fromisoformat(str(value))


def on_time_delivery_rate(shipments: Iterable[Mapping[str, Any]]) -> Decimal | None:
    """Return on-time delivered shipments divided by delivered shipments."""

    delivered = 0
    on_time = 0
    for shipment in shipments:
        actual = _as_date(shipment.get("actual_delivery_date"))
        promised = _as_date(shipment.get("promised_delivery_date"))
        if actual is None:
            continue
        delivered += 1
        if promised is not None and actual <= promised:
            on_time += 1
    if delivered == 0:
        return None
    return Decimal(on_time) / Decimal(delivered)


def fill_rate(order_lines: Iterable[Mapping[str, Any]]) -> Decimal | None:
    """Return capped shipped quantity divided by ordered quantity."""

    ordered_total = Decimal(0)
    fulfilled_total = Decimal(0)
    for line in order_lines:
        ordered = _decimal(line.get("ordered_qty"))
        shipped = _decimal(line.get("shipped_qty"))
        if ordered < 0 or shipped < 0:
            raise ValueError("Quantities cannot be negative.")
        ordered_total += ordered
        fulfilled_total += min(shipped, ordered)
    if ordered_total == 0:
        return None
    return fulfilled_total / ordered_total


def latest_inventory_rows(
    snapshots: Iterable[Mapping[str, Any]],
) -> list[Mapping[str, Any]]:
    """Return the latest snapshot for every plant and part pair."""

    latest: dict[tuple[str, str], Mapping[str, Any]] = {}
    for row in snapshots:
        key = (str(row["plant_id"]), str(row["part_id"]))
        current = latest.get(key)
        if current is None or _as_date(row["snapshot_date"]) > _as_date(current["snapshot_date"]):
            latest[key] = row
    return list(latest.values())


def days_of_inventory(
    snapshots: Iterable[Mapping[str, Any]],
    shipped_lines: Iterable[Mapping[str, Any]],
) -> Decimal | None:
    """Return latest on-hand divided by trailing-30-day average shipped quantity."""

    latest = latest_inventory_rows(snapshots)
    if not latest:
        return None
    anchor = max(_as_date(row["snapshot_date"]) for row in latest)
    assert anchor is not None
    window_start = anchor - timedelta(days=29)
    on_hand = sum((_decimal(row["on_hand_qty"]) for row in latest), Decimal(0))
    shipped = Decimal(0)
    for line in shipped_lines:
        ship_date = _as_date(line.get("ship_date"))
        if ship_date is not None and window_start <= ship_date <= anchor:
            shipped += _decimal(line.get("shipped_qty"))
    if shipped == 0:
        return None
    return on_hand / (shipped / Decimal(30))


def landed_cost(cost_rows: Iterable[Mapping[str, Any]]) -> Decimal:
    """Return product + freight + duty + insurance + handling in USD."""

    components = (
        "product_cost_usd",
        "freight_usd",
        "duty_usd",
        "insurance_usd",
        "handling_usd",
    )
    return sum(
        (_decimal(row.get(component)) for row in cost_rows for component in components),
        Decimal(0),
    )


def canonical_metrics(
    *,
    shipments: Iterable[Mapping[str, Any]],
    order_lines: Iterable[Mapping[str, Any]],
    inventory_snapshots: Iterable[Mapping[str, Any]],
    shipped_lines: Iterable[Mapping[str, Any]],
    landed_costs: Iterable[Mapping[str, Any]],
) -> dict[str, Decimal | None]:
    """Calculate every governed KPI using the documented definitions."""

    return {
        "on_time_delivery_rate": on_time_delivery_rate(shipments),
        "fill_rate": fill_rate(order_lines),
        "days_of_inventory": days_of_inventory(inventory_snapshots, shipped_lines),
        "landed_cost_usd": landed_cost(landed_costs),
    }

