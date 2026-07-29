# CRMX Auth POC Local Setup

This branch adds a Flutter mobile UI auth POC backed by Supabase Phone OTP and the local FastAPI backend.

## 1. Backend environment

Create `/Users/omshrivastava/Documents/New project 4/CRMX/.env` from `.env.sample`.

```env
ENVIRONMENT=development

MONGODB_URI=mongodb+srv://<username>:<password>@<cluster-url>/?retryWrites=true&w=majority
MONGODB_DB_NAME=crmx

SUPABASE_DB_HOST=db.<project-ref>.supabase.co
SUPABASE_DB_PORT=5432
SUPABASE_DB_NAME=postgres
SUPABASE_DB_USER=postgres
SUPABASE_DB_PASSWORD=<database_password>
SUPABASE_SSL_MODE=require

SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
SUPABASE_VERIFY_JWT=true
```

Do not commit `.env`. It is gitignored.

## 2. Flutter environment

Create `/Users/omshrivastava/Documents/New project 4/CRMX/ui_flutter/crmx_mobile/.env` from `ui_flutter/crmx_mobile/.env.sample`.

```env
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<supabase_anon_or_publishable_key>
BACKEND_API_BASE=http://127.0.0.1:8000
APP_ENV=development
```

For Android emulator testing, use:

```env
BACKEND_API_BASE=http://10.0.2.2:8000
```

For a physical phone, use the Mac's LAN IP:

```env
BACKEND_API_BASE=http://<mac_lan_ip>:8000
```

## 3. Supabase setup

In Supabase:

1. Go to `Authentication -> Providers -> Phone`.
2. Enable phone provider.
3. Choose `Twilio Verify` for real SMS.
4. Add Twilio Account SID, Auth Token, and Verify Service SID.
5. Add test phone numbers for local development.

Example test numbers:

```text
91XXXXXXXXXX=123456,91YYYYYYYYYY=123456
```

Use the exact same normalized phone number in the app. The Flutter app accepts a normal Indian 10-digit number and converts it to `+91...`.

## 4. Database migrations

Install backend dependencies:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

Run pending migrations:

```bash
env PYTHONPATH=. .venv/bin/python scripts/apply_migrations.py
```

Verify schema:

```bash
env PYTHONPATH=. .venv/bin/python scripts/check_supabase_schema.py
```

Expected tables:

```text
client_info, client_updates, organizations, status_master, users
```

## 5. Run locally

Backend:

```bash
env PYTHONPATH=. .venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8000
```

Flutter:

```bash
cd ui_flutter/crmx_mobile
flutter pub get
flutter run -d chrome --web-port 3000
```

## 6. First organization bootstrap

After OTP verification, select `Set up company`, enter the organization name,
and submit. The backend creates the organization and approves that user as its
initial admin. No manual SQL approval is required.

The admin workspace displays a company code. Employees use that code under
`Join company`; their requests remain pending until an admin approves them.

## 7. Current auth flow

1. User enters phone.
2. Supabase sends/verifies OTP.
3. Flutter asks the backend for `/api/auth/user/status`.
4. If no CRMX profile exists, Flutter shows signup form.
5. The first admin creates an organization, or an employee joins with its code.
6. Organization admins approve or reject team requests.
7. Approved active users land on the CRM client dashboard.

## 8. Verification commands

```bash
env PYTHONPATH=. .venv/bin/python -m compileall db services/user utils main.py
curl -sS http://127.0.0.1:8000/postgres/health
cd ui_flutter/crmx_mobile
flutter test
flutter analyze --no-fatal-infos
```
