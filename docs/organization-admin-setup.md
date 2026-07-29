# Organization and Admin Setup

## What changed

CRMX now separates each company's users and clients with an
`organization_id`. A first-time user can either:

- create a company workspace and become its approved admin; or
- enter a company code and send an employee/manager request to that company's
  admin.

Admins can view pending requests, approve or reject them, change approved
employees between Employee and Manager, deactivate or reactivate access, and
archive inactive users who do not own client records. Administrative changes
are written to an append-only audit trail.

## Supabase database change

Open **Supabase > SQL Editor**, paste
`db/postgres/004_add_organizations.sql`, and run it once. The script is
idempotent and:

1. creates `public.organizations`;
2. adds `organization_id` to `public.users` and `public.client_info`;
3. adds soft-deletion fields for users and clients;
4. creates append-only `public.audit_events`;
5. enables RLS without public application-table policies;
6. adds indexes needed by signup, admin lists, and client queries.

Do not create these columns manually in Table Editor. Keep the migration in
source control as the database change record.

## First admin flow

1. Sign in with the admin mobile number and OTP.
2. On **Set up your company**, enter the admin name and company name.
3. CRMX creates a unique company code and opens the client workspace.
4. Open the shield icon in the app bar to see **Admin**.
5. Share the company code shown there with employees.
6. Rotate the code from Admin when it has been shared too widely.

The setup flow never claims unassigned rows automatically. Existing data must
be assigned to an organization through a reviewed migration.

## Employee flow

1. Sign in with the employee mobile number and OTP.
2. Select **Join company** and enter the company code.
3. Enter name and requested role.
4. The employee sees **Waiting for admin approval**.
5. The admin approves the request from **Admin > Requests**.
6. The employee taps **Check again** or signs in again.

## Local run

Backend:

```bash
cd "/Users/omshrivastava/Documents/New project 4/CRMX"
python3 -m uvicorn main:app --host 127.0.0.1 --port 8000
```

Flutter web:

```bash
cd "/Users/omshrivastava/Documents/New project 4/CRMX/ui_flutter/crmx_mobile"
flutter run -d chrome --web-port 3000
```

Use `http://10.0.2.2:8000` as `BACKEND_API_BASE` for an Android emulator and
the Mac's LAN IP for a physical phone.

## Logging

Every backend response includes `X-Request-ID`. Flutter sends the same header,
so a failed mobile request can be matched to the backend log line. Backend
logging code lives in `utils/logging/`. Logs go to stdout and, when
`LOG_TO_FILE=true`, to `LOG_DIR/app.log` with rotation (`logs/app.log` by
default). Credentials, OTPs, database passwords, tokens, and phone numbers are
automatically redacted. Request and response bodies are never logged.

Use `LOG_FORMAT=json` and `LOG_TO_FILE=false` in hosted environments, then ship
stdout to the platform log collector.

## Production rollout

See `docs/production-readiness.md` before enabling real company data.
