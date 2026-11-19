from functools import lru_cache

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "PocketPilot"
    app_env: str = "development"
    secret_key: str = "change-me-in-production"
    base_url: str = "http://localhost:8000"
    database_url: str = "postgresql+asyncpg://pocketpilot:pocketpilot@localhost:5432/pocketpilot"
    access_token_minutes: int = 30
    refresh_token_days: int = 30
    google_client_ids: str = ""
    cors_origins: str = "http://localhost,http://127.0.0.1"
    firebase_service_account_json: str = ""
    firebase_project_id: str = ""
    firebase_api_key: str = ""
    firebase_app_id: str = ""
    firebase_messaging_sender_id: str = ""
    firebase_storage_bucket: str = ""
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_from: str = "no-reply@example.com"
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.0-flash"
    redis_url: str = ""
    max_page_size: int = Field(default=200, ge=1, le=1000)

    @property
    def is_production(self) -> bool:
        return self.app_env.lower() == "production"

    @property
    def allowed_google_client_ids(self) -> list[str]:
        return [item.strip() for item in self.google_client_ids.split(",") if item.strip()]

    @property
    def allowed_origins(self) -> list[str]:
        return [item.strip() for item in self.cors_origins.split(",") if item.strip()]

    @field_validator("secret_key")
    @classmethod
    def reject_default_secret_in_production(cls, value: str, info) -> str:
        env = (info.data or {}).get("app_env", "development")
        if str(env).lower() == "production" and value == "change-me-in-production":
            raise ValueError("SECRET_KEY must be changed in production")
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()
