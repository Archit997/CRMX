# CRMX

CRMX is a multi-tenant CRM for phone- and WhatsApp-led sales teams. The
repository contains a FastAPI/Postgres backend and a separate Flutter mobile
application.

## Repository layout

```text
CRMX/
|-- db/postgres/                 SQLAlchemy models and ordered migrations
|-- services/                    Auth, organizations, users, clients, audit
|-- tests/                       Backend security and service tests
|-- ui_flutter/crmx_mobile/      Flutter application
|-- docs/                        Setup and production runbooks
|-- main.py                      FastAPI entry point
`-- .env.sample                  Backend configuration template
```

## Local setup

Backend:

```bash
cp .env.sample .env
python3 -m venv .venv
./.venv/bin/pip install -r requirements.txt
./.venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8000
```

Flutter:

```bash
cd ui_flutter/crmx_mobile
cp .env.sample .env
flutter pub get
flutter run -d chrome --web-port 3000
```

Local URLs:

- Flutter: `http://127.0.0.1:3000`
- API: `http://127.0.0.1:8000`
- OpenAPI docs in development: `http://127.0.0.1:8000/docs`
- Liveness: `http://127.0.0.1:8000/health`
- Database readiness: `http://127.0.0.1:8000/ready`

For Android Emulator use `http://10.0.2.2:8000` as `BACKEND_API_BASE`.
For a physical phone, bind the backend to the Mac LAN interface and use the
Mac's LAN IP.

## Database

Apply migrations in numeric order. The organization/admin feature requires:

```text
db/postgres/004_add_organizations.sql
```

It creates organization ownership, soft-deletion fields, audit events, indexes,
and RLS protection. See [organization setup](docs/organization-admin-setup.md)
for the user flow.

The current Supabase project predates the migration ledger. Follow the baseline
instructions in [production readiness](docs/production-readiness.md) before
applying migration 004.

## Authentication flow

1. Supabase Phone Auth verifies OTP.
2. A new company owner selects **Set up company** and becomes its first admin.
3. Employees select **Join company** with the admin's rotatable company code.
4. Admins approve or reject pending requests.
5. Every protected backend query is scoped to the authenticated organization.

The Flutter app receives only the Supabase publishable key. Database passwords
and the Supabase service-role key are backend-only.

## Tests

```bash
./.venv/bin/python -m pytest -q
cd ui_flutter/crmx_mobile
flutter test
flutter analyze --no-fatal-infos
```

## Production

Read [production readiness](docs/production-readiness.md) before using real
company data. It covers migrations, secret rotation, pooler configuration,
backups, monitoring, rate limits, mobile release controls, and recording
compliance.
