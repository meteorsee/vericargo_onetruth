"""Generate deterministic, referentially consistent supply-chain fixtures."""

from __future__ import annotations

import csv
from collections.abc import Iterable
from pathlib import Path
from typing import Any

SUPPLIERS = [
    {"supplier_id": "SUP-001", "supplier_name": "Nimbus Components", "country": "Malaysia", "risk_tier": "LOW"},
    {"supplier_id": "SUP-002", "supplier_name": "Straits Metals", "country": "Malaysia", "risk_tier": "MEDIUM"},
    {"supplier_id": "SUP-003", "supplier_name": "Hanse Precision", "country": "Germany", "risk_tier": "LOW"},
]

PARTS = [
    {"part_id": "PART-001", "supplier_id": "SUP-001", "part_name": "ECU Control Module", "unit_cost_usd": "120.00"},
    {"part_id": "PART-002", "supplier_id": "SUP-002", "part_name": "Valve Assembly", "unit_cost_usd": "80.00"},
    {"part_id": "PART-003", "supplier_id": "SUP-001", "part_name": "Sensor Kit", "unit_cost_usd": "65.00"},
    {"part_id": "PART-004", "supplier_id": "SUP-003", "part_name": "Precision Housing", "unit_cost_usd": "95.00"},
]

PLANTS = [
    {"plant_id": "PLANT-PEN", "plant_name": "Penang Assembly", "country": "Malaysia"},
    {"plant_id": "PLANT-JHB", "plant_name": "Johor Final Assembly", "country": "Malaysia"},
]

CUSTOMERS = [
    {"customer_id": "CUST-001", "customer_name": "Orion Motors", "country": "Thailand"},
    {"customer_id": "CUST-002", "customer_name": "Pacific Appliances", "country": "Vietnam"},
    {"customer_id": "CUST-003", "customer_name": "Southern Mobility", "country": "Singapore"},
]

PORTS = [
    {"port_code": "MYPEN", "port_name": "Penang", "country": "Malaysia"},
    {"port_code": "MYPKG", "port_name": "Port Klang", "country": "Malaysia"},
    {"port_code": "SGSIN", "port_name": "Singapore", "country": "Singapore"},
    {"port_code": "THLCH", "port_name": "Laem Chabang", "country": "Thailand"},
    {"port_code": "VNSGN", "port_name": "Ho Chi Minh City", "country": "Vietnam"},
]

ORDERS = [
    {"order_id": "ORD-1001", "customer_id": "CUST-001", "plant_id": "PLANT-PEN", "order_date": "2026-08-20", "promised_delivery_date": "2026-09-05", "status": "DELIVERED"},
    {"order_id": "ORD-1002", "customer_id": "CUST-002", "plant_id": "PLANT-PEN", "order_date": "2026-08-23", "promised_delivery_date": "2026-09-09", "status": "DELIVERED"},
    {"order_id": "ORD-1003", "customer_id": "CUST-001", "plant_id": "PLANT-JHB", "order_date": "2026-08-25", "promised_delivery_date": "2026-09-12", "status": "DELIVERED"},
    {"order_id": "ORD-1004", "customer_id": "CUST-003", "plant_id": "PLANT-JHB", "order_date": "2026-09-01", "promised_delivery_date": "2026-09-18", "status": "IN_TRANSIT"},
    {"order_id": "ORD-1005", "customer_id": "CUST-002", "plant_id": "PLANT-PEN", "order_date": "2026-09-05", "promised_delivery_date": "2026-09-20", "status": "DELIVERED"},
    {"order_id": "ORD-1006", "customer_id": "CUST-003", "plant_id": "PLANT-PEN", "order_date": "2026-09-07", "promised_delivery_date": "2026-09-24", "status": "DELIVERED"},
]

