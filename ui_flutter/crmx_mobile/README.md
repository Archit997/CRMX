# CRMX Flutter Mobile UI

Separate Flutter UI package for the CRMX mobile application.

This package is intentionally separate from:

- FastAPI backend at the repo root
- Static HTML prototype in `mobile-prototype/`

## Current Status

Flutter is installed locally and this package has been generated for Android, iOS, and Web.

Run locally:

```bash
cd ui_flutter/crmx_mobile
flutter pub get
flutter run -d chrome --dart-define=CRMX_API_BASE=http://127.0.0.1:8000/api
```

## API Configuration

The app reads API base URL from `CRMX_API_BASE`.

Laptop browser / desktop:

```bash
flutter run --dart-define=CRMX_API_BASE=http://127.0.0.1:8000/api
```

Android emulator:

```bash
flutter run --dart-define=CRMX_API_BASE=http://10.0.2.2:8000/api
```

Real phone on same Wi-Fi:

```bash
flutter run --dart-define=CRMX_API_BASE=http://<laptop-ip>:8000/api
```

If the API is unreachable, the UI falls back to mock data so design work can continue.

## Screens

- Sales: company SIM count, WhatsApp count, update form, follow-up queue.
- Client: profile, status path, audit timeline.
- Audit: call recording to transcription to translation to insight pipeline.
- Manager: missed follow-ups, quoted value, unlogged calls, digest preview.
- Finance: receivable follow-ups and WhatsApp summary.

## Architecture

```text
lib/
  main.dart
  src/
    app.dart
    data/
      crmx_repository.dart
      mock_data.dart
    models/
      crmx_models.dart
    theme/
      app_theme.dart
    ui/
      home_shell.dart
      widgets.dart
```

## Design Direction

- Keep screens operational, not decorative.
- Make every card answer one question.
- Use status and priority as visual anchors.
- Keep forms short and quick for field staff.
- Keep manager/finance screens summary-first.
- Add new workflows as tabs/modules, not as clutter inside existing screens.
