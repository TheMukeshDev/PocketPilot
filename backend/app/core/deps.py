import time
from collections import defaultdict, deque
from typing import Annotated

from fastapi import Depends, HTTPException, Query, Request, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decode_access_token
from app.db.models import User
from app.db.session import get_session

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/token", auto_error=False)


class _RateLimiter:
    def __init__(self, max_attempts: int, window_seconds: int = 900):
        self.max_attempts = max_attempts
        self.window_seconds = window_seconds
        self._attempts: dict[str, deque[float]] = defaultdict(deque)

    def is_blocked(self, key: str) -> bool:
        return len(self._prune(key)) >= self.max_attempts

    def hit(self, key: str) -> None:
        self._prune(key).append(time.monotonic())

    def reset(self, key: str) -> None:
        self._attempts.pop(key, None)

    def _prune(self, key: str) -> deque[float]:
        bucket = self._attempts[key]
        cutoff = time.monotonic() - self.window_seconds
        while bucket and bucket[0] <= cutoff:
            bucket.popleft()
        return bucket


login_limiter = _RateLimiter(max_attempts=10)
email_limiter = _RateLimiter(max_attempts=5, window_seconds=3600)


def client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


async def get_current_user(
    session: Annotated[AsyncSession, Depends(get_session)],
    token: Annotated[str | None, Depends(oauth2_scheme)] = None,
) -> User:
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Not authenticated",
        headers={"WWW-Authenticate": "Bearer"},
    )
    payload = decode_access_token(token) if token else None
    if payload is None:
        raise unauthorized
    try:
        user_id = str(payload["sub"])
    except (KeyError, TypeError):
        raise unauthorized from None
    user = await session.get(User, user_id)
    if user is None or not user.is_active or user.auth_stamp != payload.get("stamp"):
        raise unauthorized
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
SessionDep = Annotated[AsyncSession, Depends(get_session)]


def pagination(
    limit: Annotated[int, Query(ge=1, le=500)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> tuple[int, int]:
    return limit, offset


Page = Annotated[tuple[int, int], Depends(pagination)]


async def get_user_by_email(session: AsyncSession, email: str) -> User | None:
    result = await session.execute(select(User).where(User.email == email.lower().strip()))
    return result.scalar_one_or_none()
