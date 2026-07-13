# CRMX First POC: Endpoints and Mobile Testing

## Local Run

From the repo root:

```bash
python3 -m uvicorn main:app --host 127.0.0.1 --port 8000
```

Open:

```text
http://127.0.0.1:8000/mobile/index.html
```

The POC does not require Postgres. It reads and writes JSON files from `data/`.

Flutter UI package:

```bash
cd ui_flutter/crmx_mobile
flutter run -d chrome --dart-define=CRMX_API_BASE=http://127.0.0.1:8000/api
```

Compiled Flutter web build can be served from:

```bash
cd ui_flutter/crmx_mobile/build/web
python3 -m http.server 8090 --bind 127.0.0.1
```

Open:

```text
http://127.0.0.1:8090
```

## Mobile Testing Options

### 1. Browser device mode

Use this first for layout and interaction checks.

1. Open `http://127.0.0.1:8000/mobile/index.html`.
2. Open Chrome DevTools.
3. Enable device toolbar.
4. Test common sizes:
   - Android compact: `360 x 800`
   - Android standard: `390 x 844`
   - Large phone: `430 x 932`

### 2. Real phone on same Wi-Fi

Run the backend on all interfaces:

```bash
python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
```

Find your laptop IP, then open this on the phone:

```text
http://<your-laptop-ip>:8000/mobile/index.html
```

This is useful for checking touch targets, scrolling, and visual density with real device behavior.

### 3. Android emulator

If this later becomes a native Android app, the emulator reaches your laptop localhost through:

```text
http://10.0.2.2:8000
```

For a React Native / Expo app, set the API base URL to:

```text
http://10.0.2.2:8000/api
```

## POC Data Files

- `data/status_master.json`: 14 CRM statuses.
- `data/client_info.json`: dummy clients based on the client info schema.
- `data/client_updates.json`: call, WhatsApp, document, and follow-up audit events.
- `data/users.json`: dummy auth users for sales, manager, and finance roles.
- `data/team_activity.json`: manager analytics dummy data.
- `data/finance_receivables.json`: finance follow-up dummy data.

## Current POC API

### Health

```http
GET /api/health
```

Purpose: confirm local JSON POC backend is running.

```http
GET /api/health/cron
```

Purpose: confirm scheduled-job contracts for daily follow-up, receivable digest, and call-audit ingestion.

### Auth

```http
POST /api/auth/login
```

Purpose: local POC login for role-aware UI entry.

Example body:

```json
{
  "identifier": "rohit@crmx.local",
  "password": "sales123"
}
```

Dummy users:

- Sales: `rohit@crmx.local / sales123`
- Manager: `priya@crmx.local / manager123`
- Finance: `finance@crmx.local / finance123`

### Status Master

```http
GET /api/statuses
```

Purpose: returns the 14 status rows used for dropdowns and status rail UI.

```http
POST /api/statuses
```

Purpose: create an additional status type for experimentation.

### Client List

```http
GET /api/clients
```

Purpose: returns all clients with computed `status_name` and `status_category`.

```http
GET /api/clients/search?q=aman
```

Purpose: search customers/leads by name, company, phone, WhatsApp, email, city, owner, or priority.

```http
POST /api/clients
```

Purpose: create a new customer/lead.

Example body:

```json
{
  "client_name": "Sanjay Verma",
  "company_name": "Verma Components",
  "phone": "9888812345",
  "whatsapp_number": "9888812345",
  "email": "sanjay@example.com",
  "city": "Indore",
  "assigned_to": "Rohit Sharma",
  "current_status_no": 1,
  "requirement_summary": "Needs pricing and delivery timeline for 300 units.",
  "priority": "Warm",
  "deal_value": 90000
}
```

### Client Detail

```http
GET /api/clients/{client_id}
```

Purpose: returns one client with its audit timeline updates.

```http
PATCH /api/clients/{client_id}
```

Purpose: update customer details, owner, requirement, priority, status, or value.

```http
DELETE /api/clients/{client_id}
```

Purpose: delete one POC client and its related update rows.

### Client Updates

```http
GET /api/clients/{client_id}/updates
```

Purpose: returns timeline rows for one client.

```http
POST /api/clients/{client_id}/updates
```

Purpose: creates a call, WhatsApp, document, or follow-up update. Also updates the client's current status.

Example body:

```json
{
  "update_type": "Follow-up",
  "new_status_no": 7,
  "request_type": "Document",
  "request_subtype": "Quotation",
  "note": "Send revised quotation and follow up tomorrow.",
  "followup_date": "2026-06-08",
  "followup_time": "12:00",
  "created_by": "Rohit"
}
```

### Follow-Up Queue

```http
GET /api/followups/today
```

Purpose: returns due and overdue follow-ups for the sales executive day screen.

### Manager Analytics

```http
GET /api/analytics/manager
```

Purpose: returns call count, WhatsApp count, overdue follow-ups, quoted value, unlogged calls, and team heatmap rows.

### Finance Receivables

```http
GET /api/finance/receivables
```

Purpose: returns amount due, receivable client list, and a ready-to-send WhatsApp daily summary.

## Next Backend Endpoints Needed After POC

These should move from JSON-backed POC data to Postgres tables:

- `GET /api/users`
- `GET /api/teams/{team_id}/activity`
- `POST /api/calls/ingest`
- `POST /api/whatsapp/webhook`
- `POST /api/transcripts/analyze`
- `POST /api/digests/manager/send`
- `POST /api/digests/finance/send`

## Implementation Notes

- The current POC intentionally uses JSON files so it can run without credentials.
- `POST /api/auth/login` is dummy local auth, not production-grade JWT/session auth.
- Client create/update/delete currently mutates `data/client_info.json`.
- `POST /api/clients/{client_id}/updates` mutates `data/client_updates.json` and `data/client_info.json`.
- For production, this write path should be moved to Postgres with server-side validation and authentication.
