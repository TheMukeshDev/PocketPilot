from datetime import UTC, date, datetime, time, timedelta

from fastapi import APIRouter
from sqlalchemy import func, select

from app.core.deps import CurrentUser, SessionDep
from app.db.models import Expense
from app.schemas import PredictionOut

router = APIRouter(prefix="/predictions", tags=["predictions"])


@router.get("/overspend", response_model=PredictionOut)
async def overspend(user: CurrentUser, session: SessionDep) -> PredictionOut:
    from app.modules.budgets.service import daily_limit

    now = datetime.now(UTC)
    limits = await daily_limit(session, user.id, now)
    start = date.fromisoformat(limits["cycle_start"])
    end = date.fromisoformat(limits["cycle_end"])
    start_dt = datetime.combine(start, time.min, tzinfo=UTC)
    end_dt = datetime.combine(end + timedelta(days=1), datetime.min.time(), tzinfo=UTC)
    spent = await session.scalar(
        select(func.coalesce(func.sum(Expense.amount), 0)).where(
            Expense.user_id == user.id,
            Expense.deleted.is_(False),
            Expense.spent_at >= start_dt,
            Expense.spent_at < end_dt,
        )
    )
    spent = int(spent or 0)
    days_in_cycle = int(limits["days_in_cycle"])
    elapsed = max((now.date() - start).days + 1, 1)
    daily_average = spent / elapsed
    predicted = daily_average * days_in_cycle
    available = int(limits["budget"])
    overspend = max(predicted - available, 0.0)
    percent = (overspend / available * 100) if available > 0 else (100.0 if predicted > 0 else 0.0)
    remaining = int(limits["days_left"])
    tips = [
        f"Cut about {int(overspend / max(remaining, 1))} per day for the rest of the cycle.",
        "Review Food and Entertainment spends first — they are usually the easiest to trim.",
    ]
    return PredictionOut(
        total_spent=spent,
        available_budget=available,
        remaining_days=remaining,
        days_in_cycle=days_in_cycle,
        daily_average_spend=round(daily_average, 2),
        predicted_month_spend=round(predicted, 2),
        is_likely_to_overspend=predicted > available,
        overspend_amount=round(overspend, 2),
        overspend_percent=round(percent, 2),
        suggested_daily_cut=int(overspend / max(remaining, 1)),
        tips=tips,
    )


@router.get("/tips")
async def tips(user: CurrentUser, session: SessionDep) -> dict:
    result = await overspend(user, session)
    return {"tips": result.tips, "risk": result.is_likely_to_overspend}
