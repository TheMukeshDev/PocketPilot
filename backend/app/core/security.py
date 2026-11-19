import asyncio
import hashlib
import secrets
from datetime import UTC, datetime, timedelta
from typing import Any

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError
from itsdangerous import BadSignature, URLSafeTimedSerializer

from app.core.config import get_settings

_hasher = PasswordHasher()
_DUMMY_HASH = _hasher.hash("timing-equalization-placeholder")
VERIFY_EMAIL = "verify-email"
RESET_PASSWORD = "reset-password"


def new_auth_stamp() -> str:
    return secrets.token_hex(16)


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password_hash: str | None, password: str) -> bool:
    try:
        _hasher.verify(password_hash or _DUMMY_HASH, password)
    except (VerificationError, InvalidHashError):
        return False
    return password_hash is not None


def password_needs_rehash(password_hash: str) -> bool:
    return _hasher.check_needs_rehash(password_hash)


async def hash_password_async(password: str) -> str:
    return await asyncio.to_thread(hash_password, password)


async def verify_password_async(password_hash: str | None, password: str) -> bool:
    return await asyncio.to_thread(verify_password, password_hash, password)


def create_access_token(user_id: str, auth_stamp: str) -> str:
    settings = get_settings()
    now = datetime.now(UTC)
    payload = {
        "sub": str(user_id),
        "stamp": auth_stamp,
        "type": "access",
        "iat": now,
        "exp": now + timedelta(minutes=settings.access_token_minutes),
    }
    return jwt.encode(payload, settings.secret_key, algorithm="HS256")


def decode_access_token(token: str) -> dict[str, Any] | None:
    try:
        payload = jwt.decode(
            token,
            get_settings().secret_key,
            algorithms=["HS256"],
            options={"require": ["exp", "sub"]},
        )
    except jwt.PyJWTError:
        return None
    if payload.get("type") != "access":
        return None
    return payload


def make_link_token(purpose: str, data: dict[str, Any]) -> str:
    return URLSafeTimedSerializer(get_settings().secret_key, salt=purpose).dumps(data)


def read_link_token(purpose: str, token: str, max_age_seconds: int) -> dict[str, Any] | None:
    try:
        data = URLSafeTimedSerializer(get_settings().secret_key, salt=purpose).loads(
            token, max_age=max_age_seconds
        )
    except BadSignature:
        return None
    return data if isinstance(data, dict) else None


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()
