# Authentication and Organization Workflow

## Sign in

1. Flutter sends an E.164 phone number to `POST /api/auth/send-otp`.
2. The backend asks Supabase Auth to send the OTP through Twilio Verify.
3. Flutter submits the code to `POST /api/auth/verify-otp`.
4. Supabase verifies the OTP and returns a signed access token and rotating
   refresh token.
5. The backend reads the Supabase user ID and phone from that verified identity.
   It never accepts either value from signup or organization request JSON.

Fixed OTPs belong only in Supabase's **Test Phone Numbers and OTPs** setting.
They must expire before a production release.

## First Company Admin

After the first OTP verification, a user without a CRMX profile can select
**Set up company**. Flutter sends:

```http
POST /api/organizations/bootstrap
Authorization: Bearer <supabase-access-token>
```

The backend atomically creates:

- the organization;
- its first approved `ADMIN` profile;
- a long, random company join code;
- an audit event.

The admin can see the code in the admin workspace and rotate it with
`POST /api/organizations/join-code/rotate`.

## Employee Signup

An employee verifies their phone, selects **Join company**, and submits their
name, requested role, contact note, and company code:

```http
POST /api/auth/signup-request
Authorization: Bearer <supabase-access-token>
```

The profile is created as `pending` and inactive inside the matching
organization. An admin reviews it using:

```http
GET /users/pending
PATCH /users/{user_id}/verification
```

Only an approved, active profile in an active organization can use protected
CRM endpoints. Rejected and archived profiles cannot silently sign up again.

## Session Handling

- Native Flutter builds store access and refresh tokens through
  `flutter_secure_storage`.
- On an API `401`, one shared refresh operation rotates the session and retries
  concurrent requests once.
- A refresh also rechecks the application profile, approval, active state, and
  organization state.
- Signing out clears both in-memory and secure token storage.

## Supabase Configuration

Required:

- Phone provider enabled.
- Twilio Verify configured for SMS.
- Test phone/OTP pairs removed or expired for production.
- Backend receives `SUPABASE_URL` and the service-role key.
- Flutter receives only `SUPABASE_URL` and the publishable/anon key.

The backend validates every access token against Supabase JWKS and verifies its
signature algorithm, issuer, audience, and expiry. There is no mode that trusts
a client-supplied user ID.

## Database

Run the ordered, checksummed migrations:

```bash
.venv/bin/python scripts/apply_migrations.py --dry-run
.venv/bin/python scripts/apply_migrations.py
```

`public.users.id` matches `auth.users.id`. Application tables have RLS enabled
without anon/authenticated PostgREST policies; Flutter uses Supabase directly
only for Auth, while business data goes through FastAPI.

See [organization admin setup](organization-admin-setup.md) and
[production readiness](production-readiness.md) for rollout controls.
