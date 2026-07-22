# CRMX Flutter Mobile UI

Separate Flutter UI package for the CRMX mobile application.

This package is intentionally separate from:

- FastAPI backend at the repo root
- Static HTML prototype in `mobile-prototype/`

## Current Status

Simple client list view with search functionality - no authentication required.

Run locally:

```bash
cd ui_flutter/crmx_mobile
flutter pub get
flutter run -d chrome --dart-define=CRMX_API_BASE=http://127.0.0.1:8000/api
```

## Features

### Landing Page (Client List)

- Displays all clients in a scrollable list
- Each client card shows:
  - Client Name
  - Company Name
  - Phone Number
  - Current Status
  - Priority badge
- Real-time search by name, company, phone, or status
- Pull to refresh
- Mock data fallback when API is unavailable

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

Current implementation:
- **Client List (Landing Page)**: Scrollable list of all clients with search functionality

Removed (for simplicity):
- Authentication flow
- Sales executive day screen
- Manager analytics screen
- Finance screen
- Call intelligence screen

## Architecture

```text
lib/
  main.dart                    # App entry point
  src/
    app.dart                   # Main app widget (no auth)
    data/
      crmx_repository.dart     # API calls & data fetching (legacy)
    models/
      crmx_models.dart         # Data models (ClientInfo, etc.)
    theme/
      app_theme.dart           # Material theme & colors
    ui/
      client_list_screen.dart  # Main landing page (client list + search)
  features/
    auth/                      # Authentication feature module
    clients/                   # Client management feature module
  core/
    cache/                     # Caching system (see CACHING_DOCUMENTATION.md)
```

## Design Direction

- Keep screens operational, not decorative.
- Make every card answer one question.
- Use status and priority as visual anchors.
- Keep forms short and quick for field staff.
- Keep manager/finance screens summary-first.
- Add new workflows as tabs/modules, not as clutter inside existing screens.
