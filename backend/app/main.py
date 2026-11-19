from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.errors import ApiError, api_error_handler, unhandled_error_handler
from app.db.session import dispose_engine, init_engine
from app.gateways.firebase import init_firebase
from app.modules.analytics.routes import router as analytics_router
from app.modules.auth.routes import router as auth_router
from app.modules.budgets.routes import router as budgets_router
from app.modules.challenges.routes import router as challenges_router
from app.modules.expenses.routes import router as expenses_router
from app.modules.gamification.routes import router as gamification_router
from app.modules.notifications.routes import router as notifications_router
from app.modules.ocr.routes import router as ocr_router
from app.modules.predictions.routes import router as predictions_router
from app.modules.reports.routes import router as reports_router
from app.modules.sync.routes import router as sync_router


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_engine()
    init_firebase()
    yield
    await dispose_engine()


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title=settings.app_name,
        version="1.0.0",
        lifespan=lifespan,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.allowed_origins,
        allow_credentials=False,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "Idempotency-Key"],
    )
    app.add_exception_handler(ApiError, api_error_handler)
    app.add_exception_handler(Exception, unhandled_error_handler)

    app.include_router(auth_router, prefix="/api/v1")
    app.include_router(expenses_router, prefix="/api/v1")
    app.include_router(budgets_router, prefix="/api/v1")
    app.include_router(sync_router, prefix="/api/v1")
    app.include_router(analytics_router, prefix="/api/v1")
    app.include_router(predictions_router, prefix="/api/v1")
    app.include_router(gamification_router, prefix="/api/v1")
    app.include_router(challenges_router, prefix="/api/v1")
    app.include_router(notifications_router, prefix="/api/v1")
    app.include_router(reports_router, prefix="/api/v1")
    app.include_router(ocr_router, prefix="/api/v1")

    @app.get("/api/v1/config/public")
    async def public_config() -> dict[str, str]:
        return {
            "firebaseApiKey": settings.firebase_api_key,
            "firebaseAppId": settings.firebase_app_id,
            "firebaseMessagingSenderId": settings.firebase_messaging_sender_id,
            "firebaseProjectId": settings.firebase_project_id,
            "firebaseStorageBucket": settings.firebase_storage_bucket,
        }

    @app.get("/health")
    async def health() -> dict:
        return {"status": "ok"}

    @app.get("/")
    async def root() -> dict:
        return {
            "name": settings.app_name,
            "status": "ok",
            "health": "/health",
            "api": "/api/v1",
        }

    @app.get("/health/ready")
    async def ready() -> dict:
        from sqlalchemy import text

        from app.db.session import get_session_factory

        async with get_session_factory()() as session:
            await session.execute(text("SELECT 1"))
        return {"status": "ready"}

    return app


app = create_app()
