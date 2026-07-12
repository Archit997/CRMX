# Auth Workflow

## Current Flow

1. User enters mobile number in E.164 format, for example `+919876543210`.
2. Flutter calls Supabase phone OTP auth.
3. Twilio sends the OTP through Supabase Auth. For configured test numbers, use fixed OTP `123456`.
4. After OTP verification, Flutter checks backend profile:
   - `GET /auth/profile/{supabase_user_id}`
5. If no CRMX profile exists, Flutter opens signup.
6. Signup creates a pending user profile:
   - `POST /auth/signup-request`
7. A manager/admin approves or rejects pending users:
   - `GET /users/pending`
   - `PATCH /users/{user_id}/verification`
8. Only approved and active users enter the client management app.

## Supabase Requirements

In Supabase Auth:

- Enable phone auth.
- Configure Twilio SMS provider.
- Add test phone numbers if using fixed OTP `123456`.
- Ensure the app uses the correct `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

Flutter env file:

```bash
cd ui_flutter/crmx_mobile
cp .env.sample .env
```

Required values:

```text
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
BACKEND_API_BASE=http://127.0.0.1:8000
APP_ENV=development
```

Backend env file:

```text
SUPABASE_DB_HOST=db.<project-ref>.supabase.co
SUPABASE_DB_PASSWORD=...
SUPABASE_JWT_SECRET=...
```

`SUPABASE_JWT_SECRET` is optional for local development but should be set outside development so backend auth/profile endpoints can verify that the Supabase bearer token subject matches the requested user ID.

## Database Migration

Run migrations in order:

1. `db/postgres/001_init_crmx_tables.sql`
2. `db/postgres/002_add_users_table.sql`

The users table is intentionally linked to Supabase Auth:

```sql
id uuid primary key references auth.users(id) on delete cascade
```

This means `public.users.id` must be the same ID as `auth.users.id`.

## User Table Fields

`public.users` includes:

- `id`
- `name`
- `role`
- `phone`
- `contact`
- `approval_status`
- `is_active`
- `verified_by`
- `verified_at`
- `rejection_reason`
- `created_at`
- `updated_at`

Allowed roles:

- `sales`
- `manager`
- `finance`
- `admin`

Allowed approval statuses:

- `pending`
- `approved`
- `rejected`

## Backend Endpoints

```http
GET /auth/profile/{user_id}
POST /auth/signup-request
GET /users/pending
PATCH /users/{user_id}/verification
GET /users
GET /users/{user_id}
POST /users
PATCH /users/{user_id}
DELETE /users/{user_id}
```

## Security Note

The backend verifies `/auth/profile` and `/auth/signup-request` bearer tokens when `SUPABASE_JWT_SECRET` is configured. Without that variable, these endpoints run in local-development mode and trust the supplied Supabase user ID.
