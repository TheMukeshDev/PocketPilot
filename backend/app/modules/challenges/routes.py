from datetime import UTC, datetime

from fastapi import APIRouter
from sqlalchemy import select

from app.core.deps import CurrentUser, SessionDep
from app.db.models import Challenge, ChallengeProgress
from app.schemas import ChallengeOut, ChallengeProgressOut

router = APIRouter(prefix="/challenges", tags=["challenges"])

SEED = [
    {
        "code": "daily_under_budget",
        "title": "Stay under budget",
        "description": "Keep today's spending at or below your daily limit.",
        "period": "daily",
        "target": 1,
        "points": 20,
    },
    {
        "code": "weekly_save_300",
        "title": "Save 300 this week",
        "description": "Spend 300 less than your planned weekly budget.",
        "period": "weekly",
        "target": 300,
        "points": 40,
    },
]


async def ensure_seeded(session) -> None:
    for item in SEED:
        existing = await session.scalar(select(Challenge).where(Challenge.code == item["code"]))
        if existing is None:
            session.add(Challenge(**item, is_active=True))
    await session.commit()


@router.get("/active", response_model=list[ChallengeOut])
async def active_challenges(user: CurrentUser, session: SessionDep) -> list[ChallengeOut]:
    await ensure_seeded(session)
    rows = (await session.scalars(select(Challenge).where(Challenge.is_active.is_(True)))).all()
    return [ChallengeOut.model_validate(row) for row in rows]


@router.get("/progress", response_model=list[ChallengeProgressOut])
async def challenge_progress(user: CurrentUser, session: SessionDep) -> list[ChallengeProgressOut]:
    await ensure_seeded(session)
    rows = (
        await session.execute(
            select(ChallengeProgress, Challenge)
            .join(Challenge, Challenge.id == ChallengeProgress.challenge_id)
            .where(ChallengeProgress.user_id == user.id)
            .order_by(ChallengeProgress.period_key.desc())
            .limit(50)
        )
    ).all()
    result = []
    for progress, challenge in rows:
        result.append(
            ChallengeProgressOut(
                challenge_id=challenge.id,
                period_key=progress.period_key,
                progress=progress.progress,
                target=challenge.target,
                completed=progress.completed,
                points=challenge.points,
            )
        )
    return result


@router.post("/{challenge_id}/progress", response_model=ChallengeProgressOut)
async def update_progress(
    challenge_id: str,
    payload: dict,
    user: CurrentUser,
    session: SessionDep,
) -> ChallengeProgressOut:
    await ensure_seeded(session)
    challenge = await session.get(Challenge, challenge_id)
    if challenge is None or not challenge.is_active:
        from app.core.errors import ApiError

        raise ApiError(status_code=404, detail="Challenge not found")
    now = datetime.now(UTC)
    period_key = now.strftime("%Y-%m-%d") if challenge.period == "daily" else now.strftime("%Y-W%W")
    result = await session.scalar(
        select(ChallengeProgress).where(
            ChallengeProgress.user_id == user.id,
            ChallengeProgress.challenge_id == challenge_id,
            ChallengeProgress.period_key == period_key,
        )
    )
    if result is None:
        result = ChallengeProgress(
            user_id=user.id, challenge_id=challenge_id, period_key=period_key
        )
        session.add(result)
    result.progress = max(int(payload.get("progress", 0)), 0)
    result.completed = result.progress >= challenge.target
    if result.completed:
        from app.modules.gamification.routes import award_points

        await award_points(
            {
                "reason": f"challenge:{challenge.code}",
                "points": challenge.points,
                "date": now.date().isoformat(),
            },
            user,
            session,
        )
    await session.commit()
    return ChallengeProgressOut(
        challenge_id=challenge.id,
        period_key=result.period_key,
        progress=result.progress,
        target=challenge.target,
        completed=result.completed,
        points=challenge.points,
    )
