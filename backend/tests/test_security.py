import json

from app.core.config import get_settings
from app.gateways.firebase import firebase_configured, init_firebase


def test_firebase_admin_disabled_without_service_account(monkeypatch):
    monkeypatch.delenv("FIREBASE_SERVICE_ACCOUNT_JSON", raising=False)
    get_settings.cache_clear()
    try:
        assert firebase_configured() is False
        assert init_firebase() is False
    finally:
        get_settings.cache_clear()


def test_public_config_does_not_expose_secrets(client):
    response = client.get("/api/v1/config/public")
    assert response.status_code == 200
    body = json.dumps(response.json()).lower()
    assert "private" not in body
    assert "service_account" not in body
    assert "secret" not in body
