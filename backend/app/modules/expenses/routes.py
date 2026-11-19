from datetime import datetime

from fastapi import APIRouter, status

from app.core.deps import CurrentUser, Page, SessionDep
from app.modules.expenses import service as expenses
from app.schemas import ExpenseIn, ExpenseOut

router = APIRouter(prefix="/expenses", tags=["expenses"])


@router.get("", response_model=list[ExpenseOut])
async def list_expenses(
    session: SessionDep,
    user: CurrentUser,
    page: Page,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
    category: str | None = None,
    search: str | None = None,
) -> list[ExpenseOut]:
    limit, offset = page
    items = await expenses.list_expenses(
        session, user.id, limit, offset, date_from, date_to, category, search
    )
    return [ExpenseOut.model_validate(item) for item in items]


@router.post("", response_model=ExpenseOut, status_code=status.HTTP_201_CREATED)
async def create_expense(payload: ExpenseIn, user: CurrentUser, session: SessionDep) -> ExpenseOut:
    return ExpenseOut.model_validate(await expenses.upsert(session, user.id, payload))


@router.put("/{expense_id}", response_model=ExpenseOut)
async def update_expense(
    expense_id: str, payload: ExpenseIn, user: CurrentUser, session: SessionDep
) -> ExpenseOut:
    existing = await expenses.get_owned(session, user.id, expense_id)
    if existing.client_id != payload.client_id:
        payload = payload.model_copy(update={"client_id": existing.client_id})
    return ExpenseOut.model_validate(await expenses.upsert(session, user.id, payload))


@router.delete("/{expense_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_expense(expense_id: str, user: CurrentUser, session: SessionDep) -> None:
    expense = await expenses.get_owned(session, user.id, expense_id)
    await expenses.soft_delete(session, expense)