ORDER_LINES = [
    {"order_id": "ORD-1001", "line_number": "1", "part_id": "PART-001", "ordered_qty": "100", "shipped_qty": "100"},
    {"order_id": "ORD-1001", "line_number": "2", "part_id": "PART-003", "ordered_qty": "50", "shipped_qty": "45"},
    {"order_id": "ORD-1002", "line_number": "1", "part_id": "PART-002", "ordered_qty": "80", "shipped_qty": "80"},
    {"order_id": "ORD-1003", "line_number": "1", "part_id": "PART-001", "ordered_qty": "120", "shipped_qty": "110"},
    {"order_id": "ORD-1004", "line_number": "1", "part_id": "PART-004", "ordered_qty": "60", "shipped_qty": "60"},
    {"order_id": "ORD-1005", "line_number": "1", "part_id": "PART-003", "ordered_qty": "40", "shipped_qty": "40"},
    {"order_id": "ORD-1005", "line_number": "2", "part_id": "PART-002", "ordered_qty": "70", "shipped_qty": "65"},
    {"order_id": "ORD-1006", "line_number": "1", "part_id": "PART-004", "ordered_qty": "90", "shipped_qty": "90"},
]

SHIPMENTS = [
    {"shipment_id": "SHP-1001", "order_id": "ORD-1001", "supplier_id": "SUP-001", "origin_port_code": "MYPEN", "destination_port_code": "THLCH", "container_id": "CONT-001", "ship_date": "2026-08-29", "promised_delivery_date": "2026-09-05", "actual_delivery_date": "2026-09-04", "status": "DELIVERED"},
    {"shipment_id": "SHP-1002", "order_id": "ORD-1002", "supplier_id": "SUP-002", "origin_port_code": "MYPKG", "destination_port_code": "VNSGN", "container_id": "CONT-002", "ship_date": "2026-09-01", "promised_delivery_date": "2026-09-09", "actual_delivery_date": "2026-09-10", "status": "DELIVERED"},
    {"shipment_id": "SHP-1003", "order_id": "ORD-1003", "supplier_id": "SUP-001", "origin_port_code": "MYPEN", "destination_port_code": "THLCH", "container_id": "CONT-003", "ship_date": "2026-09-03", "promised_delivery_date": "2026-09-12", "actual_delivery_date": "2026-09-12", "status": "DELIVERED"},
    {"shipment_id": "SHP-1004", "order_id": "ORD-1004", "supplier_id": "SUP-003", "origin_port_code": "SGSIN", "destination_port_code": "MYPKG", "container_id": "CONT-004", "ship_date": "2026-09-10", "promised_delivery_date": "2026-09-18", "actual_delivery_date": "", "status": "IN_TRANSIT"},
    {"shipment_id": "SHP-1005", "order_id": "ORD-1005", "supplier_id": "SUP-002", "origin_port_code": "MYPKG", "destination_port_code": "VNSGN", "container_id": "CONT-005", "ship_date": "2026-09-12", "promised_delivery_date": "2026-09-20", "actual_delivery_date": "2026-09-18", "status": "DELIVERED"},
    {"shipment_id": "SHP-1006", "order_id": "ORD-1006", "supplier_id": "SUP-003", "origin_port_code": "SGSIN", "destination_port_code": "MYPEN", "container_id": "CONT-006", "ship_date": "2026-09-15", "promised_delivery_date": "2026-09-24", "actual_delivery_date": "2026-09-25", "status": "DELIVERED"},
]

SHIPMENT_EVENTS = [
    {"event_id": "EVT-001", "shipment_id": "SHP-1001", "event_ts": "2026-09-04T09:15:00", "event_type": "DELIVERED", "location_code": "THLCH", "temperature_c": "25.2"},
    {"event_id": "EVT-002", "shipment_id": "SHP-1002", "event_ts": "2026-09-08T13:10:00", "event_type": "PORT_HOLD", "location_code": "VNSGN", "temperature_c": "31.8"},
    {"event_id": "EVT-003", "shipment_id": "SHP-1002", "event_ts": "2026-09-10T16:45:00", "event_type": "DELIVERED", "location_code": "VNSGN", "temperature_c": "29.1"},
    {"event_id": "EVT-004", "shipment_id": "SHP-1003", "event_ts": "2026-09-12T11:20:00", "event_type": "DELIVERED", "location_code": "THLCH", "temperature_c": "27.0"},
    {"event_id": "EVT-005", "shipment_id": "SHP-1004", "event_ts": "2026-09-17T06:30:00", "event_type": "CUSTOMS_REVIEW", "location_code": "MYPKG", "temperature_c": "24.7"},
    {"event_id": "EVT-006", "shipment_id": "SHP-1005", "event_ts": "2026-09-18T14:00:00", "event_type": "DELIVERED", "location_code": "VNSGN", "temperature_c": "28.8"},
    {"event_id": "EVT-007", "shipment_id": "SHP-1006", "event_ts": "2026-09-23T19:30:00", "event_type": "TRANSSHIPMENT_DELAY", "location_code": "SGSIN", "temperature_c": "30.5"},
    {"event_id": "EVT-008", "shipment_id": "SHP-1006", "event_ts": "2026-09-25T10:05:00", "event_type": "DELIVERED", "location_code": "MYPEN", "temperature_c": "29.4"},
]

