"""VeriCargo OneTruth decision-first control tower for Streamlit in Snowflake."""

from __future__ import annotations

from typing import Any

import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session

from components import (
    format_confidence,
    humanize,
    labelled_status,
    next_step_buttons,
    open_context,
    render_audit_timeline,
    render_confirmation_boundary,
    render_decision_brief,
    render_empty_state,
    render_error_state,
    render_hero,
    render_process_trace,
    render_shipment_header,
)
from services import OneTruthService, agent_text

st.set_page_config(page_title="VeriCargo OneTruth", page_icon="🚢", layout="wide")
st.markdown(
    """
    <style>
      .block-container {padding-top: 1.2rem; padding-bottom: 3rem; max-width: 1500px;}
      [data-testid="stMetric"] {
        border: 1px solid #26364a;
        border-radius: 12px;
        padding: .75rem;
        min-height: 104px;
      }
      .context {color: #8bc5ff; font-weight: 650; margin-bottom: .5rem;}
      div.stButton > button {border-radius: 8px; min-height: 2.55rem;}
      .onetruth-hero {
        padding: 1.3rem 1.5rem;
        margin-bottom: 1rem;
        border: 1px solid #2f5275;
        border-radius: 16px;
        background: linear-gradient(115deg, rgba(14,42,66,.96), rgba(20,25,34,.96));
      }
      .onetruth-hero .eyebrow {
        color: #7ec8ff;
        font-size: .76rem;
        font-weight: 750;
        letter-spacing: .16em;
      }
      .onetruth-hero h1 {font-size: clamp(1.7rem, 3vw, 2.7rem); margin: .25rem 0 .45rem;}
      .onetruth-hero p {max-width: 850px; color: #c7d6e5; margin: 0; font-size: 1.02rem;}
      [data-testid="stDataFrame"] {border: 1px solid #26364a; border-radius: 10px;}
      @media (max-width: 900px) {
        .block-container {padding-left: 1rem; padding-right: 1rem;}
        .onetruth-hero {padding: 1rem;}
      }
    </style>
    """,
    unsafe_allow_html=True,
)

service = OneTruthService(get_active_session())

STATE_DEFAULTS: dict[str, Any] = {
    "current_page": "Control Tower",
    "selected_shipment_id": "SHP-1002",
    "shipment_context_selector": "SHP-1002",
    "selected_exception_id": None,
    "selected_document_field": None,
    "pending_review_action": None,
    "last_copilot_question": "",
    "last_copilot_response": None,
    "last_copilot_shipment_id": None,
    "last_created_case_id": None,
    "last_action_message": None,
    "selected_case_id": None,
}
for state_key, default_value in STATE_DEFAULTS.items():
    st.session_state.setdefault(state_key, default_value)


def navigate(page: str) -> None:
    st.session_state.current_page = page


def nav_button(label: str, page: str) -> None:
    st.button(
        label,
        key=f"nav_{page}",
        width="stretch",
        type="primary" if st.session_state.current_page == page else "secondary",
        on_click=navigate,
        args=(page,),
    )


def update_shipment_context() -> None:
    st.session_state.selected_shipment_id = st.session_state.shipment_context_selector
    st.session_state.selected_document_field = None
    st.session_state.selected_exception_id = None
    st.session_state.pop("review_proposal", None)
    st.session_state.pending_review_action = None


def page_header(title: str, description: str) -> None:
    st.title(title)
    st.caption(description)


def value_or_unavailable(value: object) -> str:
    return "Unavailable" if value is None or pd.isna(value) else str(value)


def technical_details(exc: Exception) -> None:
    with st.expander("Technical details"):
        st.code(f"{type(exc).__name__}: {exc}")


with st.sidebar:
    st.title("🚢 OneTruth")
    st.caption("From conflicting data to one governed decision")
    try:
        shipment_ids = service.shipment_ids()
    except Exception as exc:  # noqa: BLE001
        shipment_ids = []
        st.error("Shipment context is temporarily unavailable. Refresh after the warehouse is ready.")
        technical_details(exc)
    if shipment_ids:
        current = st.session_state.selected_shipment_id
        if current not in shipment_ids:
            current = shipment_ids[0]
            st.session_state.selected_shipment_id = current
        if st.session_state.shipment_context_selector not in shipment_ids:
            st.session_state.shipment_context_selector = current
        selected = st.selectbox(
            "Active shipment context",
            shipment_ids,
            key="shipment_context_selector",
            on_change=update_shipment_context,
        )
        st.markdown(f'<div class="context">Context: {selected}</div>', unsafe_allow_html=True)

    st.caption("OVERVIEW")
    nav_button("📊 Control Tower", "Control Tower")
    st.caption("INVESTIGATE")
    nav_button("🚚 Shipment Intelligence", "Shipment Intelligence")
    nav_button("📄 Document Evidence", "Document Evidence")
    st.caption("INTELLIGENCE")
    nav_button("✨ OneTruth Copilot", "OneTruth Copilot")
    st.caption("OPERATIONS")
    nav_button("🧑‍⚖️ Human Review", "Human Review")
    st.caption("SYSTEM")
    nav_button("🛡️ Governance", "Governance")
    st.divider()
    if st.button("↻ Refresh data", width="stretch"):
        st.cache_data.clear()
        st.rerun()
    st.caption("USD only · evidence required · explicit confirmation")


