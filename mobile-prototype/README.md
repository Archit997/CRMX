# CRMX Mobile Prototype

This is a dependency-free mobile UI prototype for the CRMX workflow.

Run the FastAPI backend and open `/mobile/index.html` to test it with live POC APIs:

```bash
python3 -m uvicorn main:app --host 127.0.0.1 --port 8000
```

```text
http://127.0.0.1:8000/mobile/index.html
```

It is built as a mobile-first prototype, not a production Android/React Native app.

## Screens

- Sales executive day: call/WhatsApp sync, quick client update, follow-up queue.
- Client profile: client info, status path, transcript insight, audit trail.
- Manager analytics: missed follow-ups, quoted value, unlogged calls, team heatmap, WhatsApp digest.
- Finance follow-ups: receivables list and daily WhatsApp summary.

## Backend Mapping

The UI maps to the current repo tables:

- `status_master`: status path and category labels.
- `client_info`: client profile, owner, priority, phone, requirement, current status.
- `client_updates`: call/WhatsApp/document/follow-up updates, status changes, notes, follow-up date/time.

## Product Gaps In Current Repo

- No client CRUD APIs yet.
- No status master API yet.
- No client update API yet.
- No WhatsApp webhook ingestion yet.
- No call recording/transcript ingestion pipeline yet.
- No auth, role, or employee/team model yet.
- No mobile/frontend app yet.

## Recommended Next Build Step

Convert this prototype into a React Native or Expo app after the backend exposes:

- `GET /statuses`
- `GET /clients`
- `POST /clients`
- `GET /clients/{client_id}`
- `POST /clients/{client_id}/updates`
- `GET /followups/today`
- `GET /analytics/manager`
- `GET /finance/receivables`

See `docs/poc-endpoints-and-mobile-testing.md` for local mobile testing steps and endpoint details.
