import json
import logging
from typing import Any

from firebase_admin import credentials, firestore, get_app, initialize_app

from app.core.config import get_settings

logger = logging.getLogger(__name__)
_initialized = False


def firebase_configured() -> bool:
    return bool(get_settings().firebase_service_account_json.strip())


def init_firebase() -> bool:
    global _initialized
    if _initialized:
        return True
    if not firebase_configured():
        return False
    try:
        get_app()
        _initialized = True
        return True
    except ValueError:
        pass
    try:
        settings = get_settings()
        service_account = json.loads(settings.firebase_service_account_json)
        cred = credentials.Certificate(service_account)
        options: dict[str, Any] = {}
        project_id = settings.firebase_project_id or service_account.get("project_id")
        if project_id:
            options["projectId"] = project_id
        initialize_app(cred, options or None)
        _initialized = True
        return True
    except Exception as exc:
        logger.error("Firebase Admin initialization failed: %s", type(exc).__name__)
        return False


def get_firestore() -> Any | None:
    if not init_firebase():
        return None
    return firestore.client()
