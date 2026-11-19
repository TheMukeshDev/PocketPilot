from datetime import UTC, datetime
from io import BytesIO

from fastapi import APIRouter
from fastapi.responses import Response
from sqlalchemy import func, select

from app.core.deps import CurrentUser, SessionDep
from app.db.models import Expense

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/monthly.pdf")
async def monthly_pdf(
    user: CurrentUser,
    session: SessionDep,
    month: str = "",
) -> Response:
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfgen import canvas

    if month:
        try:
            start = datetime.strptime(month, "%Y-%m").replace(tzinfo=UTC)
        except ValueError:
            from app.core.errors import ApiError

            raise ApiError(status_code=400, detail="month must be YYYY-MM") from None
    else:
        now = datetime.now(UTC)
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    end = (
        start.replace(year=start.year + 1, month=1)
        if start.month == 12
        else start.replace(month=start.month + 1)
    )
    rows = (
        await session.execute(
            select(Expense.category, func.sum(Expense.amount), func.count(Expense.id))
            .where(
                Expense.user_id == user.id,
                Expense.deleted.is_(False),
                Expense.spent_at >= start,
                Expense.spent_at < end,
            )
            .group_by(Expense.category)
            .order_by(func.sum(Expense.amount).desc())
        )
    ).all()

    buffer = BytesIO()
    pdf = canvas.Canvas(buffer, pagesize=A4)
    pdf.setTitle("PocketPilot Monthly Report")
    pdf.setFont("Helvetica-Bold", 18)
    pdf.drawString(50, 800, "PocketPilot Monthly Report")
    pdf.setFont("Helvetica", 11)
    pdf.drawString(50, 780, start.strftime("%B %Y"))
    y = 750
    total = 0
    for category, amount, count in rows:
        value = int(amount or 0)
        total += value
        pdf.drawString(50, y, f"{category}  ({count} expenses)")
        pdf.drawRightString(545, y, str(value))
        y -= 22
        if y < 60:
            pdf.showPage()
            y = 800
    pdf.setFont("Helvetica-Bold", 12)
    pdf.drawString(50, y - 10, "Total")
    pdf.drawRightString(545, y - 10, str(total))
    pdf.save()
    return Response(
        content=buffer.getvalue(),
        media_type="application/pdf",
        headers={"Content-Disposition": 'attachment; filename="pocketpilot-report.pdf"'},
    )
