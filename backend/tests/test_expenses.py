from datetime import UTC, datetime

EXPENSE = {
    "client_id": "device-expense-1",
    "title": "Lunch",
    "amount": 250,
    "category": "Food",
    "date": datetime.now(UTC).isoformat(),
}


def test_expense_crud_and_ownership(client, auth_headers):
    created = client.post("/api/v1/expenses", json=EXPENSE, headers=auth_headers)
    assert created.status_code == 201, created.text
    expense_id = created.json()["id"]

    listing = client.get("/api/v1/expenses", headers=auth_headers)
    assert listing.status_code == 200
    assert any(item["id"] == expense_id for item in listing.json())

    duplicate = client.post("/api/v1/expenses", json=EXPENSE, headers=auth_headers)
    assert duplicate.status_code in (200, 201)
    assert duplicate.json()["id"] == expense_id

    assert client.delete(f"/api/v1/expenses/{expense_id}", headers=auth_headers).status_code == 204
    assert all(
        item["id"] != expense_id
        for item in client.get("/api/v1/expenses", headers=auth_headers).json()
    )


def test_budget_and_daily_limit(client, auth_headers):
    saved = client.put(
        "/api/v1/budgets",
        json={"monthly_amount": 6000, "rent_amount": 2000, "cycle_start_day": 1, "currency": "INR"},
        headers=auth_headers,
    )
    assert saved.status_code == 200, saved.text
    limit = client.get("/api/v1/budgets/daily-limit", headers=auth_headers)
    assert limit.status_code == 200
    body = limit.json()
    assert body["budget"] == 4000
    assert body["days_left"] >= 1
    assert body["daily_limit"] >= 0


def test_prediction_and_report(client, auth_headers):
    client.post(
        "/api/v1/expenses", json={**EXPENSE, "client_id": "prediction-1"}, headers=auth_headers
    )
    prediction = client.get("/api/v1/predictions/overspend", headers=auth_headers)
    assert prediction.status_code == 200
    assert prediction.json()["available_budget"] == 0

    report = client.get("/api/v1/reports/monthly.pdf", headers=auth_headers)
    assert report.status_code == 200
    assert report.content.startswith(b"%PDF")
