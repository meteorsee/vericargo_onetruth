"""VeriCargo OneTruth control tower running in Streamlit in Snowflake."""

from __future__ import annotations

import json
from typing import Any

import streamlit as st
from snowflake.snowpark.context import get_active_session

AGENT_NAME = "VERICARGO_ONETRUTH.APP.VERICARGO_AGENT"
session = get_active_session()

st.set_page_config(
    page_title="VeriCargo OneTruth",
    page_icon="⛴",
    layout="wide",
)


@st.cache_data(ttl=30)
def query_frame(sql: str):
    """Return a small Snowflake result as a pandas frame."""

    return session.sql(sql).to_pandas()


def parse_variant(value: Any) -> dict[str, Any]:
    if isinstance(value, dict):
        return value
    if isinstance(value, str):
        parsed = json.loads(value)
        return parsed if isinstance(parsed, dict) else {"content": parsed}
    return {"content": value}


def agent_text(response: dict[str, Any]) -> str:
    messages: list[str] = []
    for item in response.get("content", []):
        if not isinstance(item, dict):
            continue
        if item.get("type") == "text" and item.get("text"):
            messages.append(str(item["text"]))
    return "\n\n".join(messages) or "The agent returned no displayable text."


def run_agent(question: str) -> dict[str, Any]:
    request = json.dumps(
        {
            "messages": [
                {
                    "role": "user",
                    "content": [{"type": "text", "text": question}],
                }
            ],
            "background": False,
            "stream": False,
        }
    )
    row = session.sql(
        """
        SELECT TRY_PARSE_JSON(
          SNOWFLAKE.CORTEX.DATA_AGENT_RUN(?, ?, TRUE)
        ) AS RESPONSE
        """,
        params=[AGENT_NAME, request],
    ).collect()[0]
    return parse_variant(row["RESPONSE"])


st.title("VeriCargo OneTruth")
st.caption("Governed supply-chain ontology and exception copilot")

with st.sidebar:
    st.subheader("Governance contract")
    st.markdown(
        """
        - One canonical definition per KPI
        - USD-only landed cost fixture
        - Evidence must cite its source file
        - Missing or failed extraction stays unresolved
        - Review creation requires explicit confirmation
        """
    )
    if st.button("Refresh data", use_container_width=True):
        st.cache_data.clear()
        st.rerun()

overview_tab, copilot_tab, evidence_tab, review_tab = st.tabs(
    ["KPI overview", "OneTruth copilot", "Document evidence", "Human review"]
)

with overview_tab:
    kpis = query_frame(
        """
        SELECT on_time_delivery_rate, fill_rate, days_of_inventory,
               landed_cost_usd, measured_at
        FROM VERICARGO_ONETRUTH.ANALYTICS.KPI_OVERVIEW
        """
    )
    if kpis.empty:
        st.warning("KPI mart has no rows. Run the deployment and validation scripts.")
    else:
        row = kpis.iloc[0]
        c1, c2, c3, c4 = st.columns(4)
        c1.metric("On-time delivery", f"{float(row['ON_TIME_DELIVERY_RATE']):.1%}")
        c2.metric("Fill rate", f"{float(row['FILL_RATE']):.1%}")
        c3.metric("Days of inventory", f"{float(row['DAYS_OF_INVENTORY']):.1f}")
        c4.metric("Landed cost", f"${float(row['LANDED_COST_USD']):,.2f}")
        st.caption(f"Last measured: {row['MEASURED_AT']}")

    st.subheader("Open exceptions")
    st.dataframe(
        query_frame(
            """
            SELECT exception_id, shipment_id, exception_type, severity, reason,
                   error_details, detected_at
            FROM VERICARGO_ONETRUTH.ANALYTICS.SHIPMENT_EXCEPTIONS
            ORDER BY IFF(severity = 'HIGH', 1, 2), shipment_id
            """
        ),
        use_container_width=True,
        hide_index=True,
    )

