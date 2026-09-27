"""Deterministic domain logic for VeriCargo OneTruth."""

from .document_comparison import compare_documents
from .metrics import canonical_metrics
from .review import ReviewCaseRequest, validate_review_case

__all__ = [
    "ReviewCaseRequest",
    "canonical_metrics",
    "compare_documents",
    "validate_review_case",
]

