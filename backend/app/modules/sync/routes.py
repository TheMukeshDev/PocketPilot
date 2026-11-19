from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Header
from pydantic import ValidationError
from sqlalchemy import select

from app.core.deps import CurrentUser, SessionDep
from app.core.errors import ApiError
from app.db.models import Budget, Expense, IdempotencyKey
from app.gateways.firestore_store import mirror_expense
from app.modules.budgets import service as budgets
from app.modules.expenses import service as expenses
from app.schemas import (
    ExpenseIn,
    SyncApplied,
    SyncBatchIn,
    SyncBatchOut,
    SyncChange,
    SyncChangesOut,
    SyncConflict,
)

router = APIRouter(prefix="/sync", tags=["sync"])


def _naive(value: datetime) -> datetime:
    return value.astimezone(UTC).replace(tzinfo=None) if value.tzinfo else value


@router.post("/batch", response_model=SyncBatchOut)
async def sync_batch(
    payload: SyncBatchIn,
    user: CurrentUser,
    session: SessionDep,
    idempotency_key: str = Header(alias="Idempotency-Key", min_length=8, max_length=200),
) -> SyncBatchOut:
    replay = await session.scalar(
        select(IdempotencyKey).where(
            IdempotencyKey.user_id == user.id, IdempotencyKey.key == idempotency_key
        )
    )
    if replay is not None:
        import json

        stored = json.loads(replay.response)
        stored["replayed"] = True
        return SyncBatchOut.model_validate(stored)

    applied: list[SyncApplied] = []
    conflicts: list[SyncConflict] = []
    for item in payload.items:
        try:
            if item.entity == "expense":
                if item.action == "delete":
                    result = await session.scalar(
                        select(Expense).where(
                            Expense.user_id == user.id, Expense.client_id == item.client_id
                        )
                    )
                    if result is None:
                        conflicts.append(SyncConflict(client_id=item.client_id, reason="not_found"))
                        continue
                    result.deleted = True
                    result.version = max(result.version, item.version) + 1
                    await session.commit()
                    await mirror_expense(user.id, result)
                    applied.append(
                        SyncApplied(
                            client_id=item.client_id,
                            entity="expense",
                            id=result.id,
                            version=result.version,
                        )
                    )
                    continue
                expense_in = ExpenseIn(**{**item.payload, "client_id": item.client_id})
                saved = await expenses.upsert(session, user.id, expense_in)
                applied.append(
                    SyncApplied(
                        client_id=item.client_id,
                        entity="expense",
                        id=saved.id,
                        version=saved.version,
                    )
                )
            else:
                if item.action == "delete":
                    conflicts.append(
                        SyncConflict(client_id=item.client_id, reason="budget_cannot_be_deleted")
                    )
                    continue
                saved_budget = await budgets.save_budget(session, user.id, item.payload)
                applied.append(
                    SyncApplied(
                        client_id=item.client_id,
                        entity="budget",
                        id=saved_budget.id,
                        version=saved_budget.version,
                    )
                )
        except (ApiError, ValidationError, ValueError) as exc:
            detail = exc.detail if isinstance(exc, ApiError) else str(exc)
            conflicts.append(SyncConflict(client_id=item.client_id, reason=detail[:200]))

    cursor = datetime.now(UTC)
    response = SyncBatchOut(applied=applied, conflicts=conflicts, cursor=cursor, replayed=False)
    session.add(
        IdempotencyKey(
            user_id=user.id,
            key=idempotency_key,
            response=response.model_dump_json(),
        )
    )
    await session.commit()
    return response


@router.get("/changes", response_model=SyncChangesOut)
async def sync_changes(
    user: CurrentUser,
    session: SessionDep,
    since: datetime | None = None,
) -> SyncChangesOut:
    cursor = datetime.now(UTC)
    since_value = _naive(since) if since else datetime(1970, 1, 1)
    changes: list[SyncChange] = []

    expense_rows = (
        await session.scalars(
            select(Expense).where(
                Expense.user_id == user.id,
                Expense.updated_at > since_value,
            )
        )
    ).all()
    for row in expense_rows:
        changes.append(
            SyncChange(
                entity="expense",
                id=row.id,
                client_id=row.client_id,
                data={
                    "title": row.title,
                    "amount": row.amount,
                    "category": row.category,
                    "date": row.spent_at.isoformat(),
                    "payment_app": row.payment_app,
                },
                version=row.version,
                updated_at=row.updated_at,
                deleted=row.deleted,
            )
        )

    budget_rows = (
        await session.scalars(
            select(Budget).where(Budget.user_id == user.id, Budget.updated_at > since_value)
        )
    ).all()
    for row in budget_rows:
        changes.append(
            SyncChange(
                entity="budget",
                id=row.id,
                client_id=None,
                data={
                    "monthly_amount": row.monthly_amount,
                    "rent_amount": row.rent_amount,
                    "cycle_start_day": row.cycle_start_day,
                    "currency": row.currency,
                },
                version=row.version,
                updated_at=row.updated_at,
            )
        )

    return SyncChangesOut(changes=changes, cursor=cursor + timedelta(seconds=1))
