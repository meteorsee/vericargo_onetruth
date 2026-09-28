"""Deterministic domain logic for VeriCargo OneTruth."""

from .document_comparison import compare_documents
from .metrics import canonical_metrics
from .risk import RiskResult, calculate_risk
from .review import (
    ReviewCaseRequest,
    ensure_no_active_duplicate,
    validate_case_transition,
    validate_review_case,
)

__all__ = [
    "ReviewCaseRequest",
    "canonical_metrics",
    "compare_documents",
    "RiskResult",
    "calculate_risk",
    "validate_review_case",
    "validate_case_transition",
    "ensure_no_active_duplicate",
]

