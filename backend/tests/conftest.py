import os
from pathlib import Path

os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///./test_pocketpilot.db")
os.environ.setdefault("SECRET_KEY", "test-secret-key-for-unit-tests-only")
os.environ.setdefault("APP_ENV", "test")

import asyncio

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import create_async_engine

from app.db import models  # noqa: F401
from app.db.base import Base


@pytest.fixture(scope="session", autouse=True)
def _prepare_db():
    path = Path("test_pocketpilot.db")
    if path.exists():
        path.unlink()

    async def create():
        engine = create_async_engine(os.environ["DATABASE_URL"])
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        await engine.dispose()

    asyncio.run(create())
    yield
    if path.exists():
        path.unlink()


@pytest.fixture
def client():
    from app.main import app

    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def auth_headers(client):
    email = f"user{os.urandom(4).hex()}@example.com"
    response = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "StrongPass123!", "display_name": "Tester"},
    )
    assert response.status_code == 201, response.text
    login = client.post(
        "/api/v1/auth/token", data={"username": email, "password": "StrongPass123!"}
    )
    assert login.status_code == 200, login.text
    return {"Authorization": f"Bearer {login.json()['access_token']}"}
