"""Deterministic SI and Draft BL normalization and comparison."""

from __future__ import annotations

import re
import unicodedata
from collections.abc import Mapping
from decimal import Decimal, InvalidOperation
from typing import Any

FIELDS = (
    "shipper",
    "consignee",
    "notify_party",
    "port_of_loading",
    "port_of_discharge",
    "container_count",
    "gross_weight",
)

PORT_ALIASES = {
    "SINGAPORE": "SGSIN",
    "SINGAPORE PORT": "SGSIN",
    "SGSIN": "SGSIN",
    "PENANG": "MYPEN",
    "PENANG PORT": "MYPEN",
    "MYPEN": "MYPEN",
    "PORT KLANG": "MYPKG",
    "KLANG": "MYPKG",
    "MYPKG": "MYPKG",
    "LAEM CHABANG": "THLCH",
    "THLCH": "THLCH",
    "HO CHI MINH CITY": "VNSGN",
    "HO CHI MINH": "VNSGN",
    "CAT LAI": "VNSGN",
    "VNSGN": "VNSGN",
    "BUSAN": "KRPUS",
    "PUSAN": "KRPUS",
    "KRPUS": "KRPUS",
}


def normalize_text(value: Any) -> str | None:
    if value is None:
        return None
    normalized = unicodedata.normalize("NFKD", str(value))
    normalized = "".join(char for char in normalized if not unicodedata.combining(char))
    normalized = re.sub(r"[^A-Za-z0-9]+", " ", normalized).strip().upper()
    return normalized or None


def normalize_port(value: Any) -> str | None:
    text = normalize_text(value)
    if text is None:
        return None
    for alias, code in PORT_ALIASES.items():
        if re.search(rf"\b{re.escape(alias)}\b", text):
            return code
    return text


def normalize_container_count(value: Any) -> int | None:
    text = normalize_text(value)
    if text is None:
        return None
    match = re.search(r"\d+", text)
    return int(match.group()) if match else None


def normalize_weight_kg(value: Any) -> Decimal | None:
    if value is None:
        return None
    text = str(value).strip().upper().replace(",", "")
    match = re.search(r"(-?\d+(?:\.\d+)?)", text)
    if not match:
        return None
    try:
        amount = Decimal(match.group(1))
    except InvalidOperation:
        return None
    if amount < 0:
        return None
    if re.search(r"\b(LB|LBS|POUND|POUNDS)\b", text):
        return amount * Decimal("0.45359237")
    if re.search(r"\b(MT|TON|TONS|TONNE|TONNES)\b", text):
        return amount * Decimal(1000)
    return amount


def normalize_field(field: str, value: Any) -> str | int | Decimal | None:
    if field in {"port_of_loading", "port_of_discharge"}:
        return normalize_port(value)
    if field == "container_count":
        return normalize_container_count(value)
    if field == "gross_weight":
        return normalize_weight_kg(value)
    return normalize_text(value)


def compare_value(field: str, left: Any, right: Any) -> str:
    left_normalized = normalize_field(field, left)
    right_normalized = normalize_field(field, right)
    if left_normalized is None or right_normalized is None:
        return "UNRESOLVED"
    if field == "gross_weight":
        left_weight = Decimal(left_normalized)
        right_weight = Decimal(right_normalized)
        tolerance = max(Decimal("0.5"), left_weight * Decimal("0.001"))
        return "MATCH" if abs(left_weight - right_weight) <= tolerance else "MISMATCH"
    return "MATCH" if left_normalized == right_normalized else "MISMATCH"


def compare_documents(
    shipping_instruction: Mapping[str, Any],
    draft_bill_of_lading: Mapping[str, Any],
) -> dict[str, Any]:
    fields: dict[str, dict[str, Any]] = {}
    for field in FIELDS:
        left = shipping_instruction.get(field)
        right = draft_bill_of_lading.get(field)
        fields[field] = {
            "si_raw": left,
            "draft_bl_raw": right,
            "si_normalized": normalize_field(field, left),
            "draft_bl_normalized": normalize_field(field, right),
            "status": compare_value(field, left, right),
        }
    statuses = {result["status"] for result in fields.values()}
    overall = "MISMATCH" if "MISMATCH" in statuses else (
        "NEEDS_REVIEW" if "UNRESOLVED" in statuses else "MATCH"
    )
    return {"overall_status": overall, "fields": fields}

