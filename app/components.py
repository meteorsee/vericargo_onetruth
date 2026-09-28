"""Small shared presentation helpers for the OneTruth control tower."""

from __future__ import annotations

import streamlit as st

STATUS_ICONS = {
    "MATCH": "✅",
    "HEALTHY": "✅",
    "GOVERNED": "✅",
    "ENFORCED": "🔒",
    "MISMATCH": "❌",
    "MISSING": "⚠️",
    "UNRESOLVED": "⚠️",
    "ATTENTION": "⚠️",
    "PENDING": "🟡",
    "IN_REVIEW": "🔵",
    "RESOLVED": "✅",
    "REJECTED": "⛔",
    "LOW": "🟢",
    "MEDIUM": "🟡",
    "HIGH": "🟠",
    "CRITICAL": "🔴",
}


def labelled_status(value: object) -> str:
    text = str(value or "UNKNOWN").upper()
    return f"{STATUS_ICONS.get(text, 'ℹ️')} {text.replace('_', ' ').title()}"


def go_to(page: str) -> None:
    st.session_state.current_page = page
    st.rerun()


def next_step_buttons() -> None:
    left, middle, right = st.columns(3)
    if left.button("📄 Inspect evidence", use_container_width=True):
        go_to("Document Evidence")
    if middle.button("✨ Ask Copilot", use_container_width=True):
        go_to("OneTruth Copilot")
    if right.button("🧑‍⚖️ Open review", use_container_width=True):
        go_to("Human Review")
