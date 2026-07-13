# CRMX

A modern CRM system with FastAPI backend and Flutter frontend for managing client relationships, status tracking, and follow-ups.

## Prerequisites

- Python 3.8+
- Flutter 3.0+
- PostgreSQL (via Supabase)

## Project Structure

```
CRMX/
├── main.py                 # FastAPI application entry point
├── requirements.txt        # Python dependencies
├── .env                    # Environment variables (not in git)
├── .env.sample            # Environment variables template
├── db/                    # Database models and connections
├── services/              # Business logic and API controllers
├── utils/                 # Utility functions
└── ui_flutter/            # Flutter mobile/web application
    └── crmx_mobile/       # Flutter app source
```

## Backend Setup

### 1. Create Virtual Environment

```bash
# Navigate to project root
cd /Users/architaggarwal/Documents/CRMX

# Create virtual environment
python -m venv venv

# Activate virtual environment
# On macOS/Linux:
source venv/bin/activate

# On Windows:
# venv\Scripts\activate
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Configure Environment Variables

Copy `.env.sample` to `.env` and fill in your credentials:

```bash
cp .env.sample .env
```

Edit `.env` with your actual values:
- MongoDB credentials (if using MongoDB features)
- WhatsApp API credentials (if using WhatsApp features)
- Supabase Postgres credentials

### 4. Start Backend Server

```bash
python main.py
```

The backend API will start on `http://127.0.0.1:8000`

You can access:
- **API Documentation**: http://127.0.0.1:8000/docs
- **Alternative Docs**: http://127.0.0.1:8000/redoc

## Frontend Setup (Flutter)

### 1. Navigate to Flutter Project

```bash
cd ui_flutter/crmx_mobile
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Run Flutter App

**For Web (Chrome)**:
```bash
flutter run -d chrome --dart-define=CRMX_API_BASE=http://127.0.0.1:8000
```

**For Android Emulator**:
```bash
flutter run -d android --dart-define=CRMX_API_BASE=http://127.0.0.1:8000
```

**For iOS Simulator** (macOS only):
```bash
flutter run -d ios --dart-define=CRMX_API_BASE=http://127.0.0.1:8000
```

**Note**: Make sure to use `http://127.0.0.1:8000` (without `/api` suffix) as the API base URL.

## Quick Start (Both Backend & Frontend)

Open two terminal windows:

**Terminal 1 - Backend**:
```bash
cd /Users/architaggarwal/Documents/CRMX
source venv/bin/activate
python main.py
```

**Terminal 2 - Frontend**:
```bash
cd /Users/architaggarwal/Documents/CRMX/ui_flutter/crmx_mobile
flutter run -d chrome --dart-define=CRMX_API_BASE=http://127.0.0.1:8000
```

## Features

### Current Features
- ✅ **Client Management**: Create, view, edit, and search clients
- ✅ **Status Tracking**: Track client status through customizable stages
- ✅ **Priority Management**: Categorize clients as Hot, Warm, or Cold
- ✅ **Search & Filter**: Real-time client search by name, company, phone, or status
- ✅ **Client Details**: View and edit comprehensive client information
- ✅ **Responsive UI**: Works on web, iOS, and Android

### API Endpoints

Main endpoints available:
- `GET /client-list` - List all clients
- `GET /client/{search_term}` - Search clients
- `POST /client` - Create new client
- `PATCH /client-list` - Update client details
- `POST /change-client-status` - Change client status
- `GET /master-status` - Get all available statuses

Full API documentation: http://127.0.0.1:8000/docs

## Development

### Backend Development

The backend uses:
- **FastAPI** for the REST API
- **SQLAlchemy** for database ORM
- **Pydantic** for data validation
- **Uvicorn** as the ASGI server

Hot reload is enabled by default when running `python main.py`.

### Frontend Development

The Flutter app features:
- **Material Design 3** UI components
- **Responsive layout** for all screen sizes
- **State management** using StatefulWidget
- **API integration** with fallback to mock data
- **Form validation** for data integrity

## Environment Variables

Required environment variables in `.env`:

```bash
# Postgres - Supabase
SUPABASE_DB_HOST=your-db-host.supabase.co
SUPABASE_DB_PORT=5432
SUPABASE_DB_NAME=postgres
SUPABASE_DB_USER=postgres
SUPABASE_DB_PASSWORD=your-password
SUPABASE_SSL_MODE=require

# MongoDB (optional)
MONGO_URI=your-mongo-connection-string

# WhatsApp Business API (optional)
WA_ACCESS_TOKEN=your-whatsapp-token
WA_PHONE_ID=your-phone-id
WA_BUSINESS_ACC_ID=your-business-account-id
WA_SENDER_ID=your-sender-id
```

## Testing

### Backend Testing

```bash
# Run backend
python main.py

# Test API endpoints
curl http://127.0.0.1:8000/client-list
curl http://127.0.0.1:8000/master-status
```

### Frontend Testing

The Flutter app includes visual indicators:
- 🟢 **Green "API" badge**: Connected to backend successfully
- 🟡 **Yellow "Mock" badge**: Using mock data (backend unreachable)

## Troubleshooting

### Backend Issues

**Problem**: `ModuleNotFoundError`
```bash
# Solution: Make sure virtual environment is activated and dependencies installed
source venv/bin/activate
pip install -r requirements.txt
```

**Problem**: Database connection fails
```bash
# Solution: Check .env file has correct Supabase credentials
# Verify SUPABASE_DB_HOST, SUPABASE_DB_PASSWORD, etc.
```

### Frontend Issues

**Problem**: "Using mock data" warning
```bash
# Solution: Ensure backend is running on http://127.0.0.1:8000
# Check API_BASE URL doesn't have /api suffix
flutter run -d chrome --dart-define=CRMX_API_BASE=http://127.0.0.1:8000
```

**Problem**: CORS errors in browser console
```bash
# Solution: Backend CORS is configured for localhost
# Make sure you're accessing from http://127.0.0.1 or http://localhost
```

## Documentation

Additional documentation available:
- `CREATE_CLIENT_FEATURE.md` - Client creation functionality
- `CLIENT_EDIT_FEATURE.md` - Client editing functionality
- `TEST_EDIT_FEATURE.md` - Testing guide for edit feature
- `docs/poc-endpoints-and-mobile-testing.md` - API endpoints reference

## Contributing

1. Create a feature branch
2. Make your changes
3. Test both backend and frontend
4. Submit a pull request

## License

[Your License Here]

## Support

For issues and questions, please contact the development team.