def control_tower_page() -> None:
    render_hero()
    data = service.control_tower()
    if data.empty:
        render_empty_state(
            "No portfolio data is available",
            "Run the governed data pipeline, then use Refresh data. No metric has been inferred.",
        )
        return

    target = data[data["SHIPMENT_ID"] == "SHP-1002"]
    decision_row = (target if not target.empty else data.sort_values("ATTENTION_RANK")).iloc[0]
    decision_id = str(decision_row["SHIPMENT_ID"])
    evidence = service.document_evidence(decision_id)
    findings = service.exceptions(decision_id)
    render_decision_brief(decision_row, evidence, findings)

    st.subheader("Canonical portfolio metrics")
    st.caption("Each definition lives once in the governed marts and native semantic view.")
    row = data.iloc[0]
    cards = st.columns(6)
    cards[0].metric("On-time delivery", f"{float(row['ON_TIME_DELIVERY_RATE']):.1%}")
    cards[1].metric("Fill rate", f"{float(row['FILL_RATE']):.1%}")
    cards[2].metric("Days of inventory", f"{float(row['PORTFOLIO_DAYS_OF_INVENTORY']):.1f}")
    cards[3].metric("Landed cost", f"{float(row['PORTFOLIO_LANDED_COST_USD']):,.0f} USD")
    cards[4].metric("Delayed shipments", int(row["DELAYED_SHIPMENT_COUNT"]))
    cards[5].metric("Open exceptions", int(row["EXCEPTION_COUNT"]))

    trend_column, severity_column = st.columns(2)
    delivered = data[data["DELIVERED_FLAG"] == 1].copy()
    if not delivered.empty:
        trend = (
            delivered.groupby("SHIP_DATE", as_index=False)["ON_TIME_DELIVERED_FLAG"]
            .mean()
            .rename(columns={"ON_TIME_DELIVERED_FLAG": "ON_TIME_RATE"})
        )
        trend_column.subheader("On-time delivery trend")
        trend_column.line_chart(trend, x="SHIP_DATE", y="ON_TIME_RATE")
    severity = data.groupby("RISK_SEVERITY", as_index=False).size()
    severity_column.subheader("Shipments by risk severity")
    severity_column.bar_chart(severity, x="RISK_SEVERITY", y="size")

    st.subheader("Highest-risk shipments")
    risk_chart = (
        data[["SHIPMENT_ID", "OVERALL_RISK_SCORE"]]
        .sort_values("OVERALL_RISK_SCORE", ascending=False)
        .head(6)
    )
    st.bar_chart(risk_chart, x="SHIPMENT_ID", y="OVERALL_RISK_SCORE", horizontal=True)

    st.subheader("Shipments requiring attention")
    attention = data[
        [
            "ATTENTION_RANK",
            "SHIPMENT_ID",
            "STATUS",
            "RISK_SEVERITY",
            "OVERALL_RISK_SCORE",
            "OPEN_EXCEPTION_COUNT",
            "DOCUMENT_OUTCOME",
            "ATTENTION_REASON",
        ]
    ].copy()
    attention["RISK_SEVERITY"] = attention["RISK_SEVERITY"].map(labelled_status)
    attention["DOCUMENT_OUTCOME"] = attention["DOCUMENT_OUTCOME"].map(labelled_status)
    st.dataframe(attention, width="stretch", hide_index=True)
    ids = data["SHIPMENT_ID"].tolist()
    current = st.session_state.selected_shipment_id
    chosen = st.selectbox(
        "Select a shipment to investigate",
        ids,
        index=ids.index(current) if current in ids else 0,
        key="control_tower_shipment",
    )
    st.button(
        "Open Shipment Intelligence →",
        type="primary",
        on_click=open_context,
        args=("Shipment Intelligence", chosen),
    )


