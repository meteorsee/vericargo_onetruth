"""Guardrails for state-changing review-case creation."""

from __future__ import annotations

from collections.abc import Collection
from dataclasses import dataclass

ALLOWED_SEVERITIES = {"LOW", "MEDIUM", "HIGH", "CRITICAL"}


class ReviewValidationError(ValueError):
    """Raised when a review case fails a guardrail."""


class ReviewNotConfirmed(ReviewValidationError):
    """Raised when the user has not explicitly confirmed the action."""


@dataclass(frozen=True)
class ReviewCaseRequest:
    shipment_id: str
    reason: str
    severity: str
    confirmed: bool
    source_question: str


def validate_review_case(
    request: ReviewCaseRequest,
    known_shipment_ids: Collection[str],
) -> ReviewCaseRequest:
    """Validate and normalize a proposed review case without performing the write."""

    if not request.confirmed:
        raise ReviewNotConfirmed("Explicit confirmation is required.")
    shipment_id = request.shipment_id.strip().upper()
    if shipment_id not in {value.strip().upper() for value in known_shipment_ids}:
        raise ReviewValidationError("Shipment does not exist.")
    severity = request.severity.strip().upper()
    if severity not in ALLOWED_SEVERITIES:
        raise ReviewValidationError("Severity must be LOW, MEDIUM, HIGH, or CRITICAL.")
    reason = request.reason.strip()
    if not 5 <= len(reason) <= 1000:
        raise ReviewValidationError("Reason must be between 5 and 1,000 characters.")
    source_question = request.source_question.strip()
    if len(source_question) < 3 or len(source_question) > 2000:
        raise ReviewValidationError("Source question must be between 3 and 2,000 characters.")
    return ReviewCaseRequest(
        shipment_id=shipment_id,
        reason=reason,
        severity=severity,
        confirmed=True,
        source_question=source_question,
    )