INVENTORY_SNAPSHOTS = [
    {"snapshot_date": "2026-08-31", "plant_id": "PLANT-PEN", "part_id": "PART-001", "on_hand_qty": "340"},
    {"snapshot_date": "2026-08-31", "plant_id": "PLANT-PEN", "part_id": "PART-002", "on_hand_qty": "250"},
    {"snapshot_date": "2026-08-31", "plant_id": "PLANT-PEN", "part_id": "PART-003", "on_hand_qty": "190"},
    {"snapshot_date": "2026-08-31", "plant_id": "PLANT-JHB", "part_id": "PART-001", "on_hand_qty": "290"},
    {"snapshot_date": "2026-08-31", "plant_id": "PLANT-JHB", "part_id": "PART-004", "on_hand_qty": "175"},
    {"snapshot_date": "2026-08-31", "plant_id": "PLANT-PEN", "part_id": "PART-004", "on_hand_qty": "205"},
    {"snapshot_date": "2026-09-27", "plant_id": "PLANT-PEN", "part_id": "PART-001", "on_hand_qty": "300"},
    {"snapshot_date": "2026-09-27", "plant_id": "PLANT-PEN", "part_id": "PART-002", "on_hand_qty": "220"},
    {"snapshot_date": "2026-09-27", "plant_id": "PLANT-PEN", "part_id": "PART-003", "on_hand_qty": "170"},
    {"snapshot_date": "2026-09-27", "plant_id": "PLANT-JHB", "part_id": "PART-001", "on_hand_qty": "260"},
    {"snapshot_date": "2026-09-27", "plant_id": "PLANT-JHB", "part_id": "PART-004", "on_hand_qty": "150"},
    {"snapshot_date": "2026-09-27", "plant_id": "PLANT-PEN", "part_id": "PART-004", "on_hand_qty": "180"},
]

LANDED_COSTS = [
    {"shipment_id": "SHP-1001", "product_cost_usd": "14925.00", "freight_usd": "900.00", "duty_usd": "1492.50", "insurance_usd": "150.00", "handling_usd": "100.00"},
    {"shipment_id": "SHP-1002", "product_cost_usd": "6400.00", "freight_usd": "700.00", "duty_usd": "640.00", "insurance_usd": "80.00", "handling_usd": "100.00"},
    {"shipment_id": "SHP-1003", "product_cost_usd": "13200.00", "freight_usd": "950.00", "duty_usd": "1320.00", "insurance_usd": "130.00", "handling_usd": "100.00"},
    {"shipment_id": "SHP-1004", "product_cost_usd": "5700.00", "freight_usd": "800.00", "duty_usd": "570.00", "insurance_usd": "75.00", "handling_usd": "90.00"},
    {"shipment_id": "SHP-1005", "product_cost_usd": "7800.00", "freight_usd": "750.00", "duty_usd": "780.00", "insurance_usd": "90.00", "handling_usd": "100.00"},
    {"shipment_id": "SHP-1006", "product_cost_usd": "8550.00", "freight_usd": "850.00", "duty_usd": "855.00", "insurance_usd": "95.00", "handling_usd": "100.00"},
]

