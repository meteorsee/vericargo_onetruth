"""Reusable presentation and navigation helpers for VeriCargo OneTruth."""

from __future__ import annotations

from collections.abc import Iterable
from html import escape
from typing import Any

import pandas as pd
import streamlit as st

STATUS_ICONS = {
    "MATCH": "✓",
    "NORMAL": "✓",
    "HEALTHY": "✓",
    "GOVERNED": "✓",
    "ENFORCED": "✓",
    "PARSED": "✓",
    "RESOLVED": "✓",
    "MISMATCH": "×",
    "CRITICAL": "×",
    "FAILED": "×",
    "MISSING": "!",
    "ATTENTION": "!",
    "HIGH": "!",
    "WARNING": "!",
    "UNRESOLVED": "?",
    "LOW_CONFIDENCE": "?",
    "PENDING": "○",
    "IN_REVIEW": "◐",
    "REJECTED": "×",
    "LOW": "✓",
    "MEDIUM": "!",
}


def labelled_status(value: object) -> str:
    """Return one consistent text-and-symbol status label."""

    text = str(value or "UNKNOWN").upper()
    return f"{STATUS_ICONS.get(text, '•')} {text.replace('_', ' ').title()}"


def humanize(value: object) -> str:
    """Convert a machine identifier into a compact display label."""

    if value is None or (isinstance(value, float) and pd.isna(value)):
        return "Unavailable"
    text = str(value).strip()
    return text.replace("_", " ").title() if text else "Unavailable"


def format_confidence(value: object) -> str:
    if value is None or pd.isna(value):
        return "Unavailable"
    return f"{float(value):.0%}"


def go_to(page: str) -> None:
    st.session_state.current_page = page
    st.rerun()


def open_context(
    page: str,
    shipment_id: str | None = None,
    question: str | None = None,
    case_id: str | None = None,
) -> None:
    """Carry the active investigation context into another page."""

    if shipment_id:
        st.session_state.selected_shipment_id = shipment_id
        st.session_state.pop("review_proposal", None)
        st.session_state.pop("pending_review_action", None)
    if question:
        st.session_state.copilot_question = question
        st.session_state.last_copilot_question = question
    if case_id:
        st.session_state.selected_case_id = case_id
    st.session_state.current_page = page


def render_hero() -> None:
    st.markdown(
        """
        <section class="onetruth-hero">
          <div class="eyebrow">VERICARGO ONETRUTH</div>
          <h1>One shipment. Two destinations. One governed truth.</h1>
          <p>Detect contradictions across operational records and shipping documents,
          explain them with evidence, and turn them into human-confirmed, auditable action.</p>
        </section>
        """,
        unsafe_allow_html=True,
    )


def _evidence_row(evidence: pd.DataFrame, field_name: str) -> pd.Series | None:
    if evidence.empty or "FIELD_NAME" not in evidence:
        return None
    match = evidence[evidence["FIELD_NAME"] == field_name]
    return None if match.empty else match.iloc[0]


def _evidence_value(row: pd.Series | None, side: str) -> tuple[str, str, str]:
    if row is None:
        return "Unavailable", "Unavailable", "Unavailable"
    raw = row.get(f"{side}_VALUE")
    normalized = row.get(f"NORMALIZED_{side}")
    source = row.get(f"{side}_SOURCE")
    return (
        "Unavailable" if pd.isna(raw) else str(raw),
        "Unavailable" if pd.isna(normalized) else str(normalized),
        "Unavailable" if pd.isna(source) else str(source),
    )


def _delivery_summary(shipment: pd.Series) -> str:
    days_late = int(shipment.get("DELIVERY_DAYS_LATE") or 0)
    status = str(shipment.get("STATUS") or "").upper()
    actual = shipment.get("ACTUAL_DELIVERY_DATE")
    actual_missing = actual is None or pd.isna(actual)
    if actual_missing and status != "DELIVERED":
        if days_late > 0:
            return f"{days_late} day{'s' if days_late != 1 else ''} past promise"
        return "In transit"
    if days_late > 0:
        return f"{days_late} day{'s' if days_late != 1 else ''} late"
    if days_late < 0:
        days_early = abs(days_late)
        return f"{days_early} day{'s' if days_early != 1 else ''} early"
    return "On time"


