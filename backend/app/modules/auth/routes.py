from fastapi import APIRouter, Depends, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel

from app.core.deps import CurrentUser, SessionDep, client_ip, email_limiter, login_limiter
from app.core.errors import ApiError
from app.core.security import new_auth_stamp
from app.db.session import get_session_factory
from app.modules.auth import service as auth
from app.schemas import (
    ForgotIn,
    GoogleIn,
    MeOut,
    MeUpdate,
    RefreshIn,
    RegisterIn,
    ResetIn,
    TokenOut,
)

router = APIRouter(prefix="/auth", tags=["auth"])


class LogoutIn(BaseModel):
    refresh_token: str | None = None


def _me_out(user) -> MeOut:
    return MeOut(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        email_verified=user.email_verified_at is not None,
        created_at=user.created_at,
    )


@router.post("/register", response_model=MeOut, status_code=status.HTTP_201_CREATED)
async def register(payload: RegisterIn, session: SessionDep) -> MeOut:
    try:
        user = await auth.create_user(
            session, payload.email, payload.password, payload.display_name
        )
    except auth.EmailTakenError as exc:
        raise ApiError(status_code=409, detail="Email already registered") from exc
    await auth.send_verification_email(user)
    return _me_out(user)


@router.post("/token", response_model=TokenOut)
async def token(
    request: Request,
    session: SessionDep,
    form: OAuth2PasswordRequestForm = Depends(),
) -> TokenOut:
    key = f"{client_ip(request)}:{form.username.strip().lower()}"
    if login_limiter.is_blocked(key):
        raise ApiError(status_code=429, detail="Too many attempts", code="rate_limited")
    user = await auth.authenticate(session, form.username, form.password)
    if user is None:
        login_limiter.hit(key)
        raise ApiError(
            status_code=401, detail="Invalid email or password", code="invalid_credentials"
        )
    login_limiter.reset(key)
    return TokenOut.model_validate(await auth.issue_tokens(session, user))


@router.post("/refresh", response_model=TokenOut)
async def refresh(payload: RefreshIn, session: SessionDep) -> TokenOut:
    return TokenOut.model_validate(await auth.rotate_refresh(session, payload.refresh_token))


@router.post("/google", response_model=TokenOut)
async def google(payload: GoogleIn, session: SessionDep) -> TokenOut:
    user = await auth.authenticate_google(session, payload.id_token)
    return TokenOut.model_validate(await auth.issue_tokens(session, user))


@router.get("/verify-email")
async def verify_email(token: str) -> dict:
    async with get_session_factory()() as session:
        ok = await auth.verify_email(session, token)
    if not ok:
        raise ApiError(status_code=400, detail="Invalid or expired verification link")
    return {"verified": True}


@router.post("/forgot-password")
async def forgot_password(payload: ForgotIn, request: Request, session: SessionDep) -> dict:
    key = f"reset:{client_ip(request)}"
    if email_limiter.is_blocked(key):
        raise ApiError(status_code=429, detail="Too many attempts", code="rate_limited")
    email_limiter.hit(key)
    user = await auth.get_by_email(session, payload.email)
    if user is not None and user.is_active:
        await auth.send_reset_email(user)
    return {"sent": True}


@router.post("/reset-password")
async def reset_password(payload: ResetIn, session: SessionDep) -> dict:
    ok = await auth.reset_password(session, payload.token, payload.new_password)
    if not ok:
        raise ApiError(status_code=400, detail="Invalid or expired reset link")
    return {"reset": True}


@router.get("/me", response_model=MeOut)
async def me(user: CurrentUser) -> MeOut:
    return _me_out(user)


@router.patch("/me", response_model=MeOut)
async def update_me(payload: MeUpdate, user: CurrentUser, session: SessionDep) -> MeOut:
    if payload.display_name is not None:
        user.display_name = payload.display_name.strip()[:120] or None
        await session.commit()
    return _me_out(user)


@router.post("/logout")
async def logout(payload: LogoutIn, user: CurrentUser, session: SessionDep) -> dict:
    if payload.refresh_token:
        await auth.revoke_refresh(session, payload.refresh_token)
    user.auth_stamp = new_auth_stamp()
    await session.commit()
    return {"logged_out": True}


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_me(user: CurrentUser, session: SessionDep) -> None:
    await session.delete(user)
    await session.commit()
