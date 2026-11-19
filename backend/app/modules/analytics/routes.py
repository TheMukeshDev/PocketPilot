from datetime import UTC, datetime, timedelta

from fastapi import APIRouter
from sqlalchemy import func, select

from app.core.deps import CurrentUser, SessionDep
from app.db.models import Expense
from app.schemas import PredictionOut

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/spending")
async def spending(
    user: CurrentUser,
    session: SessionDep,
    days: int = 30,
) -> dict:
    start = datetime.now(UTC) - timedelta(days=days)
    rows = (
        await session.execute(
            select(Expense.category, func.sum(Expense.amount), func.count(Expense.id))
            .where(
                Expense.user_id == user.id,
                Expense.deleted.is_(False),
                Expense.spent_at >= start,
            )
            .group_by(Expense.category)
            .order_by(func.sum(Expense.amount).desc())
        )
    ).all()
    total = sum(int(row[1] or 0) for row in rows)
    return {
        "total": total,
        "categories": [
            {
                "category": row[0],
                "amount": int(row[1] or 0),
                "count": int(row[2] or 0),
                "percent": round(int(row[1] or 0) / total * 100, 2) if total else 0,
            }
            for row in rows
        ],
    }


@router.get("/trends")
async def trends(user: CurrentUser, session: SessionDep, days: int = 28) -> dict:
    start = (datetime.now(UTC) - timedelta(days=days)).date()
    rows = (
        await session.execute(
            select(func.date(Expense.spent_at), func.sum(Expense.amount))
            .where(
                Expense.user_id == user.id,
                Expense.deleted.is_(False),
                Expense.spent_at >= datetime.combine(start, datetime.min.time(), tzinfo=UTC),
            )
            .group_by(func.date(Expense.spent_at))
            .order_by(func.date(Expense.spent_at))
        )
    ).all()
    return {"points": [{"date": str(row[0]), "amount": int(row[1] or 0)} for row in rows]}


@router.get("/health-score")
async def health_score(user: CurrentUser, session: SessionDep) -> dict:
    from app.modules.predictions.routes import overspend

    result: PredictionOut = await overspend(user, session)
    score = 100.0
    if result.is_likely_to_overspend:
        score = max(0.0, 100.0 - min(result.overspend_percent, 100.0))
    return {"score": round(score), "label": "healthy" if score >= 70 else "at_risk"}