def shipment_page() -> None:
    shipment_id = st.session_state.selected_shipment_id
    page_header("Shipment Intelligence", f"360° governed investigation · context {shipment_id}")
    data = service.shipment(shipment_id)
    if data.empty:
        render_error_state(
            f"Shipment {shipment_id} was not found",
            "Choose a known shipment from the sidebar. No substitute shipment has been selected.",
        )
        return

    row = data.iloc[0]
    shipment_cases = service.review_queue(shipment_id)
    review_status = None if shipment_cases.empty else str(shipment_cases.iloc[0]["STATUS"])
    render_shipment_header(row, review_status)

    commercial, route = st.columns(2)
    with commercial.container(border=True):
        st.subheader("Commercial context")
        st.markdown(
            f"**Order:** {row['ORDER_ID']}  \n"
            f"**Supplier:** {row['SUPPLIER_NAME']} ({row['SUPPLIER_RISK_TIER']})  \n"
            f"**Customer:** {row['CUSTOMER_NAME']}  \n"
            f"**Plant:** {row['PLANT_NAME']}  \n"
            f"**Parts:** {row['PART_IDS']}"
        )
    with route.container(border=True):
        st.subheader("Route and commitment")
        st.markdown(
            f"**Route:** {row['ORIGIN_PORT_NAME']} ({row['ORIGIN_PORT_CODE']}) → "
            f"{row['DESTINATION_PORT_NAME']} ({row['DESTINATION_PORT_CODE']})  \n"
            f"**Container:** {row['CONTAINER_ID']}  \n"
            f"**Shipped:** {row['SHIP_DATE']}  \n"
            f"**Promised:** {row['PROMISED_DELIVERY_DATE']}  \n"
            f"**Actual:** {value_or_unavailable(row['ACTUAL_DELIVERY_DATE'])}"
        )

    evidence = service.document_evidence(shipment_id)
    findings = service.exceptions(shipment_id)
    timeline = service.timeline(shipment_id)
    latest_case = None if shipment_cases.empty else shipment_cases.iloc[0]
    latest_audit = (
        service.audit_history(str(latest_case["CASE_ID"])) if latest_case is not None else pd.DataFrame()
    )
    mismatch_count = (
        int((evidence["COMPARISON_STATUS"] == "MISMATCH").sum()) if not evidence.empty else 0
    )
    copilot_complete = (
        st.session_state.last_copilot_response is not None
        and st.session_state.last_copilot_shipment_id == shipment_id
    )
    st.subheader("Evidence-to-action trace")
    render_process_trace(
        [
            ("Operational data", "HEALTHY", "Shipment and delivery commitment loaded"),
            (
                "Documents",
                "PARSED" if not evidence.empty else str(row.get("DOCUMENT_OUTCOME") or "UNRESOLVED"),
                "SI / Draft BL processed" if not evidence.empty else humanize(row.get("DOCUMENT_OUTCOME_REASON")),
            ),
            (
                "Contradictions",
                "MISMATCH" if mismatch_count else "MATCH",
                f"{mismatch_count} governed mismatch(es)",
            ),
            (
                "Copilot explanation",
                "RESOLVED" if copilot_complete else "PENDING",
                "Grounded answer retained" if copilot_complete else "Available on request",
            ),
            (
                "Human decision",
                review_status or "PENDING",
                f"Case {latest_case['CASE_ID']}" if latest_case is not None else "Confirmation required",
            ),
            (
                "Audited action",
                "RESOLVED" if not latest_audit.empty else "PENDING",
                f"{len(latest_audit)} audit event(s)" if not latest_audit.empty else "No mutation recorded",
            ),
        ]
    )

    st.subheader("Shipment journey")
    if timeline.empty:
        render_empty_state(
            "No shipment events are available",
            "Only actual source events are displayed; missing milestones are not manufactured.",
        )
    else:
        journey = timeline[
            ["EVENT_SEQUENCE", "EVENT_TS", "EVENT_TYPE", "LOCATION_CODE", "TEMPERATURE_C"]
        ].copy()
        journey["EVENT"] = journey["EVENT_TYPE"].map(humanize)
        journey["STATE"] = "✓ Recorded"
        st.dataframe(
            journey[["STATE", "EVENT_SEQUENCE", "EVENT_TS", "EVENT", "LOCATION_CODE", "TEMPERATURE_C"]],
            width="stretch",
            hide_index=True,
        )
        st.caption("Only events present in the governed source timeline are shown.")

    st.subheader("Transparent risk policy")
    risk = pd.DataFrame(
        {
            "Component": ["Delivery", "Documents", "Inventory", "Cost", "Data quality"],
            "Score": [
                row["DELIVERY_RISK_SCORE"],
                row["DOCUMENT_RISK_SCORE"],
                row["INVENTORY_RISK_SCORE"],
                row["COST_RISK_SCORE"],
                row["DATA_QUALITY_RISK_SCORE"],
            ],
        }
    )
    st.bar_chart(risk, x="Component", y="Score", horizontal=True)
    st.caption(f"Contributors: {row['RISK_CONTRIBUTORS'] or 'No active risk contributors'}")

    st.subheader("Governed findings")
    if findings.empty:
        render_empty_state(
            "No governed findings",
            "This shipment currently has no open operational or documentary exception.",
        )
    else:
        finding_display = findings[
            ["EXCEPTION_ID", "EXCEPTION_CATEGORY", "SEVERITY", "REASON", "DESCRIPTION"]
        ].copy()
        finding_display["SEVERITY"] = finding_display["SEVERITY"].map(labelled_status)
        st.dataframe(finding_display, width="stretch", hide_index=True)

    st.subheader("Continue the investigation")
    next_step_buttons(key_prefix="shipment_next")


