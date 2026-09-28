"""VeriCargo OneTruth connected control tower for Streamlit in Snowflake."""

from __future__ import annotations

from typing import Any

import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session

from components import labelled_status, next_step_buttons
from services import OneTruthService, agent_text

st.set_page_config(page_title="VeriCargo OneTruth", page_icon="🚢", layout="wide")
st.markdown(
    """
    <style>
      .block-container {padding-top: 1.5rem; padding-bottom: 3rem;}
      [data-testid="stMetric"] {border: 1px solid #26364a; border-radius: 10px; padding: .8rem;}
      .context {color: #8bc5ff; font-weight: 600;}
      div.stButton > button {border-radius: 8px;}
    </style>
    """,
    unsafe_allow_html=True,
)

service = OneTruthService(get_active_session())
st.session_state.setdefault("current_page", "Control Tower")
st.session_state.setdefault("selected_shipment_id", "SHP-1002")
st.session_state.setdefault("shipment_context_selector", "SHP-1002")


def navigate(page: str) -> None:
    st.session_state.current_page = page


def nav_button(label: str, page: str) -> None:
    st.button(
        label,
        key=f"nav_{page}",
        use_container_width=True,
        type="primary" if st.session_state.current_page == page else "secondary",
        on_click=navigate,
        args=(page,),
    )


def update_shipment_context() -> None:
    st.session_state.selected_shipment_id = st.session_state.shipment_context_selector
    st.session_state.pop("review_proposal", None)


def open_shipment(shipment_id: str) -> None:
    st.session_state.selected_shipment_id = shipment_id
    st.session_state.shipment_context_selector = shipment_id
    st.session_state.current_page = "Shipment Intelligence"
    st.session_state.pop("review_proposal", None)


with st.sidebar:
    st.title("🚢 OneTruth")
    st.caption("Governed exception control tower")
    try:
        shipment_ids = service.shipment_ids()
    except Exception as exc:  # noqa: BLE001
        shipment_ids = []
        st.error(f"Shipment context unavailable: {exc}")
    if shipment_ids:
        current = st.session_state.selected_shipment_id
        if current not in shipment_ids:
            current = shipment_ids[0]
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
    if st.button("↻ Refresh data", use_container_width=True):
        st.cache_data.clear()
        st.rerun()
    st.caption("USD-only • evidence required • explicit confirmation")


def page_header(title: str, description: str) -> None:
    st.title(title)
    st.caption(description)


def control_tower_page() -> None:
    page_header("Control Tower", "Portfolio health, governed KPIs, and ranked attention")
    data = service.control_tower()
    if data.empty:
        st.warning("No control-tower rows are available. Run the deployment pipeline.")
        return
    row = data.iloc[0]
    cards = st.columns(6)
    cards[0].metric("On-time delivery", f"{float(row['ON_TIME_DELIVERY_RATE']):.1%}")
    cards[1].metric("Fill rate", f"{float(row['FILL_RATE']):.1%}")
    cards[2].metric("Days of inventory", f"{float(row['PORTFOLIO_DAYS_OF_INVENTORY']):.1f}")
    cards[3].metric("Landed cost", f"${float(row['PORTFOLIO_LANDED_COST_USD']):,.0f}")
    cards[4].metric("Delayed", int(row["DELAYED_SHIPMENT_COUNT"]))
    cards[5].metric("Exceptions", int(row["EXCEPTION_COUNT"]))

    left, right = st.columns(2)
    delivered = data[data["DELIVERED_FLAG"] == 1].copy()
    if not delivered.empty:
        trend = (
            delivered.groupby("SHIP_DATE", as_index=False)["ON_TIME_DELIVERED_FLAG"]
            .mean()
            .rename(columns={"ON_TIME_DELIVERED_FLAG": "ON_TIME_RATE"})
        )
        left.subheader("On-time delivery trend")
        left.line_chart(trend, x="SHIP_DATE", y="ON_TIME_RATE")
    severity = data.groupby("RISK_SEVERITY", as_index=False).size()
    right.subheader("Shipments by risk severity")
    right.bar_chart(severity, x="RISK_SEVERITY", y="size")

    st.subheader("Attention ranking")
    attention = data[
        [
            "ATTENTION_RANK", "SHIPMENT_ID", "STATUS", "RISK_SEVERITY",
            "OVERALL_RISK_SCORE", "OPEN_EXCEPTION_COUNT", "DOCUMENT_OUTCOME",
            "ATTENTION_REASON",
        ]
    ].copy()
    attention["RISK_SEVERITY"] = attention["RISK_SEVERITY"].map(labelled_status)
    st.dataframe(attention, use_container_width=True, hide_index=True)
    chosen = st.selectbox("Select a shipment to investigate", data["SHIPMENT_ID"].tolist())
    st.button(
        "Open Shipment 360 →", type="primary", on_click=open_shipment, args=(chosen,)
    )


