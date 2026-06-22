# Mobile Feature Recommendations

## Product Principle

CRMX should not become a generic CRM. The core product should be:

```text
Every client-facing call or WhatsApp conversation becomes:
client status + audit trail + follow-up + manager/finance action.
```

That keeps the app focused and understandable for traditional firms.

## Recommended POC Scope

### 1. Sales Executive Day

Build first.

Purpose:

- Show today's follow-ups.
- Let employee update client status quickly.
- Capture what was discussed.
- Create next follow-up.

Implementation:

- `GET /api/followups/today`
- `GET /api/clients`
- `GET /api/statuses`
- `POST /api/clients/{client_id}/updates`

UI:

- Daily metrics at top.
- Client update form.
- Follow-up queue.
- Recent audit trail.

### 2. Client Workspace

Build second.

Purpose:

- One screen for all client information.
- Current status visible.
- Timeline of calls, WhatsApp updates, documents, and follow-ups.

Implementation:

- `GET /api/clients/{client_id}`
- `GET /api/clients/{client_id}/updates`

UI:

- Client profile card.
- Status rail.
- Requirement summary.
- Last 5 updates.
- Action buttons: call, WhatsApp, add update, set follow-up.

### 3. Manager Analytics

Build third.

Purpose:

- Show which employees are missing follow-ups.
- Show unlogged calls.
- Show negotiation/payment/order flow.
- Generate daily WhatsApp digest.

Implementation:

- `GET /api/analytics/manager`
- `POST /api/digests/manager/send`

UI:

- Missed follow-ups.
- Unlogged calls.
- Team heatmap.
- Ready-to-send digest preview.

### 4. Finance Receivables

Build fourth.

Purpose:

- Daily receivable call list.
- Track payment promises.
- Generate finance/company-head summary.

Implementation:

- `GET /api/finance/receivables`
- `POST /api/digests/finance/send`

UI:

- Due amount by client.
- Follow-up action.
- Last payment promise.
- WhatsApp summary.

## Call Recording, Transcription, Translation, Insight

This should be a separate feature module, not mixed into the basic CRM screens.

Recommended flow:

```text
Call event
-> recording metadata
-> audio upload
-> transcript
-> translation
-> structured insight
-> suggested CRM update
-> human confirmation
-> saved client update
```

### Suggested Tables

```text
call_events
- call_id
- employee_id
- phone
- client_id
- direction
- started_at
- ended_at
- duration_seconds
- recording_status
- transcript_status
- insight_status
- consent_status

call_recordings
- recording_id
- call_id
- storage_url
- mime_type
- size_bytes
- created_at

call_transcripts
- transcript_id
- call_id
- language_detected
- transcript_text
- translated_text
- confidence_score
- created_at

call_insights
- insight_id
- call_id
- suggested_status_no
- request_type
- request_subtype
- summary
- action_items
- followup_date
- followup_time
- risk_level
- requires_human_review
```

### Important Platform Constraint

Call recording is not just a UI feature. It depends on:

- Android version and OEM behavior.
- Consent and telecom/privacy law.
- Whether calls happen through native SIM, VoIP, or a telephony provider.
- Whether the business can mandate a company device or only a company SIM.

For a reliable business POC, the safest implementation path is:

1. Start with call metadata and manual notes.
2. Add employee-confirmed recording upload.
3. Add transcript and insight generation.
4. Only then evaluate automatic call recording.

### Recommended MVP for Call Intelligence

Do this first:

- Employee finishes call.
- App opens "Log call" screen.
- Employee selects client.
- Employee records a short voice note or uploads call audio if available.
- Backend transcribes it.
- Backend suggests:
  - status
  - request type
  - request subtype
  - follow-up date/time
  - summary
  - finance/manager alert
- Employee confirms before saving.

This reduces platform risk and still proves the business value.

## WhatsApp Integration Recommendation

Use WhatsApp Business Cloud API for official business messaging and webhooks.

Avoid building the first POC around scraping personal WhatsApp chats. That creates reliability and compliance risk.

Recommended flow:

```text
WhatsApp Business webhook
-> message event
-> client matching by phone
-> conversation timeline
-> request/status inference
-> suggested follow-up
```

If employees currently use personal/company-SIM WhatsApp directly, use the mobile app to let them manually log:

- message sent
- document sent
- client asked for price/quotation/receipt/delivery
- next follow-up

Then migrate high-volume teams to WhatsApp Business API later.

## Feature Backlog

### P0

- Client list and search.
- Add/update client.
- Status update.
- Follow-up queue.
- Client timeline.
- Manager digest.
- Finance receivable list.

### P1

- Call metadata sync.
- Manual call note.
- Voice note upload.
- Transcript generation.
- Translation.
- Insight suggestion.
- Human review before saving.

### P2

- WhatsApp Business webhook.
- Document tracking.
- Quotation/receipt attachment tracking.
- Team-level SLA rules.
- Missed follow-up escalation.

### P3

- Automatic call recording after legal/platform validation.
- Role-based access.
- Multi-branch analytics.
- Raw material acquisition workflow.
- Client risk scoring.

## Backend Endpoint Recommendations

```http
GET /api/clients
POST /api/clients
GET /api/clients/{client_id}
PATCH /api/clients/{client_id}
GET /api/clients/{client_id}/updates
POST /api/clients/{client_id}/updates

GET /api/followups/today
PATCH /api/followups/{followup_id}/complete
PATCH /api/followups/{followup_id}/reschedule

POST /api/calls/events
POST /api/calls/{call_id}/recording
POST /api/calls/{call_id}/transcribe
POST /api/calls/{call_id}/translate
POST /api/calls/{call_id}/insights
POST /api/calls/{call_id}/confirm-insight

POST /api/whatsapp/webhook
GET /api/whatsapp/conversations/{client_id}

GET /api/analytics/manager
GET /api/finance/receivables
POST /api/digests/manager/send
POST /api/digests/finance/send
```

## Design Recommendation

Keep the mobile app modular:

- Sales tab: daily work.
- Client tab: record and timeline.
- Audit tab: recording/transcription/insight pipeline.
- Manager tab: control tower.
- Finance tab: receivables.

Do not put everything on one dashboard. Field employees need speed; managers need summaries; finance needs action lists.

## Useful Official References

- Android permissions and call log access: `https://developer.android.com/reference/android/Manifest.permission#READ_CALL_LOG`
- Android media recording APIs: `https://developer.android.com/media/platform/mediarecorder`
- Apple CallKit framework: `https://developer.apple.com/documentation/callkit`
- WhatsApp Cloud API webhooks: `https://developers.facebook.com/docs/whatsapp/cloud-api/webhooks`
