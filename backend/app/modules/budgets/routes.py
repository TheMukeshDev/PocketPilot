from datetime import UTC, datetime

from fastapi import APIRouter

from app.core.deps import CurrentUser, SessionDep
from app.modules.budgets import service as budgets
from app.schemas import BudgetIn, BudgetOut, DailyLimitOut

router = APIRouter(prefix="/budgets", tags=["budgets"])


@router.get("", response_model=BudgetOut)
async def get_budget(user: CurrentUser, session: SessionDep) -> BudgetOut:
    return BudgetOut.model_validate(await budgets.get_budget(session, user.id))


@router.put("", response_model=BudgetOut)
async def put_budget(payload: BudgetIn, user: CurrentUser, session: SessionDep) -> BudgetOut:
    budget = await budgets.save_budget(session, user.id, payload.model_dump())
    return BudgetOut.model_validate(budget)


@router.get("/daily-limit", response_model=DailyLimitOut)
async def get_daily_limit(user: CurrentUser, session: SessionDep) -> DailyLimitOut:
    result = await budgets.daily_limit(session, user.id, datetime.now(UTC))
    return DailyLimitOut(**result)