DOCUMENT_SCENARIOS = [
    {"shipment_id": "SHP-1001", "expected_outcome": "MATCH"},
    {"shipment_id": "SHP-1002", "expected_outcome": "MISMATCH"},
    {"shipment_id": "SHP-1003", "expected_outcome": "MISSING_DOCUMENT"},
    {"shipment_id": "SHP-1004", "expected_outcome": "UNREADABLE"},
    {"shipment_id": "SHP-1005", "expected_outcome": "MATCH"},
    {"shipment_id": "SHP-1006", "expected_outcome": "AMBIGUOUS"},
]


def _write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def _pdf_bytes(lines: Iterable[str]) -> bytes:
    """Build a small valid one-page PDF using only the Python standard library."""

    escaped_lines = [
        str(line).replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
        for line in lines
    ]
    commands = ["BT", "/F1 11 Tf", "50 790 Td"]
    for index, line in enumerate(escaped_lines):
        if index:
            commands.append("0 -18 Td")
        commands.append(f"({line}) Tj")
    commands.append("ET")
    stream = "\n".join(commands).encode("ascii")
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        b"<< /Length " + str(len(stream)).encode("ascii") + b" >>\nstream\n" + stream + b"\nendstream",
    ]
    payload = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for number, obj in enumerate(objects, start=1):
        offsets.append(len(payload))
        payload.extend(f"{number} 0 obj\n".encode("ascii"))
        payload.extend(obj)
        payload.extend(b"\nendobj\n")
    xref_offset = len(payload)
    payload.extend(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
    payload.extend(b"0000000000 65535 f \n")
    for offset in offsets[1:]:
        payload.extend(f"{offset:010d} 00000 n \n".encode("ascii"))
    payload.extend(
        f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref_offset}\n%%EOF\n".encode(
            "ascii"
        )
    )
    return bytes(payload)


def _document_lines(
    *,
    title: str,
    shipment_id: str,
    shipper: str,
    consignee: str,
    notify_party: str,
    pol: str,
    pod: str,
    container_count: str,
    gross_weight: str,
) -> list[str]:
    return [
        title,
        f"Shipment ID: {shipment_id}",
        f"Shipper: {shipper}",
        f"Consignee: {consignee}",
        f"Notify Party: {notify_party}",
        f"Port of Loading: {pol}",
        f"Port of Discharge: {pod}",
        f"Container Count: {container_count}",
        f"Gross Weight: {gross_weight}",
        "SYNTHETIC HACKATHON DOCUMENT - NOT FOR COMMERCIAL USE",
    ]


