import asyncio
import logging
from typing import Any

from app.gateways.firebase import get_firestore

logger = logging.getLogger(__name__)


def _write_document(user_id: str, collection: str, document_id: str, data: dict[str, Any]) -> None:
    try:
        client = get_firestore()
        if client is None:
            return
        (
            client.collection("users")
            .document(user_id)
            .collection(collection)
            .document(document_id)
            .set(data, merge=True)
        )
    except Exception as exc:
        logger.error("Firestore write failed: %s", type(exc).__name__)


async def mirror_expense(user_id: str, expense: Any) -> None:
    await asyncio.to_thread(
        _write_document,
        user_id,
        "expenses",
        expense.client_id,
        {
            "client_id": expense.client_id,
            "title": expense.title,
            "amount": expense.amount,
            "category": expense.category,
            "spent_at": expense.spent_at,
            "payment_app": expense.payment_app,
            "version": expense.version,
            "deleted": expense.deleted,
            "updated_at": expense.updated_at,
        },
    )


async def mirror_budget(user_id: str, budget: Any) -> None:
    await asyncio.to_thread(
        _write_document,
        user_id,
        "budgets",
        "current",
        {
            "monthly_amount": budget.monthly_amount,
            "rent_amount": budget.rent_amount,
            "cycle_start_day": budget.cycle_start_day,
            "currency": budget.currency,
            "version": budget.version,
            "updated_at": budget.updated_at,
        },
    )