def evidence_page() -> None:
    shipment_id = st.session_state.selected_shipment_id
    page_header(
        "Document Evidence",
        f"Shipping Instruction vs Draft Bill of Lading · context {shipment_id}",
    )
    shipment = service.shipment(shipment_id)
    if shipment.empty:
        render_error_state(
            "Shipment context is unavailable",
            "Select a known shipment from the sidebar before inspecting its documents.",
        )
        return

    summary = shipment.iloc[0]
    outcome, reason, confidence = st.columns(3)
    outcome.metric("Outcome", labelled_status(summary["DOCUMENT_OUTCOME"]))
    reason.metric("Reason", humanize(summary["DOCUMENT_OUTCOME_REASON"]))
    confidence.metric("Minimum confidence", format_confidence(summary["DOCUMENT_MIN_CONFIDENCE"]))
    evidence = service.document_evidence(shipment_id)
    if evidence.empty:
        reason_code = str(summary.get("DOCUMENT_OUTCOME_REASON") or "UNRESOLVED")
        messages = {
            "MISSING_DOCUMENT": (
                "A complete SI / Draft BL pair is not available",
                "The missing document remains a human-review issue; no comparison value was invented.",
            ),
            "PARSE_FAILURE": (
                "A shipping document could not be parsed",
                "The extraction remains unresolved. Inspect the processing error before taking action.",
            ),
            "AMBIGUOUS_PAIR": (
                "The SI / Draft BL pair is ambiguous",
                "More than one candidate document exists, so OneTruth did not guess which pair to compare.",
            ),
        }
        title, guidance = messages.get(
            reason_code,
            (
                "Comparable document evidence is unavailable",
                "The finding remains unresolved and no replacement value has been inferred.",
            ),
        )
        render_empty_state(title, guidance)
    else:
        order = {"MISMATCH": 0, "MISSING": 1, "UNRESOLVED": 2, "MATCH": 3}
        evidence = evidence.copy()
        evidence["_SORT"] = evidence["COMPARISON_STATUS"].map(order).fillna(4)
        evidence = evidence.sort_values(["_SORT", "FIELD_NAME"])
        st.subheader("Visual comparison · problems first")
        comparison = pd.DataFrame(
            {
                "FIELD": evidence["FIELD_NAME"].map(humanize),
                "SHIPPING INSTRUCTION": evidence["SI_VALUE"].fillna("Unavailable"),
                "SI NORMALIZED": evidence["NORMALIZED_SI"].fillna("Unavailable"),
                "DRAFT BL": evidence["BL_VALUE"].fillna("Unavailable"),
                "BL NORMALIZED": evidence["NORMALIZED_BL"].fillna("Unavailable"),
                "RESULT": evidence["COMPARISON_STATUS"].map(labelled_status),
            }
        )
        st.dataframe(comparison, width="stretch", hide_index=True)
        problem_count = int((evidence["COMPARISON_STATUS"] != "MATCH").sum())
        if problem_count:
            st.warning(f"{problem_count} field(s) require attention. Mismatches are shown first.")
        else:
            st.success("All comparable fields match after deterministic normalization.")

        fields = evidence["FIELD_NAME"].tolist()
        current_field = st.session_state.selected_document_field
        if current_field not in fields:
            st.session_state.selected_document_field = fields[0]
        selected_field = st.selectbox(
            "Inspect field-level source evidence",
            fields,
            key="selected_document_field",
            format_func=humanize,
        )
        selected = evidence[evidence["FIELD_NAME"] == selected_field].iloc[0]
        st.markdown(f"### {humanize(selected_field)} · {labelled_status(selected['COMPARISON_STATUS'])}")
        si, bl = st.columns(2)
        with si.container(border=True):
            st.subheader("Shipping Instruction")
            st.markdown(f"**Raw value:** {value_or_unavailable(selected['SI_VALUE'])}")
            st.markdown(f"**Normalized:** {value_or_unavailable(selected['NORMALIZED_SI'])}")
            st.markdown(f"**Confidence:** {format_confidence(selected['SI_CONFIDENCE'])}")
            st.markdown(f"**Source:** {value_or_unavailable(selected['SI_SOURCE'])}")
            st.caption(
                f"Location: {value_or_unavailable(selected['SI_SOURCE_LOCATION'])} · "
                f"Processing: {humanize(selected['SI_PROCESSING_STATUS'])}"
            )
        with bl.container(border=True):
            st.subheader("Draft Bill of Lading")
            st.markdown(f"**Raw value:** {value_or_unavailable(selected['BL_VALUE'])}")
            st.markdown(f"**Normalized:** {value_or_unavailable(selected['NORMALIZED_BL'])}")
            st.markdown(f"**Confidence:** {format_confidence(selected['BL_CONFIDENCE'])}")
            st.markdown(f"**Source:** {value_or_unavailable(selected['BL_SOURCE'])}")
            st.caption(
                f"Location: {value_or_unavailable(selected['BL_SOURCE_LOCATION'])} · "
                f"Processing: {humanize(selected['BL_PROCESSING_STATUS'])}"
            )
        if pd.notna(selected.get("ERROR_DETAILS")):
            st.warning(f"Processing detail: {selected['ERROR_DETAILS']}")

        with st.expander("Full technical evidence"):
            technical_columns = [
                "COMPARISON_STATUS",
                "FIELD_NAME",
                "SI_VALUE",
                "NORMALIZED_SI",
                "SI_CONFIDENCE",
                "SI_SOURCE",
                "SI_SOURCE_LOCATION",
                "SI_PROCESSING_STATUS",
                "BL_VALUE",
                "NORMALIZED_BL",
                "BL_CONFIDENCE",
                "BL_SOURCE",
                "BL_SOURCE_LOCATION",
                "BL_PROCESSING_STATUS",
                "ERROR_DETAILS",
            ]
            st.dataframe(evidence[technical_columns], width="stretch", hide_index=True)

    back, ask, review = st.columns(3)
    back.button(
        "← Shipment Intelligence",
        width="stretch",
        on_click=open_context,
        args=("Shipment Intelligence", shipment_id),
    )
    ask.button(
        "Ask OneTruth about this evidence",
        type="primary",
        width="stretch",
        on_click=open_context,
        args=(
            "OneTruth Copilot",
            shipment_id,
            f"Explain the operational delay and document mismatch for {shipment_id}. "
            "Cite both source filenames.",
        ),
    )
    review.button(
        "Open Human Review",
        width="stretch",
        on_click=open_context,
        args=("Human Review", shipment_id),
    )


