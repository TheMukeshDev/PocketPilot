from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.gateways.gemini import CATEGORIES

CATEGORY_LIST = sorted(CATEGORIES)


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class RegisterIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str | None = Field(default=None, max_length=120)


class GoogleIn(BaseModel):
    id_token: str = Field(min_length=10, max_length=8192)


class ForgotIn(BaseModel):
    email: EmailStr


class ResetIn(BaseModel):
    token: str
    new_password: str = Field(min_length=8, max_length=128)


class TokenOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class RefreshIn(BaseModel):
    refresh_token: str


class MeOut(ORMModel):
    id: str
    email: EmailStr
    display_name: str | None
    email_verified: bool
    created_at: datetime


class MeUpdate(BaseModel):
    display_name: str | None = Field(default=None, max_length=120)


class ExpenseIn(BaseModel):
    client_id: str = Field(min_length=1, max_length=80)
    title: str = Field(min_length=1, max_length=200)
    amount: int = Field(gt=0, le=100_000_000)
    category: str = "Other"
    date: datetime
    payment_app: str | None = Field(default=None, max_length=40)
    version: int = Field(default=1, ge=1)

    @field_validator("category")
    @classmethod
    def check_category(cls, value: str) -> str:
        return value if value in CATEGORY_LIST else "Other"


class ExpenseOut(ORMModel):
    id: str
    client_id: str
    title: str
    amount: int
    category: str
    date: datetime = Field(validation_alias="spent_at")
    payment_app: str | None
    version: int
    updated_at: datetime


class BudgetIn(BaseModel):
    monthly_amount: int = Field(ge=0, le=100_000_000)
    rent_amount: int = Field(ge=0, le=100_000_000)
    cycle_start_day: int = Field(default=1, ge=1, le=28)
    currency: str = Field(default="INR", max_length=8)
    version: int = Field(default=1, ge=1)


class BudgetOut(ORMModel):
    monthly_amount: int
    rent_amount: int
    cycle_start_day: int
    currency: str
    version: int
    updated_at: datetime


class DailyLimitOut(BaseModel):
    budget: int
    spent: int
    remaining: int
    days_left: int
    daily_limit: int


class SyncItem(BaseModel):
    client_id: str = Field(min_length=1, max_length=80)
    entity: str = Field(pattern="^(expense|budget)$")
    action: str = Field(pattern="^(create|update|delete)$")
    payload: dict
    version: int = Field(default=1, ge=1)


class SyncBatchIn(BaseModel):
    items: list[SyncItem] = Field(default_factory=list, max_length=500)


class SyncApplied(BaseModel):
    client_id: str
    entity: str
    id: str
    version: int


class SyncConflict(BaseModel):
    client_id: str
    reason: str
    server: dict | None = None


class SyncBatchOut(BaseModel):
    applied: list[SyncApplied]
    conflicts: list[SyncConflict]
    cursor: datetime
    replayed: bool = False


class SyncChange(BaseModel):
    entity: str
    id: str
    client_id: str | None
    data: dict
    version: int
    updated_at: datetime
    deleted: bool = False


class SyncChangesOut(BaseModel):
    changes: list[SyncChange]
    cursor: datetime


class PredictionOut(BaseModel):
    total_spent: int
    available_budget: int
    remaining_days: int
    days_in_cycle: int
    daily_average_spend: float
    predicted_month_spend: float
    is_likely_to_overspend: bool
    overspend_amount: float
    overspend_percent: float
    suggested_daily_cut: int
    tips: list[str]


class BadgeOut(ORMModel):
    code: str
    name: str
    description: str


class GamificationOut(BaseModel):
    total_points: int
    current_streak: int
    best_streak: int
    badges: list[BadgeOut]


class ChallengeOut(ORMModel):
    id: str
    code: str
    title: str
    description: str
    period: str
    target: int
    points: int


class ChallengeProgressOut(BaseModel):
    challenge_id: str
    period_key: str
    progress: int
    target: int
    completed: bool
    points: int


class NotificationOut(ORMModel):
    id: str
    title: str
    body: str
    kind: str
    is_read: bool
    created_at: datetime


class NotificationPrefsIn(BaseModel):
    daily_reminder: bool = True
    threshold_alerts: bool = True
    challenge_alerts: bool = True
    quiet_hours_start: str | None = Field(default=None, pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    quiet_hours_end: str | None = Field(default=None, pattern=r"^([01]\d|2[0-3]):[0-5]\d$")


class NotificationPrefsOut(ORMModel):
    daily_reminder: bool
    threshold_alerts: bool
    challenge_alerts: bool
    quiet_hours_start: str | None
    quiet_hours_end: str | None
