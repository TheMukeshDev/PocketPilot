# PocketPilot Backend

FastAPI service that owns secrets and cloud state for PocketPilot. The Flutter app remains local-first and works without this service.

## Run locally

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements-dev.txt
copy .env.example .env
alembic upgrade head
uvicorn app.main:app --reload --port 8000
```

Health check: `http://localhost:8000/health`

## Docker

```bash
copy .env.example .env
docker compose up --build
```

The API is available at `http://localhost:8000`.

## Tests and lint

```bash
python -m pytest
python -m ruff check app tests migrations
```

## Environment

Copy `.env.example` to `.env` and set real values. Keep `SECRET_KEY`, `GEMINI_API_KEY`, `SMTP_PASSWORD`, and `FIREBASE_SERVICE_ACCOUNT_JSON` on the server only; the Android app must not contain them. Firebase public config values are exposed only through `GET /api/v1/config/public` or dart-defines. mirror writes to Firestore are enabled when `FIREBASE_SERVICE_ACCOUNT_JSON` is set.

## API overview

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/token`
- `POST /api/v1/auth/refresh`
- `GET /api/v1/expenses`
- `POST /api/v1/expenses`
- `PUT /api/v1/budgets`
- `GET /api/v1/budgets/daily-limit`
- `POST /api/v1/sync/batch`
- `GET /api/v1/sync/changes`
- `GET /api/v1/predictions/overspend`
- `GET /api/v1/analytics/spending`
- `GET /api/v1/gamification`
- `GET /api/v1/challenges/active`
- `GET /api/v1/notifications`
- `GET /api/v1/reports/monthly.pdf`
- `POST /api/v1/ocr/receipt`
- `GET /api/v1/config/public`

Use `Authorization: Bearer <access_token>` for protected routes.
