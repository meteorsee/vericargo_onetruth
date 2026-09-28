"""Pure-Python mirror of the governed MVP risk thresholds used in Snowflake."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class RiskResult:
    delivery: int
    documents: int
    inventory: int
    cost: int
    data_quality: int
    overall: int
    severity: str


def calculate_risk(
    *,
    days_late: int,
    document_outcome: str,
    document_reason: str,
    days_of_inventory: float | None,
    landed_cost: float,
    route_average_cost: float,
) -> RiskResult:
    """Apply the centrally documented MVP_V1 policy without probabilistic inference."""

    delivery = 30 if days_late > 3 else 15 if days_late > 0 else 0
    documents = {"MISMATCH": 30, "MISSING": 25, "UNRESOLVED": 20}.get(
        document_outcome.upper(), 0
    )
    inventory = (
        0
        if days_of_inventory is None
        else 15
        if days_of_inventory < 15
        else 8
        if days_of_inventory < 30
        else 0
    )
    ratio = landed_cost / route_average_cost if route_average_cost > 0 else 0
    cost = 15 if ratio > 1.20 else 8 if ratio > 1.10 else 0
    data_quality = (
        10
        if document_reason.upper() in {"PARSE_FAILURE", "LOW_CONFIDENCE", "AMBIGUOUS_PAIR"}
        else 0
    )
    overall = min(100, delivery + documents + inventory + cost + data_quality)
    severity = "CRITICAL" if overall >= 75 else "HIGH" if overall >= 50 else "MEDIUM" if overall >= 25 else "LOW"
    return RiskResult(delivery, documents, inventory, cost, data_quality, overall, severity)