def render_decision_brief(
    shipment: pd.Series,
    evidence: pd.DataFrame,
    findings: pd.DataFrame,
    *,
    show_investigate_action: bool = True,
) -> None:
    """Render the full evidence-backed brief for one shipment."""

    shipment_id = str(shipment["SHIPMENT_ID"])
    destination = _evidence_row(evidence, "PORT_OF_DISCHARGE")
    weight = _evidence_row(evidence, "GROSS_WEIGHT_KG")
    si_destination, si_destination_norm, si_source = _evidence_value(destination, "SI")
    bl_destination, bl_destination_norm, bl_source = _evidence_value(destination, "BL")
    si_weight, si_weight_norm, _ = _evidence_value(weight, "SI")
    bl_weight, bl_weight_norm, _ = _evidence_value(weight, "BL")
    risk = humanize(shipment.get("RISK_SEVERITY"))
    exception_count = len(findings)
    document_outcome = str(shipment.get("DOCUMENT_OUTCOME") or "UNRESOLVED").upper()
    document_state = {
        "MATCH": "document evidence aligned",
        "MISMATCH": "conflicting document evidence",
        "MISSING": "required document missing",
        "UNRESOLVED": "document evidence unresolved",
    }.get(document_outcome, "document status unavailable")
    gate_decision = {
        "MATCH": "CLEAR · documents aligned",
        "MISMATCH": "HOLD · correction required",
        "MISSING": "UNRESOLVED · document missing",
        "UNRESOLVED": "UNRESOLVED · human check required",
    }.get(document_outcome, "UNRESOLVED · status unavailable")
    origin = shipment.get("ORIGIN_PORT_NAME", shipment.get("ORIGIN_PORT_CODE"))
    destination_name = shipment.get(
        "DESTINATION_PORT_NAME", shipment.get("DESTINATION_PORT_CODE")
    )
    attention_state = "ATTENTION" if exception_count else "HEALTHY"
    review_message = (
        "Human confirmation required  \nNo write before confirmation"
        if exception_count
        else "No open finding  \nNo review action required"
    )
    copilot_question = (
        f"Why is {shipment_id} in exception? Cite the available source filenames."
        if exception_count
        else f"Summarize {shipment_id} and explain why it has no open exception. Cite the available source filenames."
    )

    with st.container(border=True):
        header, status = st.columns([4, 1])
        header.subheader(f"{shipment_id} · Decision Brief")
        header.caption(f"{origin} → {destination_name} · {document_state}")
        status.markdown(f"**{labelled_status(attention_state)}**")

        operational, shipping_instruction, draft_bl, governed = st.columns(4)
        operational.markdown("**Operational finding**")
        operational.metric("Delivery", _delivery_summary(shipment))
        operational.caption(
            f"Promised {shipment.get('PROMISED_DELIVERY_DATE')}  \n"
            f"Actual {shipment.get('ACTUAL_DELIVERY_DATE')}"
        )

        shipping_instruction.markdown("**Shipping Instruction**")
        shipping_instruction.markdown(f"**{escape(si_destination)}**")
        shipping_instruction.caption(
            f"Normalized destination: {escape(si_destination_norm)}  \n"
            f"Weight: {escape(si_weight)} → {escape(si_weight_norm)} KG  \n"
            f"Source: {escape(si_source)}"
        )

        draft_bl.markdown("**Draft Bill of Lading**")
        draft_bl.markdown(f"**{escape(bl_destination)}**")
        draft_bl.caption(
            f"Normalized destination: {escape(bl_destination_norm)}  \n"
            f"Weight: {escape(bl_weight)} → {escape(bl_weight_norm)} KG  \n"
            f"Source: {escape(bl_source)}"
        )

        governed.markdown("**Governed result**")
        governed.markdown(f"**{gate_decision}**")
        governed.metric("Risk", risk)
        governed.caption(
            f"{exception_count} linked finding(s)  \n"
            f"{review_message}"
        )

        actions = st.columns(3 if show_investigate_action else 2)
        action_index = 0
        if show_investigate_action:
            actions[action_index].button(
                "Investigate shipment →",
                type="primary",
                width="stretch",
                on_click=open_context,
                args=("Shipment Intelligence", shipment_id),
            )
            action_index += 1
        actions[action_index].button(
            "View source evidence",
            width="stretch",
            on_click=open_context,
            args=("Document Evidence", shipment_id),
        )
        actions[action_index + 1].button(
            "Ask OneTruth",
            type="primary" if not show_investigate_action else "secondary",
            width="stretch",
            on_click=open_context,
            args=(
                "OneTruth Copilot",
                shipment_id,
                copilot_question,
            ),
        )


