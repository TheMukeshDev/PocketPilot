import json
import re

import httpx

from app.core.config import get_settings

CATEGORIES = {
    "Food",
    "Travel",
    "Shopping",
    "Recharge",
    "Medical",
    "Utilities",
    "Entertainment",
    "Study",
    "Personal",
    "Other",
}


async def classify_receipt(image_bytes: bytes, mime_type: str, hints: dict) -> dict:
    settings = get_settings()
    if not settings.gemini_api_key:
        return {
            "available": False,
            "title": None,
            "amount": None,
            "date": None,
            "category": "Other",
        }
    prompt = (
        "Return only one compact JSON object with keys amount, title, date, category. "
        f"category must be one of {sorted(CATEGORIES)}. date is YYYY-MM-DD or null. "
        f"OCR hints: {json.dumps(hints)}"
    )
    payload = {
        "contents": [
            {
                "parts": [
                    {"inline_data": {"mime_type": mime_type, "data": _b64(image_bytes)}},
                    {"text": prompt},
                ]
            }
        ],
        "generationConfig": {"temperature": 0.1, "maxOutputTokens": 200},
    }
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{settings.gemini_model}:generateContent?key={settings.gemini_api_key}"
    )
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.post(url, json=payload)
        response.raise_for_status()
        content = response.json()["candidates"][0]["content"]["parts"][0]["text"]
    match = re.search(r"\{[^{}]+\}", content, flags=re.DOTALL)
    if not match:
        return {"available": True, "title": None, "amount": None, "date": None, "category": "Other"}
    data = json.loads(match.group(0))
    category = data.get("category")
    return {
        "available": True,
        "amount": int(data["amount"]) if isinstance(data.get("amount"), (int, float)) else None,
        "title": str(data.get("title") or "")[:200] or None,
        "date": str(data.get("date"))[:10] if data.get("date") else None,
        "category": category if category in CATEGORIES else "Other",
    }


def _b64(data: bytes) -> str:
    import base64

    return base64.b64encode(data).decode("ascii")
