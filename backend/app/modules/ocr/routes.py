from fastapi import APIRouter, File, UploadFile

from app.core.deps import CurrentUser
from app.gateways.gemini import classify_receipt

router = APIRouter(prefix="/ocr", tags=["ocr"])

MAX_BYTES = 5 * 1024 * 1024
ALLOWED = {"image/jpeg", "image/png", "image/webp"}


@router.post("/receipt")
async def receipt(
    _user: CurrentUser,
    file: UploadFile = File(...),
    ocr_amount: int | None = None,
    ocr_title: str | None = None,
    ocr_category: str | None = None,
) -> dict:
    if file.content_type not in ALLOWED:
        from app.core.errors import ApiError

        raise ApiError(status_code=415, detail="Unsupported image type")
    content = await file.read(MAX_BYTES + 1)
    if len(content) > MAX_BYTES:
        from app.core.errors import ApiError

        raise ApiError(status_code=413, detail="Image too large")
    result = await classify_receipt(
        content,
        file.content_type or "image/jpeg",
        {"amount": ocr_amount, "title": ocr_title, "category": ocr_category},
    )
    return result
