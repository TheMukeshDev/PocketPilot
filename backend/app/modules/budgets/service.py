import calendar
from datetime import UTC, date, datetime, time, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Budget
from app.gateways.firestore_store import mirror_budget
from app.modules.expenses.service import total_spent


def cycle_bounds(today: date, cycle_start_day: int) -> tuple[date, date]:
    day = min(max(cycle_start_day, 1), 28)
    if today.day >= day:
        start = date(today.year, today.month, day)
    else:
        previous_month = today.month - 1 or 12
        previous_year = today.year if today.month > 1 else today.year - 1
        start = date(previous_year, previous_month, day)
    if start.month == 12:
        end = date(start.year + 1, 1, day) - timedelta(days=1)
    else:
        end = date(start.year, start.month + 1, day) - timedelta(days=1)
    return start, end


async def get_budget(session: AsyncSession, user_id: str) -> Budget:
    result = await session.execute(select(Budget).where(Budget.user_id == user_id))
    budget = result.scalar_one_or_none()
    if budget is None:
        budget = Budget(user_id=user_id)
        session.add(budget)
        await session.commit()
    return budget


async def save_budget(session: AsyncSession, user_id: str, values: dict) -> Budget:
    budget = await get_budget(session, user_id)
    if budget.version > int(values.get("version", 1)):
        from app.core.errors import ApiError

        raise ApiError(status_code=409, detail="Server version is newer")
    for field in ("monthly_amount", "rent_amount", "cycle_start_day", "currency"):
        if field in values and values[field] is not None:
            setattr(budget, field, values[field])
    budget.version += 1
    await session.commit()
    await mirror_budget(user_id, budget)
    return budget


async def daily_limit(session: AsyncSession, user_id: str, now: datetime) -> dict:
    budget = await get_budget(session, user_id)
    start, end = cycle_bounds(now.date(), budget.cycle_start_day)
    start_dt = datetime.combine(start, time.min, tzinfo=UTC)
    end_dt = datetime.combine(end + timedelta(days=1), time.min, tzinfo=UTC)
    spent = await total_spent(session, user_id, start_dt, end_dt)
    available = max(budget.monthly_amount - budget.rent_amount, 0)
    remaining = max(available - spent, 0)
    days_left = max((end - now.date()).days + 1, 1)
    import math

    return {
        "budget": available,
        "spent": spent,
        "remaining": remaining,
        "days_left": days_left,
        "daily_limit": math.ceil(remaining / days_left),
        "cycle_start": start.isoformat(),
        "cycle_end": end.isoformat(),
        "days_in_cycle": calendar.monthrange(start.year, start.month)[1],
    }