def shipment_page() -> None:
    shipment_id = st.session_state.selected_shipment_id
    page_header("Shipment Intelligence", f"360° operational context for {shipment_id}")
    data = service.shipment(shipment_id)
    if data.empty:
        st.error(f"Shipment {shipment_id} was not found.")
        return
    row = data.iloc[0]
    cols = st.columns(5)
    cols[0].metric("Status", str(row["STATUS"]).replace("_", " ").title())
    cols[1].metric("Overall risk", f"{int(row['OVERALL_RISK_SCORE'])}/100")
    cols[2].metric("Severity", labelled_status(row["RISK_SEVERITY"]))
    cols[3].metric("Days late", int(row["DELIVERY_DAYS_LATE"]))
    cols[4].metric("Open exceptions", int(row["OPEN_EXCEPTION_COUNT"]))

    context, route = st.columns(2)
    context.subheader("Commercial context")
    context.write(
        f"**Order:** {row['ORDER_ID']}  \n**Supplier:** {row['SUPPLIER_NAME']} "
        f"({row['SUPPLIER_RISK_TIER']})  \n**Customer:** {row['CUSTOMER_NAME']}  "
        f"\n**Plant:** {row['PLANT_NAME']}  \n**Parts:** {row['PART_IDS']}"
    )
    route.subheader("Route and commitment")
    route.write(
        f"**Route:** {row['ORIGIN_PORT_CODE']} → {row['DESTINATION_PORT_CODE']}  "
        f"\n**Container:** {row['CONTAINER_ID']}  \n**Shipped:** {row['SHIP_DATE']}  "
        f"\n**Promised:** {row['PROMISED_DELIVERY_DATE']}  "
        f"\n**Actual:** {row['ACTUAL_DELIVERY_DATE']}"
    )

    st.subheader("Transparent risk components")
    risk = pd.DataFrame(
        {
            "Component": ["Delivery", "Documents", "Inventory", "Cost", "Data quality"],
            "Score": [
                row["DELIVERY_RISK_SCORE"], row["DOCUMENT_RISK_SCORE"],
                row["INVENTORY_RISK_SCORE"], row["COST_RISK_SCORE"],
                row["DATA_QUALITY_RISK_SCORE"],
            ],
        }
    )
    st.bar_chart(risk, x="Component", y="Score", horizontal=True)
    st.caption(f"Contributors: {row['RISK_CONTRIBUTORS'] or 'No active risk contributors'}")

    timeline, exceptions = st.columns([3, 2])
    timeline.subheader("Shipment timeline")
    timeline.dataframe(
        service.timeline(shipment_id)[
            ["EVENT_SEQUENCE", "EVENT_TS", "EVENT_TYPE", "LOCATION_CODE", "TEMPERATURE_C"]
        ],
        use_container_width=True,
        hide_index=True,
    )
    exceptions.subheader("Governed findings")
    findings = service.exceptions(shipment_id)
    if findings.empty:
        exceptions.info("No governed findings for this shipment.")
    else:
        exceptions.dataframe(
            findings[["EXCEPTION_ID", "EXCEPTION_CATEGORY", "SEVERITY", "REASON"]],
            use_container_width=True,
            hide_index=True,
        )
    st.subheader("Next step")
    next_step_buttons()


