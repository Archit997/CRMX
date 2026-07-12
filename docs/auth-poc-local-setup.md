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

# Keep false for this POC unless backend JWKS verification is implemented.
SUPABASE_VERIFY_JWT=false
SUPABASE_JWT_SECRET=<optional_legacy_hs256_secret>
```

Do not commit `.env`. It is gitignored.

## 2. Flutter environment

Create `/Users/omshrivastava/Documents/New project 4/CRMX/ui_flutter/crmx_mobile/.env` from `ui_flutter/crmx_mobile/.env.example`.

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

Run migrations:

```bash
env PYTHONPATH=. .venv/bin/python scripts/run_sql_file.py db/postgres/001_init_crmx_tables.sql
env PYTHONPATH=. .venv/bin/python scripts/run_sql_file.py db/postgres/002_add_users_table.sql
```

Verify schema:

```bash
env PYTHONPATH=. .venv/bin/python scripts/check_supabase_schema.py
```

Expected tables:

```text
client_info, client_updates, status_master, users
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
flutter run -d chrome --web-port 5180
```

## 6. First manager bootstrap

The first manager cannot approve themself from the app because no manager exists yet. After first signup, approve the first manager manually:

```sql
update public.users
set
  role = 'manager',
  approval_status = 'approved',
  is_active = true,
  verified_at = now(),
  updated_at = now()
where phone = '<phone_used_in_signup>';
```

Then click `Check again` in the app.

After this, approved managers can use the app's pending users screen to approve other users.

## 7. Current auth flow

1. User enters phone.
2. Supabase sends/verifies OTP.
3. Flutter asks backend for `/auth/profile/{user_id}`.
4. If no CRMX profile exists, Flutter shows signup form.
5. Signup creates `public.users` row with `approval_status='pending'`.
6. Manager approves user.
7. Approved active users land on the CRM client dashboard.

## 8. Verification commands

```bash
env PYTHONPATH=. .venv/bin/python -m compileall db services/user utils main.py
curl -sS http://127.0.0.1:8000/postgres/health
cd ui_flutter/crmx_mobile
flutter test
flutter analyze --no-fatal-infos
```