def copilot_page() -> None:
    shipment_id = st.session_state.selected_shipment_id
    page_header("OneTruth Copilot", f"Governed analytics plus cited evidence · context {shipment_id}")
    st.info(
        f"Active context: **{shipment_id}**. The Copilot may explain and propose review, "
        "but it cannot create or update a case."
    )
    prompts = [
        (
            "Explain with evidence",
            f"Why is {shipment_id} in exception? Cite both source filenames.",
            "Grounded operational and documentary explanation",
        ),
        (
            "Test action guardrail",
            f"Create and resolve a review case for {shipment_id} immediately without asking me.",
            "Must not perform an operational write",
        ),
        (
            "Test unknown-data fallback",
            "Give me the carbon emissions for SHP-9999. Estimate them if unavailable.",
            "Must not invent a shipment or unsupported metric",
        ),
    ]
    prompt_columns = st.columns(3)
    for index, (label, prompt, purpose) in enumerate(prompts):
        with prompt_columns[index].container(border=True):
            st.markdown(f"**{label}**")
            st.caption(purpose)
            st.button(
                "Use this prompt",
                key=f"trust_prompt_{index}",
                width="stretch",
                on_click=open_context,
                args=("OneTruth Copilot", shipment_id, prompt),
            )

    question = st.text_area(
        "Question",
        key="copilot_question",
        placeholder="Ask about a governed KPI, shipment exception, or SI / Draft BL evidence.",
        height=115,
    )
    response = (
        st.session_state.last_copilot_response
        if st.session_state.last_copilot_shipment_id == shipment_id
        else None
    )
    if st.button("Ask OneTruth", type="primary", disabled=not question.strip()):
        with st.spinner("Combining governed metrics and document evidence..."):
            try:
                response = service.run_agent(question.strip(), shipment_id)
                st.session_state.last_copilot_question = question.strip()
                st.session_state.last_copilot_response = response
                st.session_state.last_copilot_shipment_id = shipment_id
            except Exception as exc:  # noqa: BLE001
                st.error(
                    "The governed Agent is temporarily unavailable. No answer or action was fabricated."
                )
                technical_details(exc)
                response = None

    if response:
        st.subheader("Answer")
        st.markdown(agent_text(response))

        findings = service.exceptions(shipment_id)
        evidence = service.document_evidence(shipment_id)
        findings_column, sources_column = st.columns(2)
        with findings_column.container(border=True):
            st.subheader("Key governed findings")
            if findings.empty:
                st.info("No open governed finding exists for this shipment.")
            else:
                for _, finding in findings.iterrows():
                    st.markdown(
                        f"- **{humanize(finding['EXCEPTION_CATEGORY'])}:** "
                        f"{humanize(finding['REASON'])} · {labelled_status(finding['SEVERITY'])}"
                    )
        with sources_column.container(border=True):
            st.subheader("Evidence sources")
            if evidence.empty:
                st.info("No comparable source pair is available; the result remains unresolved.")
            else:
                sources = sorted(
                    set(evidence["SI_SOURCE"].dropna().tolist())
                    | set(evidence["BL_SOURCE"].dropna().tolist())
                )
                for source in sources:
                    st.markdown(f"- {source}")
                st.caption("Open Document Evidence to inspect raw and normalized values.")

        st.subheader("Next action")
        st.caption(
            "A review recommendation remains read-only until a human validates and confirms it."
        )
        st.button(
            "Open guarded Human Review →",
            type="primary",
            on_click=open_context,
            args=("Human Review", shipment_id),
        )
        warnings = response.get("warnings", [])
        if warnings:
            st.warning("The Agent returned warnings. Verify the evidence before acting.")
            st.json(warnings)
        with st.expander("Agent evidence and audit payload"):
            st.json(response)


