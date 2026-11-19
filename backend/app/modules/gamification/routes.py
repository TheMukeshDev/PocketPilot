from datetime import UTC, date, datetime, timedelta

from fastapi import APIRouter
from sqlalchemy import func, select

from app.core.deps import CurrentUser, SessionDep
from app.db.models import Badge, Expense, PointsEvent, UserBadge
from app.schemas import BadgeOut, GamificationOut

router = APIRouter(prefix="/gamification", tags=["gamification"])


@router.get("", response_model=GamificationOut)
async def gamification(user: CurrentUser, session: SessionDep) -> GamificationOut:
    total = int(
        (
            await session.scalar(
                select(func.coalesce(func.sum(PointsEvent.points), 0)).where(
                    PointsEvent.user_id == user.id
                )
            )
        )
        or 0
    )
    rows = (
        await session.execute(
            select(func.date(Expense.spent_at))
            .where(Expense.user_id == user.id, Expense.deleted.is_(False))
            .order_by(Expense.spent_at.desc())
        )
    ).all()
    days = sorted({str(row[0]) for row in rows}, reverse=True)
    current_streak = 0
    cursor = datetime.now(UTC).date()
    for day in days:
        parsed = date.fromisoformat(day)
        if parsed == cursor:
            current_streak += 1
            cursor -= timedelta(days=1)
        elif parsed < cursor:
            break
    badges = (
        await session.scalars(
            select(Badge)
            .join(UserBadge, UserBadge.badge_id == Badge.id)
            .where(UserBadge.user_id == user.id)
        )
    ).all()
    return GamificationOut(
        total_points=total,
        current_streak=current_streak,
        best_streak=current_streak,
        badges=[BadgeOut.model_validate(badge) for badge in badges],
    )


@router.post("/points")
async def award_points(
    payload: dict,
    user: CurrentUser,
    session: SessionDep,
) -> dict:
    reason = str(payload.get("reason", ""))[:80]
    points = int(payload.get("points", 0))
    if not reason or points <= 0:
        from app.core.errors import ApiError

        raise ApiError(status_code=400, detail="reason and positive points are required")
    event_date = str(payload.get("date") or datetime.now(UTC).date().isoformat())[:10]
    existing = await session.scalar(
        select(PointsEvent).where(
            PointsEvent.user_id == user.id,
            PointsEvent.reason == reason,
            PointsEvent.event_date == event_date,
        )
    )
    if existing is not None:
        return {"awarded": 0, "duplicate": True}
    session.add(PointsEvent(user_id=user.id, reason=reason, points=points, event_date=event_date))
    await session.commit()
    return {"awarded": points, "duplicate": False}
