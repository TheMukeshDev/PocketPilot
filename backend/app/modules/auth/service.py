from datetime import UTC, datetime, timedelta
from email.utils import parseaddr

from email_validator import EmailNotValidError, validate_email
from google.auth.exceptions import GoogleAuthError
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import ApiError
from app.core.security import (
    RESET_PASSWORD,
    VERIFY_EMAIL,
    create_access_token,
    hash_password_async,
    hash_refresh_token,
    make_link_token,
    new_auth_stamp,
    password_needs_rehash,
    read_link_token,
    verify_password_async,
)
from app.db.models import RefreshToken, User
from app.gateways.email import send_email


class EmailTakenError(Exception):
    pass


def normalize_email(email: str) -> str:
    try:
        return validate_email(email, check_deliverability=False).normalized.lower()
    except EmailNotValidError as exc:
        raise ApiError(status_code=400, detail="Invalid email address") from exc


async def get_by_email(session: AsyncSession, email: str) -> User | None:
    result = await session.execute(select(User).where(User.email == normalize_email(email)))
    return result.scalar_one_or_none()


async def create_user(
    session: AsyncSession, email: str, password: str, display_name: str | None = None
) -> User:
    user = User(
        email=normalize_email(email),
        password_hash=await hash_password_async(password),
        display_name=(display_name or "").strip()[:120] or None,
    )
    session.add(user)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise EmailTakenError from exc
    return user


async def authenticate(session: AsyncSession, email: str, password: str) -> User | None:
    user = await get_by_email(session, email)
    valid = await verify_password_async(user.password_hash if user else None, password)
    if user is None or not valid or not user.is_active:
        return None
    if user.password_hash and password_needs_rehash(user.password_hash):
        user.password_hash = await hash_password_async(password)
        await session.commit()
    return user


async def issue_tokens(session: AsyncSession, user: User) -> dict:
    settings = get_settings()
    refresh = new_auth_stamp() + new_auth_stamp()
    session.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_refresh_token(refresh),
            expires_at=datetime.now(UTC) + timedelta(days=settings.refresh_token_days),
        )
    )
    await session.commit()
    return {
        "access_token": create_access_token(user.id, user.auth_stamp),
        "refresh_token": refresh,
        "token_type": "bearer",
        "expires_in": settings.access_token_minutes * 60,
    }


async def rotate_refresh(session: AsyncSession, token: str) -> dict:
    result = await session.execute(
        select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(token))
    )
    record = result.scalar_one_or_none()
    if record is None or record.revoked_at is not None:
        raise ApiError(status_code=401, detail="Invalid refresh token", code="invalid_token")
    expires_at = record.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=UTC)
    if expires_at <= datetime.now(UTC):
        raise ApiError(status_code=401, detail="Expired refresh token", code="invalid_token")
    user = await session.get(User, record.user_id)
    if user is None or not user.is_active:
        raise ApiError(status_code=401, detail="Invalid refresh token", code="invalid_token")
    record.revoked_at = datetime.now(UTC)
    await session.flush()
    return await issue_tokens(session, user)


async def revoke_refresh(session: AsyncSession, token: str) -> None:
    result = await session.execute(
        select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(token))
    )
    record = result.scalar_one_or_none()
    if record is not None and record.revoked_at is None:
        record.revoked_at = datetime.now(UTC)
        await session.commit()


async def authenticate_google(session: AsyncSession, id_token_value: str) -> User:
    settings = get_settings()
    allowed = settings.allowed_google_client_ids
    if not allowed:
        raise ApiError(
            status_code=503,
            detail="Google sign-in is not configured on this server",
            code="google_not_configured",
        )
    try:
        claims = id_token.verify_oauth2_token(
            id_token_value, google_requests.Request(), audience=allowed[0]
        )
    except (ValueError, GoogleAuthError) as exc:
        raise ApiError(
            status_code=401, detail="Invalid Google token", code="invalid_token"
        ) from exc
    if claims.get("aud") not in allowed or not claims.get("email_verified"):
        raise ApiError(status_code=401, detail="Invalid Google token", code="invalid_token")
    email = claims.get("email")
    if not email:
        raise ApiError(status_code=401, detail="Invalid Google token", code="invalid_token")
    user = await get_by_email(session, str(email))
    if user is None:
        user = await create_user(
            session,
            str(email),
            new_auth_stamp() + new_auth_stamp(),
            str(claims.get("name") or "")[:120] or None,
        )
        user.email_verified_at = datetime.now(UTC)
        await session.commit()
    if not user.is_active:
        raise ApiError(status_code=403, detail="Account disabled")
    return user


async def send_verification_email(user: User) -> None:
    token = make_link_token(VERIFY_EMAIL, {"uid": user.id, "email": user.email})
    link = f"{get_settings().base_url.rstrip('/')}/api/v1/auth/verify-email?token={token}"
    await send_email(user.email, "Verify your PocketPilot email", f"Verify your email: {link}")


async def send_reset_email(user: User) -> None:
    token = make_link_token(RESET_PASSWORD, {"uid": user.id, "stamp": user.auth_stamp})
    link = f"{get_settings().base_url.rstrip('/')}/reset-password?token={token}"
    await send_email(user.email, "Reset your PocketPilot password", f"Reset your password: {link}")


async def verify_email(session: AsyncSession, token: str) -> bool:
    data = read_link_token(VERIFY_EMAIL, token, 48 * 3600)
    if data is None:
        return False
    user = await session.get(User, str(data.get("uid", "")))
    if user is None or user.email != data.get("email"):
        return False
    if user.email_verified_at is None:
        user.email_verified_at = datetime.now(UTC)
        await session.commit()
    return True


async def reset_password(session: AsyncSession, token: str, new_password: str) -> bool:
    data = read_link_token(RESET_PASSWORD, token, 3600)
    if data is None:
        return False
    user = await session.get(User, str(data.get("uid", "")))
    if user is None or user.auth_stamp != data.get("stamp"):
        return False
    user.password_hash = await hash_password_async(new_password)
    user.auth_stamp = new_auth_stamp()
    await session.commit()
    return True


def parse_display_name(value: str | None) -> str | None:
    if not value:
        return None
    name = parseaddr(value)[1] or value
    return name.strip()[:120] or None