def evidence_page() -> None:
    shipment_id = st.session_state.selected_shipment_id
    page_header("Document Evidence", f"Shipping Instruction vs Draft Bill of Lading • {shipment_id}")
    shipment = service.shipment(shipment_id)
    if shipment.empty:
        st.error("Shipment context is unavailable.")
        return
    summary = shipment.iloc[0]
    left, middle, right = st.columns(3)
    left.metric("Outcome", labelled_status(summary["DOCUMENT_OUTCOME"]))
    middle.metric("Reason", str(summary["DOCUMENT_OUTCOME_REASON"]).replace("_", " ").title())
    confidence = summary["DOCUMENT_MIN_CONFIDENCE"]
    right.metric("Minimum confidence", "Unavailable" if pd.isna(confidence) else f"{float(confidence):.0%}")
    evidence = service.document_evidence(shipment_id)
    if evidence.empty:
        st.warning(
            "No unambiguous SI/Draft BL pair can be compared. The finding remains unresolved; "
            "no value has been invented."
        )
    else:
        evidence["STATUS"] = evidence["COMPARISON_STATUS"].map(labelled_status)
        st.dataframe(
            evidence[
                [
                    "STATUS", "FIELD_NAME", "SI_VALUE", "NORMALIZED_SI", "SI_CONFIDENCE",
                    "SI_SOURCE", "BL_VALUE", "NORMALIZED_BL", "BL_CONFIDENCE", "BL_SOURCE",
                ]
            ],
            use_container_width=True,
            hide_index=True,
        )
        problem_count = int((evidence["COMPARISON_STATUS"] != "MATCH").sum())
        if problem_count:
            st.warning(f"{problem_count} field(s) require attention. Source filenames are shown above.")
        else:
            st.success("All comparable fields match after deterministic normalization.")
    next_step_buttons()


def copilot_page() -> None:
    shipment_id = st.session_state.selected_shipment_id
    page_header("OneTruth Copilot", f"Governed analytics plus cited evidence • context {shipment_id}")
    suggestions = [
        "Why is this shipment in exception? Cite both source filenames.",
        "Explain the operational delay and document mismatch together.",
        "What is our governed on-time delivery rate and its definition?",
    ]
    st.caption("Suggested questions")
    columns = st.columns(3)
    for index, suggestion in enumerate(suggestions):
        if columns[index].button(suggestion, key=f"suggestion_{index}", use_container_width=True):
            st.session_state.copilot_question = suggestion
    question = st.text_area(
        "Question", key="copilot_question",
        placeholder="Ask about a KPI, shipment, delay, or SI/BL evidence.", height=110,
    )
    if st.button("Ask OneTruth", type="primary", disabled=not question.strip()):
        with st.spinner("Combining governed metrics and document evidence..."):
            try:
                response = service.run_agent(question.strip(), shipment_id)
                st.markdown(agent_text(response))
                warnings = response.get("warnings", [])
                if warnings:
                    st.warning("The agent returned warnings; verify before acting.")
                    st.json(warnings)
                with st.expander("Evidence and audit payload"):
                    st.json(response)
            except Exception as exc:  # noqa: BLE001
                st.error(f"Agent request failed: {exc}")
    st.info("The Copilot may propose human review, but it cannot create or update a case.")


