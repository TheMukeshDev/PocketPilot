from fastapi import APIRouter, status
from sqlalchemy import select

from app.core.deps import CurrentUser, Page, SessionDep
from app.db.models import Notification, NotificationPreference
from app.schemas import NotificationOut, NotificationPrefsIn, NotificationPrefsOut

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=list[NotificationOut])
async def list_notifications(
    user: CurrentUser, session: SessionDep, page: Page
) -> list[NotificationOut]:
    limit, offset = page
    rows = (
        await session.scalars(
            select(Notification)
            .where(Notification.user_id == user.id)
            .order_by(Notification.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
    ).all()
    return [NotificationOut.model_validate(row) for row in rows]


@router.post("", response_model=NotificationOut, status_code=status.HTTP_201_CREATED)
async def create_notification(
    payload: dict, user: CurrentUser, session: SessionDep
) -> NotificationOut:
    note = Notification(
        user_id=user.id,
        title=str(payload.get("title", ""))[:160],
        body=str(payload.get("body", ""))[:600],
        kind=str(payload.get("kind", "info"))[:40],
    )
    session.add(note)
    await session.commit()
    return NotificationOut.model_validate(note)


@router.post("/{notification_id}/read", response_model=NotificationOut)
async def mark_read(
    notification_id: str, user: CurrentUser, session: SessionDep
) -> NotificationOut:
    note = await session.get(Notification, notification_id)
    if note is None or note.user_id != user.id:
        from app.core.errors import ApiError

        raise ApiError(status_code=404, detail="Notification not found")
    note.is_read = True
    await session.commit()
    return NotificationOut.model_validate(note)


@router.get("/preferences", response_model=NotificationPrefsOut)
async def get_preferences(user: CurrentUser, session: SessionDep) -> NotificationPrefsOut:
    prefs = await session.scalar(
        select(NotificationPreference).where(NotificationPreference.user_id == user.id)
    )
    if prefs is None:
        prefs = NotificationPreference(user_id=user.id)
        session.add(prefs)
        await session.commit()
    return NotificationPrefsOut.model_validate(prefs)


@router.put("/preferences", response_model=NotificationPrefsOut)
async def put_preferences(
    payload: NotificationPrefsIn, user: CurrentUser, session: SessionDep
) -> NotificationPrefsOut:
    prefs = await session.scalar(
        select(NotificationPreference).where(NotificationPreference.user_id == user.id)
    )
    if prefs is None:
        prefs = NotificationPreference(user_id=user.id)
        session.add(prefs)
    for key, value in payload.model_dump().items():
        setattr(prefs, key, value)
    await session.commit()
    return NotificationPrefsOut.model_validate(prefs)