def render_selected_shipment_preview(
    shipment: pd.Series,
    findings: pd.DataFrame,
) -> None:
    """Render a compact shipment-scoped preview beneath portfolio analytics."""

    shipment_id = str(shipment["SHIPMENT_ID"])
    exception_count = len(findings)
    with st.container(border=True):
        heading, action = st.columns([4, 1])
        heading.subheader(f"{shipment_id} · Selected shipment")
        heading.caption(
            f"{shipment.get('ORIGIN_PORT_CODE')} → {shipment.get('DESTINATION_PORT_CODE')} · "
            "This preview follows the active shipment context."
        )
        action.button(
            "Investigate →",
            type="primary",
            width="stretch",
            on_click=open_context,
            args=("Shipment Intelligence", shipment_id),
        )

        delivery, documents, risk, exceptions = st.columns(4)
        delivery.metric("Delivery", _delivery_summary(shipment))
        documents.metric("Documents", humanize(shipment.get("DOCUMENT_OUTCOME")))
        risk.metric("Risk", humanize(shipment.get("RISK_SEVERITY")))
        exceptions.metric("Open findings", exception_count)
        st.caption(
            "Shipment-specific values change with the active context. "
            "Open Shipment Intelligence for the full evidence-backed Decision Brief."
        )


def render_shipment_header(shipment: pd.Series, review_status: str | None) -> None:
    with st.container(border=True):
        title, risk, delivery, review = st.columns([2, 1, 1, 1])
        title.subheader(str(shipment["SHIPMENT_ID"]))
        title.caption(
            f"{shipment.get('ORIGIN_PORT_CODE')} → {shipment.get('DESTINATION_PORT_CODE')} · "
            f"{shipment.get('SUPPLIER_NAME')}"
        )
        risk.metric("Risk", labelled_status(shipment.get("RISK_SEVERITY")))
        delivery.metric("Delivery", _delivery_summary(shipment))
        review.metric(
            "Review",
            labelled_status(review_status or "PENDING") if review_status else "Not created",
        )


def render_process_trace(steps: Iterable[tuple[str, str, str]]) -> None:
    """Render a compact sequence of actual workflow state."""

    items = list(steps)
    for start in range(0, len(items), 3):
        group = items[start:start + 3]
        columns = st.columns(len(group))
        for column, (label, state, detail) in zip(columns, group):
            with column.container(border=True):
                st.markdown(f"**{labelled_status(state)}**")
                st.markdown(f"**{label}**")
                st.caption(detail)


def render_confirmation_boundary(proposal: dict[str, Any]) -> None:
    with st.container(border=True):
        st.subheader("Review action · human confirmation boundary")
        st.warning("The Copilot has not written anything. This proposal is still read-only.")
        shipment, links, severity, status = st.columns(4)
        shipment.metric("Shipment", proposal.get("shipment_id", "Unavailable"))
        links.metric("Linked exceptions", len(proposal.get("exception_ids", [])))
        severity.metric("Severity", labelled_status(proposal.get("severity")))
        status.metric("Initial status", labelled_status("PENDING"))
        st.caption(
            "Confirming records the current Snowflake user, timestamp, shipment, linked "
            "exceptions, reason, and initiating question in the governed workflow."
        )


def render_audit_timeline(audit: pd.DataFrame, current_status: str | None = None) -> None:
    if audit.empty:
        st.info("No audit events exist for this case yet.")
        return
    ordered = audit.sort_values("EVENT_AT")
    columns = st.columns(len(ordered))
    for column, (_, event) in zip(columns, ordered.iterrows()):
        with column:
            target = event.get("TO_STATUS") or event.get("EVENT_TYPE")
            st.markdown(f"**{labelled_status(target)}**")
            st.markdown(f"**{humanize(event.get('EVENT_TYPE'))}**")
            st.caption(f"{event.get('ACTOR')}  \n{event.get('EVENT_AT')}")
    if current_status:
        st.caption(f"Current lifecycle state: {labelled_status(current_status)}")


def render_empty_state(title: str, guidance: str) -> None:
    with st.container(border=True):
        st.info(f"**{title}**\n\n{guidance}")


def render_error_state(title: str, guidance: str) -> None:
    with st.container(border=True):
        st.error(f"**{title}**\n\n{guidance}")


def next_step_buttons(include_review: bool = True, key_prefix: str = "next") -> None:
    labels = [
        ("📄 Inspect evidence", "Document Evidence"),
        ("✨ Ask OneTruth", "OneTruth Copilot"),
    ]
    if include_review:
        labels.append(("🧑‍⚖️ Open review", "Human Review"))
    columns = st.columns(len(labels))
    for index, (label, page) in enumerate(labels):
        columns[index].button(
            label,
            key=f"{key_prefix}_{page}",
            width="stretch",
            on_click=open_context,
            args=(page, st.session_state.get("selected_shipment_id")),
        )