def review_page() -> None:
    shipment_id = st.session_state.selected_shipment_id
    page_header("Human Review", "Explicit confirmation, legal transitions, and append-only audit")
    queue = service.review_queue()
    metrics = st.columns(4)
    metrics[0].metric("Total cases", len(queue))
    metrics[1].metric("Pending", int((queue["STATUS"] == "PENDING").sum()) if not queue.empty else 0)
    metrics[2].metric("In review", int((queue["STATUS"] == "IN_REVIEW").sum()) if not queue.empty else 0)
    metrics[3].metric("Resolved", int((queue["STATUS"] == "RESOLVED").sum()) if not queue.empty else 0)

    st.subheader(f"Create a case for {shipment_id}")
    exception_frame = service.exceptions(shipment_id)
    exception_ids = exception_frame["EXCEPTION_ID"].tolist() if not exception_frame.empty else []
    with st.form("propose_case"):
        chosen_exceptions = st.multiselect("Detected exceptions", exception_ids, default=exception_ids)
        reason = st.text_area(
            "Evidence-grounded reason",
            value="Investigate the late delivery and SI/Draft BL mismatch." if shipment_id == "SHP-1002" else "",
        )
        severity = st.selectbox("Severity", ["HIGH", "MEDIUM", "LOW", "CRITICAL"])
        source_question = st.text_area("Source question", value=f"Why is {shipment_id} in exception?")
        proposed = st.form_submit_button("Validate proposal")
    if proposed:
        try:
            result = service.propose_review_case(
                shipment_id, chosen_exceptions, reason, severity, source_question
            )
            if result.get("status") == "PROPOSED":
                st.session_state.review_proposal = result
                st.success("Proposal validated. No data has been written.")
            else:
                st.warning(result.get("message", str(result)))
        except Exception as exc:  # noqa: BLE001
            st.error(f"Proposal validation failed: {exc}")

    proposal: dict[str, Any] | None = st.session_state.get("review_proposal")
    if proposal:
        st.warning(
            f"Confirm creation for {proposal.get('shipment_id')} with "
            f"{len(proposal.get('exception_ids', []))} linked exception(s)?"
        )
        confirm, cancel, _ = st.columns([1, 1, 3])
        if confirm.button("Confirm creation", type="primary", use_container_width=True):
            try:
                result = service.create_review_case(proposal)
                if result.get("status") == "CREATED":
                    st.success(f"Created {result.get('case_id')} and recorded its audit event.")
                    st.session_state.pop("review_proposal", None)
                    st.rerun()
                else:
                    st.warning(result.get("message", str(result)))
            except Exception as exc:  # noqa: BLE001
                st.error(f"Case creation failed: {exc}")
        if cancel.button("Cancel", use_container_width=True):
            st.session_state.pop("review_proposal", None)
            st.info("Cancelled. Nothing was written.")

    st.subheader("Review queue")
    if queue.empty:
        st.info("No review cases exist yet. Validate and confirm the SHP-1002 proposal above.")
    else:
        st.dataframe(queue, use_container_width=True, hide_index=True)
        active = queue[queue["STATUS"].isin(["PENDING", "IN_REVIEW"])]
        if not active.empty:
            case_id = st.selectbox("Update case", active["CASE_ID"].tolist())
            case_status = active.loc[active["CASE_ID"] == case_id, "STATUS"].iloc[0]
            allowed = ["IN_REVIEW", "REJECTED"] if case_status == "PENDING" else ["RESOLVED", "REJECTED"]
            with st.form("update_case"):
                new_status = st.selectbox("New status", allowed)
                assigned_to = st.text_input("Assign to", placeholder="reviewer@company.example")
                resolution_note = st.text_area(
                    "Resolution note", help="Required when resolving or rejecting a case."
                )
                update = st.form_submit_button("Apply transition")
            if update:
                try:
                    result = service.update_review_case(case_id, new_status, assigned_to, resolution_note)
                    if result.get("status") == "UPDATED":
                        st.success(f"{case_id} moved to {new_status}.")
                        st.rerun()
                    else:
                        st.warning(result.get("message", str(result)))
                except Exception as exc:  # noqa: BLE001
                    st.error(f"Case update failed: {exc}")
        st.subheader("Audit history")
        st.dataframe(service.audit_history(), use_container_width=True, hide_index=True)


def governance_page() -> None:
    page_header("Governance", "Freshness, canonical definitions, guardrails, and auditability")
    status = service.governance_status()
    if status.empty:
        st.warning("Governance checks have not produced any rows.")
    else:
        status["DISPLAY_STATUS"] = status["STATUS"].map(labelled_status)
        st.dataframe(
            status[["CHECK_NAME", "DISPLAY_STATUS", "CHECK_VALUE", "DETAILS", "CHECKED_AT"]],
            use_container_width=True,
            hide_index=True,
        )
    st.subheader("Guardrails")
    st.markdown(
        """
        - One canonical semantic definition per KPI; landed cost is USD only.
        - Failed, ambiguous, missing, or low-confidence extraction is never asserted as fact.
        - The agent can only propose review; Streamlit requires explicit confirmation to write.
        - Duplicate active cases and illegal status transitions are rejected.
        - Every case creation and status change emits an append-only audit event.
        """
    )
    st.subheader("Recent audit events")
    audit = service.audit_history()
    if audit.empty:
        st.info("No state-changing review actions have occurred yet.")
    else:
        st.dataframe(audit, use_container_width=True, hide_index=True)


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
    st.error(f"This page could not be loaded: {exc}")
    st.caption("The error is visible by design so deployment and data-contract issues can be repaired.")
