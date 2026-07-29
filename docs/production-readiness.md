# Production Readiness

CRMX has production-oriented application controls, but a release is production
only after the infrastructure and operational checks below are complete.

## Implemented application controls

- Supabase JWT signature, issuer, audience, expiry, and algorithm validation.
- Cached JWKS rotation support without blocking the async event loop.
- User identity and phone derived from the verified JWT, never request JSON.
- Organization-scoped user and client access.
- Long, rotatable company join codes.
- Soft deletion for users and clients.
- Append-only administrative audit events with request IDs.
- RLS enabled with no anon/authenticated application-table policies.
- Secure mobile token persistence and refresh-token rotation.
- Explicit CORS and optional trusted-host allowlists.
- Production startup configuration validation.
- Liveness (`/health`) and database readiness (`/ready`) endpoints.
- Structured JSON logging support without request bodies, OTPs, or tokens.

## Required before first production release

1. Rotate every credential previously shared in chat or screenshots.
2. Store backend secrets in the deployment platform secret manager.
3. Run database migrations from CI/CD using a dedicated migration job.
4. Use the Supabase transaction pooler URL from hosted backend instances.
5. Enable Supabase backups and point-in-time recovery appropriate to the plan.
6. Configure Supabase Auth and Twilio Verify production rate limits.
7. Put the API behind HTTPS and an edge rate limiter/WAF.
8. Send JSON logs and application errors to a monitored log/error platform.
9. Add alerting for `/ready`, elevated 401/429/5xx rates, and failed migrations.
10. Run Android/iOS integration tests on real devices before store release.

## Database rollout

Apply pending migrations with checksum verification and a Postgres advisory
lock:

```bash
.venv/bin/python scripts/apply_migrations.py --dry-run
.venv/bin/python scripts/apply_migrations.py
```

For the existing CRMX Supabase project, migrations 001-003 were applied
manually before the migration ledger existed. Verify those tables first, then
record that baseline exactly once:

```bash
.venv/bin/python scripts/check_supabase_schema.py
.venv/bin/python scripts/apply_migrations.py \
  --baseline-through 003_update_user_roles_enum.sql
.venv/bin/python scripts/apply_migrations.py --dry-run
```

The dry run should then list only `004_add_organizations.sql`. Review the
legacy-row and duplicate-phone queries below before applying it.

Before enforcing non-null organization IDs, review any legacy rows:

```sql
select id, phone from public.users where organization_id is null;
select client_id, phone from public.client_info where organization_id is null;
select organization_id, phone, count(*)
from public.client_info
where deleted_at is null
group by organization_id, phone
having count(*) > 1;
```

Do not assign these rows automatically. Produce a reviewed mapping for each
company, migrate it, verify counts, and only then enforce non-null constraints
in a later migration.

## Hosted backend

Recommended process command:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 2
```

Set:

```env
ENVIRONMENT=production
LOG_FORMAT=json
LOG_TO_FILE=false
ALLOWED_ORIGINS=https://app.example.com
ALLOWED_HOSTS=api.example.com
```

Use the deployment platform's port variable where required. API documentation
is disabled automatically in production.

## Mobile release

- Android and iOS tokens use platform secure storage.
- Web storage is suitable for local testing, not the preferred production
  surface for privileged admin sessions.
- Configure Android signing, iOS provisioning, crash reporting, and release
  environment files outside source control.
- Test offline, expired-session, revoked-user, slow-network, and app-restart
  behavior on physical devices.

## Calls, recordings, and WhatsApp

Call recording and message auditing require a separate legal and technical
review before release. Confirm consent rules, employee notice, retention,
encryption, deletion requests, access logging, WhatsApp Business terms, Play
Store policy, and iOS platform limitations for every operating jurisdiction.
Raw recordings and transcripts must use private object storage with short-lived
signed URLs; they must not be stored directly in CRM database rows.