def _write_documents(output_dir: Path) -> list[dict[str, str]]:
    documents_dir = output_dir / "documents"
    documents_dir.mkdir(parents=True, exist_ok=True)
    manifest: list[dict[str, str]] = []

    scenarios = {
        "SHP-1001": ("Nimbus Components", "Orion Motors", "Orion Logistics", "Penang / MYPEN", "Laem Chabang / THLCH", "1 x 40HC", "10,000 KG"),
        "SHP-1002": ("Straits Metals", "Pacific Appliances", "Pacific Import Desk", "Port Klang / MYPKG", "Ho Chi Minh City / VNSGN", "1 container", "8 MT"),
        "SHP-1003": ("Nimbus Components", "Orion Motors", "Orion Logistics", "Penang / MYPEN", "Laem Chabang / THLCH", "1 container", "12,000 KGS"),
        "SHP-1004": ("Hanse Precision", "Southern Mobility", "Southern Mobility Ops", "Singapore / SGSIN", "Port Klang / MYPKG", "1 container", "6 tonnes"),
        "SHP-1005": ("Straits Metals", "Pacific Appliances", "Pacific Import Desk", "Port Klang / MYPKG", "Cat Lai / VNSGN", "1 x 20GP", "7,000 KG"),
        "SHP-1006": ("Hanse Precision", "Southern Mobility", "Southern Mobility Ops", "Singapore / SGSIN", "Penang / MYPEN", "1 container", "9,000 KG"),
    }

    def add_pdf(document_id: str, shipment_id: str, doc_type: str, lines: list[str]) -> None:
        filename = f"{document_id.lower()}.pdf"
        (documents_dir / filename).write_bytes(_pdf_bytes(lines))
        manifest.append(
            {
                "document_id": document_id,
                "shipment_id": shipment_id,
                "document_type": doc_type,
                "relative_path": filename,
            }
        )

    for shipment_id, values in scenarios.items():
        si_lines = _document_lines(
            title="SHIPPING INSTRUCTION",
            shipment_id=shipment_id,
            shipper=values[0],
            consignee=values[1],
            notify_party=values[2],
            pol=values[3],
            pod=values[4],
            container_count=values[5],
            gross_weight=values[6],
        )
        add_pdf(f"DOC-{shipment_id}-SI", shipment_id, "SI", si_lines)

        if shipment_id == "SHP-1003":
            continue
        if shipment_id == "SHP-1004":
            filename = f"doc-{shipment_id.lower()}-bl.pdf"
            (documents_dir / filename).write_bytes(b"%PDF-1.4\nCORRUPTED SYNTHETIC FIXTURE")
            manifest.append(
                {
                    "document_id": f"DOC-{shipment_id}-BL",
                    "shipment_id": shipment_id,
                    "document_type": "DRAFT_BL",
                    "relative_path": filename,
                }
            )
            continue

        bl_values = list(values)
        if shipment_id == "SHP-1002":
            bl_values[4] = "Laem Chabang / THLCH"
            bl_values[6] = "7,800 KG"
        elif shipment_id == "SHP-1001":
            bl_values[5] = "1 container"
            bl_values[6] = "10 MT"
        elif shipment_id == "SHP-1005":
            bl_values[4] = "Ho Chi Minh City / VNSGN"
            bl_values[6] = "7 MT"
        bl_lines = _document_lines(
            title="DRAFT BILL OF LADING",
            shipment_id=shipment_id,
            shipper=bl_values[0],
            consignee=bl_values[1],
            notify_party=bl_values[2],
            pol=bl_values[3],
            pod=bl_values[4],
            container_count=bl_values[5],
            gross_weight=bl_values[6],
        )
        add_pdf(f"DOC-{shipment_id}-BL", shipment_id, "DRAFT_BL", bl_lines)

        if shipment_id == "SHP-1006":
            alternate = _document_lines(
                title="SHIPPING INSTRUCTION - REVISION B",
                shipment_id=shipment_id,
                shipper=values[0],
                consignee=values[1],
                notify_party="Alternate Notify Desk",
                pol=values[3],
                pod=values[4],
                container_count=values[5],
                gross_weight=values[6],
            )
            add_pdf("DOC-SHP-1006-SI-B", shipment_id, "SI", alternate)

    return manifest


def generate_dataset(output_dir: str | Path) -> dict[str, list[dict[str, Any]]]:
    output_path = Path(output_dir)
    datasets = {
        "suppliers": SUPPLIERS,
        "parts": PARTS,
        "plants": PLANTS,
        "customers": CUSTOMERS,
        "ports": PORTS,
        "orders": ORDERS,
        "order_lines": ORDER_LINES,
        "shipments": SHIPMENTS,
        "shipment_events": SHIPMENT_EVENTS,
        "inventory_snapshots": INVENTORY_SNAPSHOTS,
        "landed_costs": LANDED_COSTS,
        "document_scenarios": DOCUMENT_SCENARIOS,
    }
    for name, rows in datasets.items():
        _write_csv(output_path / f"{name}.csv", rows)
    manifest = _write_documents(output_path)
    _write_csv(output_path / "document_manifest.csv", manifest)
    return {**datasets, "document_manifest": manifest}


def shipped_lines_with_dates() -> list[dict[str, Any]]:
    shipment_by_order = {row["order_id"]: row for row in SHIPMENTS}
    order_by_id = {row["order_id"]: row for row in ORDERS}
    return [
        {
            **line,
            "plant_id": order_by_id[line["order_id"]]["plant_id"],
            "ship_date": shipment_by_order[line["order_id"]]["ship_date"],
        }
        for line in ORDER_LINES
    ]

