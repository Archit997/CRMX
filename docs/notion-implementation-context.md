# Notion Implementation Context

Extracted from the public Notion links on 2026-06-20 using browser-rendered Notion pages. Sensitive credential values were intentionally not copied here.

## Product Direction

CRMX is a telephone and WhatsApp audit workflow for traditional firms where sales, raw-material purchase, customer acquisition, and finance teams work through direct calls and WhatsApp.

The product must:

- Track company SIM and WhatsApp conversations.
- Convert recordings into transcripts for later analysis.
- Generate action items such as quotation follow-up, order confirmation, payment follow-up, escalation, and manager summaries.
- Keep migration friction low for traditional manufacturing and trading businesses.
- Support teams that already use post-paid company SIM cards and WhatsApp for client communication.

## Primary User Workflows

### Sales Executive Day

The sales executive flow should be built around daily execution:

- Show the list of clients to contact today from follow-up data.
- For each client, show context before the call: requirement, current status, past conversation, promised document, and next expected action.
- Let the executive document call or WhatsApp outcomes quickly.
- Infer action items from the outcome later through transcription/LLM processing.
- Add urgent actions to the same-day task list.
- Escalate important items to a manager WhatsApp group when required.

### Manager Analytics

The manager flow should be summary-first:

- Daily list of sales employees.
- Number of follow-ups scheduled for each employee.
- Zoom-in/zoom-out from employee summary to details.
- List of critical clients.
- Action items for each critical client.
- Assigned sales executive for each critical item.

### Finance Flow

Finance should get receivable-focused worklists:

- Daily message listing clients to contact for receivables.
- Call-derived follow-up date and next action.
- Received amount and pending receivable tracking.
- Consolidated message to company head.

## Backend Tasks

Immediate backend tasks from Notion:

- DB seeding API.
- Authentication and authorization.
- CRUD APIs.
- CRON health APIs.
- UI integration.
- WhatsApp API integration.
- Backend logging.
- Deployment path.

## Required API Surface

Notion API design listed these routes:

- `GET /client-list` to get all clients.
- `GET /client/{name/companyname/contact}` to search by customer name, company name, or contact.
- `PATCH /client-list` to patch client data.
- `POST /client` to create a new client.
- `DELETE /client` to delete client information.
- `POST /master-status` to create a new status type.

Recommended normalized POC/API shape:

- `GET /api/clients`
- `GET /api/clients/search?q=...`
- `GET /api/clients/{client_id}`
- `POST /api/clients`
- `PATCH /api/clients/{client_id}`
- `DELETE /api/clients/{client_id}`
- `GET /api/statuses`
- `POST /api/statuses`
- `GET /api/followups/today`
- `POST /api/clients/{client_id}/updates`
- `GET /api/analytics/manager`
- `GET /api/finance/receivables`
- `GET /api/health/cron`

## UI Features

Required UI features:

- Add new customer or lead page.
- View all customers.
- Search customer by name, company name, or phone number.
- Edit customer details.
- Change customer status.
- Auto-sync customer state after status change.

Design implication:

- Forms must be short, guided, and mobile-first.
- Status change should feel like one action, not a full data-entry workflow.
- Search must support phone number because this is likely the fastest lookup for sales and finance teams.
- Screens should use familiar operational language: Call, WhatsApp, Quotation, Payment, Follow-up, Order.

## DB Schema From Notion

### Client Info

Fields:

- `client_id`
- `client_name`
- `company_name`
- `phone`
- `whatsapp_number`
- `email`
- `city`
- `assigned_to`
- `current_status_no`
- `requirement_summary`
- `priority`
- `created_date`
- `last_updated`

### Client Updates

Fields:

- `update_id`
- `client_id`
- `update_type`
- `old_status_no`
- `new_status_no`
- `request_type`
- `request_subtype`
- `note`
- `followup_date`
- `followup_time`
- `created_by`
- `created_at`

### Status Master

Fields:

- `status_no`
- `status_name`
- `category`
- `description`
- `is_active`

Statuses:

1. New Lead
2. Contacted
3. Asked for Information
4. Information Sent
5. Asked for Document
6. Document Sent
7. Follow-up Required
8. Negotiation Phase
9. Payment Pending
10. Order Confirmed
11. Delivered / Completed
12. After-Sales Follow-up
13. On Hold
14. Lost

Categories:

- `Lead`: early-stage enquiry or pre-sale.
- `Client`: serious client, order, payment, or delivery stage.
- `Critical`: stuck, inactive, or lost case.

## Environment And Credentials

The Notion pages include Meta WhatsApp test credentials and a Supabase password. Raw values were not copied into this file.

Required configuration keys should be moved into `.env` or a secrets manager:

- `META_ACCESS_TOKEN`
- `WHATSAPP_BUSINESS_ACCOUNT_ID`
- `WHATSAPP_PHONE_NUMBER_ID`
- `WHATSAPP_TEST_NUMBER`
- `SUPABASE_URL`
- `SUPABASE_PASSWORD`
- `SUPABASE_SERVICE_ROLE_KEY` if required later

Security note:

- The visible Meta token and Supabase password should be rotated because they were present on public Notion pages.

## Implementation Priorities

1. Add auth page and role-aware navigation.
2. Complete client CRUD endpoints.
3. Complete status CRUD or admin-only status management.
4. Add client search endpoint and mobile search UI.
5. Add quick update form for sales reps.
6. Add today follow-up queue.
7. Add manager analytics summary.
8. Add finance receivables queue.
9. Add call recording/transcription pipeline as separate module.
10. Add WhatsApp bot integration for daily tasks and status lookup.

## Screenshots

Non-sensitive screenshots are stored in:

- `docs/notion-screenshots/telephone_whatsapp_audit.png`
- `docs/notion-screenshots/tasks.png`
- `docs/notion-screenshots/sales_executive_day.png`
- `docs/notion-screenshots/manager_analytics.png`
- `docs/notion-screenshots/api_design.png`
- `docs/notion-screenshots/ui_features.png`
- `docs/notion-screenshots/technical_planning.png`
- `docs/notion-screenshots/db_schema.png`
- `docs/notion-screenshots/todos.png`
- `docs/notion-screenshots/ideation.png`

Sensitive screenshots for environment variables and credentials are intentionally not copied into the repo.
