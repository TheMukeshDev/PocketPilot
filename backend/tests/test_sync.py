from datetime import UTC, datetime

ITEM = {
    "client_id": "sync-item-1",
    "entity": "expense",
    "action": "create",
    "payload": {
        "title": "Metro",
        "amount": 40,
        "category": "Travel",
        "date": datetime.now(UTC).isoformat(),
    },
    "version": 1,
}


def test_sync_batch_is_idempotent(client, auth_headers):
    headers = {**auth_headers, "Idempotency-Key": "client-key-123456"}
    first = client.post("/api/v1/sync/batch", json={"items": [ITEM]}, headers=headers)
    assert first.status_code == 200, first.text
    assert len(first.json()["applied"]) == 1
    assert first.json()["replayed"] is False

    second = client.post("/api/v1/sync/batch", json={"items": [ITEM]}, headers=headers)
    assert second.status_code == 200
    assert second.json()["replayed"] is True
    assert len(second.json()["applied"]) == 1

    listing = client.get("/api/v1/expenses", headers=auth_headers).json()
    assert sum(1 for item in listing if item["client_id"] == "sync-item-1") == 1


def test_sync_rejects_short_key(client, auth_headers):
    response = client.post(
        "/api/v1/sync/batch",
        json={"items": []},
        headers={**auth_headers, "Idempotency-Key": "short"},
    )
    assert response.status_code == 422