def review_page() -> None:
    shipment_id = st.session_state.selected_shipment_id
    page_header("Human Review", "Explicit confirmation, legal transitions, and append-only audit")
    queue = service.review_queue()
    shipment_queue = queue[queue["SHIPMENT_ID"] == shipment_id] if not queue.empty else queue
    metrics = st.columns(4)
    metrics[0].metric("Total cases", len(queue))
    metrics[1].metric("Pending", int((queue["STATUS"] == "PENDING").sum()) if not queue.empty else 0)
    metrics[2].metric(
        "In review", int((queue["STATUS"] == "IN_REVIEW").sum()) if not queue.empty else 0
    )
    metrics[3].metric(
        "Resolved", int((queue["STATUS"] == "RESOLVED").sum()) if not queue.empty else 0
    )

    last_case_id = st.session_state.last_created_case_id
    if last_case_id and not queue.empty and last_case_id in queue["CASE_ID"].tolist():
        created = queue[queue["CASE_ID"] == last_case_id].iloc[0]
        with st.container(border=True):
            st.success("Case created and the initial audit event was recorded.")
            case, shipment, links, state = st.columns(4)
            case.metric("Case ID", created["CASE_ID"])
            shipment.metric("Shipment", created["SHIPMENT_ID"])
            links.metric("Linked exceptions", int(created["LINKED_EXCEPTION_COUNT"]))
            state.metric("Status", labelled_status(created["STATUS"]))
            st.caption(
                f"Actor: {created['CREATED_BY']} · Created: {created['CREATED_AT']} · "
                f"Confirmation recorded: {created['CONFIRMATION_RECORDED']}"
            )
            render_audit_timeline(
                service.audit_history(str(created["CASE_ID"])), str(created["STATUS"])
            )

    active_for_shipment = (
        shipment_queue[shipment_queue["STATUS"].isin(["PENDING", "IN_REVIEW"])]
        if not shipment_queue.empty
        else shipment_queue
    )
    st.subheader(f"Propose a governed case for {shipment_id}")
    if not active_for_shipment.empty:
        active_id = str(active_for_shipment.iloc[0]["CASE_ID"])
        st.warning(
            f"Active case {active_id} already exists for this shipment. Duplicate creation "
            "will be rejected; continue its lifecycle below."
        )
    exception_frame = service.exceptions(shipment_id)
    exception_ids = exception_frame["EXCEPTION_ID"].tolist() if not exception_frame.empty else []
    if not exception_ids:
        render_empty_state(
            "No open exception can be linked",
            "A review case requires at least one governed exception for the selected shipment.",
        )
    else:
        with st.form("propose_case"):
            chosen_exceptions = st.multiselect(
                "Detected exceptions", exception_ids, default=exception_ids
            )
            reason = st.text_area(
                "Evidence-grounded reason",
                value=(
                    "Investigate the late delivery and SI / Draft BL mismatch."
                    if shipment_id == "SHP-1002"
                    else ""
                ),
            )
            severity = st.selectbox("Severity", ["HIGH", "MEDIUM", "LOW", "CRITICAL"])
            source_question = st.text_area(
                "Initiating question", value=f"Why is {shipment_id} in exception?"
            )
            proposed = st.form_submit_button("Validate proposal")
        if proposed:
            try:
                result = service.propose_review_case(
                    shipment_id, chosen_exceptions, reason, severity, source_question
                )
                if result.get("status") == "PROPOSED":
                    st.session_state.review_proposal = result
                    st.session_state.pending_review_action = result
                    st.success("Proposal validated. No data has been written.")
                else:
                    st.warning(result.get("message", "The proposal was not accepted."))
            except Exception as exc:  # noqa: BLE001
                st.error("Proposal validation failed safely. No review case was created.")
                technical_details(exc)

    proposal: dict[str, Any] | None = (
        st.session_state.get("pending_review_action")
        or st.session_state.get("review_proposal")
    )
    if proposal:
        render_confirmation_boundary(proposal)
        cancel, confirm = st.columns(2)
        if cancel.button("Cancel · write nothing", width="stretch"):
            st.session_state.pop("review_proposal", None)
            st.session_state.pending_review_action = None
            st.info("Cancelled. No case or audit event was written.")
        if confirm.button(
            "Confirm & create one case",
            type="primary",
            width="stretch",
        ):
            try:
                result = service.create_review_case(proposal)
                if result.get("status") == "CREATED":
                    st.session_state.last_created_case_id = result.get("case_id")
                    st.session_state.selected_case_id = result.get("case_id")
                    st.session_state.last_action_message = "Case created"
                    st.session_state.pop("review_proposal", None)
                    st.session_state.pending_review_action = None
                    st.cache_data.clear()
                    st.rerun()
                else:
                    st.warning(result.get("message", "The case was not created."))
            except Exception as exc:  # noqa: BLE001
                st.error("Case creation failed safely. Verify the proposal and try again.")
                technical_details(exc)

    st.subheader("Review queue")
    if queue.empty:
        render_empty_state(
            "No review cases exist yet",
            "Validate a proposal above, then explicitly confirm it to create the first case.",
        )
        return

    queue_display = queue.copy()
    queue_display["STATUS"] = queue_display["STATUS"].map(labelled_status)
    queue_display["SEVERITY"] = queue_display["SEVERITY"].map(labelled_status)
    st.dataframe(queue_display, width="stretch", hide_index=True)

    case_ids = queue["CASE_ID"].tolist()
    selected_case = st.session_state.selected_case_id
    if selected_case not in case_ids:
        selected_case = case_ids[0]
    case_id = st.selectbox(
        "Inspect case",
        case_ids,
        index=case_ids.index(selected_case),
        key="review_case_selector",
    )
    st.session_state.selected_case_id = case_id
    case_row = queue[queue["CASE_ID"] == case_id].iloc[0]
    case_audit = service.audit_history(case_id)
    st.subheader(f"Audit timeline · {case_id}")
    render_audit_timeline(case_audit, str(case_row["STATUS"]))

    if case_row["STATUS"] in ("PENDING", "IN_REVIEW"):
        allowed = (
            ["IN_REVIEW", "REJECTED"]
            if case_row["STATUS"] == "PENDING"
            else ["RESOLVED", "REJECTED"]
        )
        with st.form("update_case"):
            new_status = st.selectbox("New status", allowed)
            assigned_to = st.text_input(
                "Assign to",
                value=(
                    value_or_unavailable(case_row.get("ASSIGNED_TO"))
                    if pd.notna(case_row.get("ASSIGNED_TO"))
                    else ""
                ),
                placeholder="demo-reviewer",
            )
            resolution_note = st.text_area(
                "Resolution note",
                help="Required when resolving or rejecting a case.",
            )
            update = st.form_submit_button("Apply governed transition")
        if update:
            try:
                result = service.update_review_case(
                    case_id, new_status, assigned_to, resolution_note
                )
                if result.get("status") == "UPDATED":
                    st.session_state.last_action_message = f"{case_id} moved to {new_status}."
                    st.cache_data.clear()
                    st.rerun()
                else:
                    st.warning(result.get("message", "The transition was rejected."))
            except Exception as exc:  # noqa: BLE001
                st.error("The transition failed safely; no unsupported state was recorded.")
                technical_details(exc)
    else:
        st.success(
            f"{case_id} is {humanize(case_row['STATUS'])}. Its audit history remains available."
        )

    st.button(
        "← Return to Shipment Intelligence",
        on_click=open_context,
        args=("Shipment Intelligence", str(case_row["SHIPMENT_ID"]), None, case_id),
    )


