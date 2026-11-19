from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.db.models import Expense
from app.gateways.firestore_store import mirror_expense
from app.schemas import ExpenseIn


async def list_expenses(
    session: AsyncSession,
    user_id: str,
    limit: int,
    offset: int,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
    category: str | None = None,
    search: str | None = None,
) -> list[Expense]:
    query = select(Expense).where(Expense.user_id == user_id, Expense.deleted.is_(False))
    if date_from is not None:
        query = query.where(Expense.spent_at >= date_from)
    if date_to is not None:
        query = query.where(Expense.spent_at <= date_to)
    if category:
        query = query.where(Expense.category == category)
    if search:
        query = query.where(Expense.title.ilike(f"%{search[:80]}%"))
    query = query.order_by(Expense.spent_at.desc()).limit(limit).offset(offset)
    return list((await session.scalars(query)).all())


async def get_owned(session: AsyncSession, user_id: str, expense_id: str) -> Expense:
    expense = await session.get(Expense, expense_id)
    if expense is None or expense.user_id != user_id:
        raise ApiError(status_code=404, detail="Expense not found")
    return expense


async def upsert(session: AsyncSession, user_id: str, payload: ExpenseIn) -> Expense:
    result = await session.execute(
        select(Expense).where(Expense.user_id == user_id, Expense.client_id == payload.client_id)
    )
    expense = result.scalar_one_or_none()
    if expense is None:
        expense = Expense(user_id=user_id, client_id=payload.client_id)
        session.add(expense)
    elif expense.version > payload.version:
        raise ApiError(status_code=409, detail="Server version is newer")
    expense.title = payload.title.strip()
    expense.amount = payload.amount
    expense.category = payload.category
    expense.spent_at = payload.date
    expense.payment_app = payload.payment_app
    expense.version = payload.version
    expense.deleted = False
    await session.commit()
    await mirror_expense(user_id, expense)
    return expense


async def soft_delete(session: AsyncSession, expense: Expense) -> None:
    expense.deleted = True
    expense.version += 1
    await session.commit()
    await mirror_expense(expense.user_id, expense)


async def total_spent(session: AsyncSession, user_id: str, start: datetime, end: datetime) -> int:
    result = await session.scalar(
        select(func.coalesce(func.sum(Expense.amount), 0)).where(
            Expense.user_id == user_id,
            Expense.deleted.is_(False),
            Expense.spent_at >= start,
            Expense.spent_at < end,
        )
    )
    return int(result or 0)