with copilot_tab:
    st.subheader("Ask governed supply-chain questions")
    st.caption(
        "The agent uses Cortex Analyst for governed metrics and Cortex Search for "
        "document evidence. Warnings are surfaced rather than hidden."
    )
    default_question = "Why is SHP-1002 in exception? Cite the SI and Draft BL filenames."
    question = st.text_area("Question", value=default_question, height=100)
    if st.button("Ask OneTruth", type="primary", disabled=not question.strip()):
        with st.spinner("Running the governed agent..."):
            try:
                response = run_agent(question.strip())
                st.markdown(agent_text(response))
                warnings = response.get("warnings", [])
                if warnings:
                    st.warning("Agent warnings")
                    st.json(warnings)
                with st.expander("Audit response payload"):
                    st.json(response)
            # UI boundary: surface connector, SQL, parsing, and agent failures to the user.
            except Exception as exc:  # noqa: BLE001
                st.error(f"Agent request failed: {exc}")

with evidence_tab:
    st.subheader("SI / Draft BL comparison")
    summary = query_frame(
        """
        SELECT shipment_id, si_count, bl_count, outcome, mismatch_count,
               unresolved_count, min_confidence, error_details
        FROM VERICARGO_ONETRUTH.CURATED.DOCUMENT_COMPARISON_SUMMARY
        ORDER BY shipment_id
        """
    )
    st.dataframe(summary, use_container_width=True, hide_index=True)

    shipment_ids = summary["SHIPMENT_ID"].tolist() if not summary.empty else []
    selected = st.selectbox("Inspect shipment", shipment_ids)
    if selected:
        fields = session.sql(
            """
            SELECT field_name, si_value, bl_value, comparison_status,
                   si_source, bl_source
            FROM VERICARGO_ONETRUTH.CURATED.DOCUMENT_FIELD_COMPARISONS
            WHERE shipment_id = ?
            ORDER BY field_name
            """,
            params=[selected],
        ).to_pandas()
        if fields.empty:
            st.info("No unambiguous readable SI/Draft BL pair is available for comparison.")
        else:
            st.dataframe(fields, use_container_width=True, hide_index=True)

with review_tab:
    st.subheader("Create an auditable human-review case")
    shipment_rows = session.sql(
        "SELECT shipment_id FROM VERICARGO_ONETRUTH.RAW.SHIPMENTS ORDER BY shipment_id"
    ).collect()
    known_shipments = [row["SHIPMENT_ID"] for row in shipment_rows]

    with st.form("create_review_case", clear_on_submit=False):
        shipment_id = st.selectbox("Shipment", known_shipments)
        reason = st.text_area("Reason", placeholder="State the evidence-grounded exception.")
        severity = st.selectbox("Severity", ["MEDIUM", "HIGH", "LOW", "CRITICAL"])
        source_question = st.text_area(
            "Source question",
            placeholder="Paste the question or instruction that led to this action.",
        )
        confirmed = st.checkbox(
            "I explicitly confirm creation of this pending human-review case."
        )
        submitted = st.form_submit_button("Create review case", type="primary")

    if submitted:
        try:
            result = session.call(
                "VERICARGO_ONETRUTH.APP.CREATE_REVIEW_CASE",
                shipment_id,
                reason,
                severity,
                confirmed,
                source_question,
            )
            result = parse_variant(result)
            if result.get("status") == "CREATED":
                st.success(f"Created {result.get('case_id')} for {shipment_id}.")
                st.cache_data.clear()
            else:
                st.warning(result.get("message", str(result)))
        # UI boundary: block the action and display any validation or Snowflake failure.
        except Exception as exc:  # noqa: BLE001
            st.error(f"Review action failed: {exc}")

    st.subheader("Review queue")
    st.dataframe(
        query_frame(
            """
            SELECT case_id, shipment_id, severity, status, reason, source_question,
                   created_by, created_at, confirmation_recorded
            FROM VERICARGO_ONETRUTH.APP.REVIEW_CASES
            ORDER BY created_at DESC
            """
        ),
        use_container_width=True,
        hide_index=True,
    )