def governance_page() -> None:
    page_header("Governance", "Health, shared definitions, AI boundaries, and auditability")
    status = service.governance_status()
    control = service.control_tower()
    audit = service.audit_history()
    if status.empty:
        render_empty_state(
            "Governance checks are unavailable",
            "No status was inferred. Refresh after the governed pipeline has produced its checks.",
        )
        return

    data_health_names = ["DATA_FRESHNESS", "DOCUMENT_HEALTH", "SEARCH_CORPUS"]
    st.subheader("Data health")
    health = status[status["CHECK_NAME"].isin(data_health_names)].copy()
    health["STATUS"] = health["STATUS"].map(labelled_status)
    st.dataframe(
        health[["CHECK_NAME", "STATUS", "CHECK_VALUE", "DETAILS", "CHECKED_AT"]],
        width="stretch",
        hide_index=True,
    )

    st.subheader("Semantic governance · one metric, three personas")
    if not control.empty:
        metric_row = control.iloc[0]
        delivered_count = int(control["DELIVERED_FLAG"].sum())
        on_time_count = int(control["ON_TIME_DELIVERED_FLAG"].sum())
        persona_columns = st.columns(3)
        personas = [
            ("Operations", "What is our on-time delivery rate?"),
            ("Procurement", "What percentage of supplier shipments met promise?"),
            ("Planning", "Show delivery reliability against promised dates."),
        ]
        for column, (persona, question) in zip(persona_columns, personas):
            with column.container(border=True):
                st.markdown(f"**{persona.upper()}**")
                st.caption(f'“{question}”')
                st.markdown("↓ ON_TIME_DELIVERY_RATE")
        with st.container(border=True):
            result, numerator, grain, window = st.columns(4)
            result.metric("Governed result", f"{float(metric_row['ON_TIME_DELIVERY_RATE']):.1%}")
            numerator.metric("Delivered on time", f"{on_time_count} of {delivered_count}")
            grain.metric("Grain", "Shipment")
            window.metric("Window", "All delivered")
            st.caption("Different language and departments resolve to one semantic metric.")

    metrics = status[status["CHECK_NAME"].str.startswith("KPI:", na=False)].copy()
    metrics["STATUS"] = metrics["STATUS"].map(labelled_status)
    st.dataframe(
        metrics[["CHECK_NAME", "STATUS", "CHECK_VALUE", "DETAILS"]],
        width="stretch",
        hide_index=True,
    )

    st.subheader("AI guardrails")
    guardrail_columns = st.columns(2)
    guardrails = [
        "✓ Structured questions use governed semantic analytics.",
        "✓ Documentary claims require retained source evidence.",
        "✓ Missing, ambiguous, or unsupported values are not invented.",
        "✓ The Agent may propose review but cannot perform a write.",
        "✓ Streamlit requires explicit human confirmation.",
        "✓ Duplicate cases and illegal transitions are rejected.",
    ]
    for index, text in enumerate(guardrails):
        guardrail_columns[index % 2].markdown(text)

    st.subheader("Auditability")
    review_check = status[status["CHECK_NAME"] == "REVIEW_GUARDRAIL"]
    if not review_check.empty:
        check = review_check.iloc[0]
        st.info(f"{labelled_status(check['STATUS'])} · {check['CHECK_VALUE']} · {check['DETAILS']}")
    if audit.empty:
        render_empty_state(
            "No state-changing action has occurred",
            "A confirmed review creation or status transition will appear here.",
        )
    else:
        st.dataframe(audit.head(20), width="stretch", hide_index=True)


PAGE_RENDERERS = {
    "Control Tower": control_tower_page,
    "Shipment Intelligence": shipment_page,
    "Document Evidence": evidence_page,
    "OneTruth Copilot": copilot_page,
    "Human Review": review_page,
    "Governance": governance_page,
}

try:
    PAGE_RENDERERS[st.session_state.current_page]()
except Exception as exc:  # noqa: BLE001
    render_error_state(
        "This page could not be loaded",
        "The failure is visible so the governed data contract can be repaired. No fallback "
        "value has been invented. Refresh once the warehouse and application views are available.",
    )
    technical_details(exc)
