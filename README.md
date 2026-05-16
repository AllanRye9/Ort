# Ort — Unified Commerce Marketplace Platform

A comprehensive **SaaS marketplace** for **Properties**, **Agriculture** and **Local Manufacturing** goods, built with **FastAPI** (backend) and **Flutter** (cross-platform frontend).

## 🏗️ Architecture

```
Ort/
├── src/                        # FastAPI backend
│   ├── app/
│   │   ├── main.py             # FastAPI entry point
│   │   ├── api/v1/
│   │   │   ├── api.py          # Root router (imports all sub-routers)
│   │   │   ├── auth.py         # JWT login
│   │   │   ├── tenants.py      # Tenant + subscription management
│   │   │   ├── agriculture.py  # Agriculture commodity listings
│   │   │   ├── manufacturing.py# Wholesale manufacturing products
│   │   │   ├── orders.py       # Order management
│   │   │   ├── messages.py     # Conversations & messaging
│   │   │   ├── rfq.py          # Request for Quote workflow
│   │   │   ├── reviews.py      # Ratings & reviews
│   │   │   └── notifications.py# User notifications
│   │   ├── models/
│   │   │   ├── models.py           # Core real-estate models (unchanged)
│   │   │   └── marketplace_models.py # Extended SaaS marketplace models
│   │   ├── schemas/
│   │   │   ├── schemas.py          # Core schemas (unchanged)
│   │   │   └── marketplace_schemas.py # Extended schemas
│   │   └── database/database.py
│   ├── docker-compose.yml
│   ├── dockerfile
│   └── requirements.txt
└── flutter_app/                # Flutter cross-platform frontend
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── core/
        │   ├── constants.dart
        │   ├── theme.dart
        │   ├── router.dart
        │   ├── api_service.dart
        │   └── auth_provider.dart
        ├── models/models.dart
        ├── screens/
        │   ├── auth/          login_screen, register_screen
        │   ├── home/          home_screen (dashboard)
        │   ├── properties/    properties_screen, property_detail_screen
        │   ├── agriculture/   agriculture_screen, agriculture_detail_screen
        │   ├── manufacturing/ manufacturing_screen, manufacturing_detail_screen
        │   ├── orders/        orders_screen, order_detail_screen
        │   ├── messages/      conversations_screen, chat_screen
        │   └── profile/       profile_screen
        └── widgets/
            └── listing_card.dart
```

## 🚀 Features

### Backend API (FastAPI)

| Module | Endpoints |
|---|---|
| **Auth** | `POST /auth/login` — JWT bearer token |
| **Users** | Full CRUD with bcrypt password hashing |
| **Tenants** | Organization onboarding (individual, SME, enterprise, government, NGO) |
| **Subscriptions** | Plan management (Free / Professional / Enterprise / Government) |
| **Properties** | Land, residential, commercial listings with geolocation support |
| **Agriculture** | Commodity listings with MOQ, quality grades, certifications, perishability flags |
| **Manufacturing** | Wholesale product catalog with tiered pricing, batch tracking, certifications |
| **Orders** | Full order lifecycle (pending → confirmed → shipped → delivered), with order items |
| **Messaging** | Conversations and messages with file/voice attachment support |
| **RFQ** | Request-for-Quote creation and response management |
| **Reviews** | Star ratings (1-5) with verified-purchase flag |
| **Notifications** | Per-user notification feed with read/unread tracking |

### Flutter App

- **Login / Register** — JWT-authenticated, role-based
- **Home Dashboard** — Summarised property, agriculture and manufacturing feeds
- **Properties Screen** — Full list with card-based UI, status badges
- **Agriculture Screen** — Commodity listings with MOQ, perishability & certification chips
- **Manufacturing Screen** — Wholesale catalog with tiered pricing indicators
- **Orders Screen** — Buyer order history with status badges
- **Messages Screen** — Conversations list + real-time chat interface
- **Profile Screen** — Account management, subscription, RFQ access, logout

## 🛠️ Technology Stack

### Backend
| Layer | Technology |
|---|---|
| API framework | FastAPI 0.104 |
| ORM | SQLAlchemy 2.0 |
| Validation | Pydantic v2 |
| Auth | JWT (`python-jose`) + bcrypt (`passlib`) |
| Database (dev) | SQLite (zero-config) |
| Database (prod) | PostgreSQL with PostGIS |
| Cache / Queue | Redis + Celery |
| Containers | Docker / Docker Compose |

### Flutter App
| Layer | Package |
|---|---|
| State management | flutter_riverpod |
| Navigation | go_router |
| HTTP client | dio |
| Secure storage | flutter_secure_storage |
| Images | cached_network_image |

## 📦 Running the Backend

```bash
cd src
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Or with Docker:

```bash
cd src
docker-compose up --build
```

API docs: http://localhost:8000/docs

## 📱 Running the Flutter App

```bash
cd flutter_app
flutter pub get
flutter run
```

Set the backend URL:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

## 📚 API Endpoints (v2)

### Authentication
- `POST /api/v1/auth/login` — returns `access_token`

### Tenants & Subscriptions
- `GET/POST /api/v1/tenants/`
- `GET/PUT/DELETE /api/v1/tenants/{id}`
- `GET/POST /api/v1/subscription-plans/`
- `GET/POST /api/v1/tenant-subscriptions/`

### Agriculture
- `GET/POST /api/v1/agriculture/`
- `GET/PUT/DELETE /api/v1/agriculture/{id}`

### Manufacturing
- `GET/POST /api/v1/manufacturing/`
- `GET/PUT/DELETE /api/v1/manufacturing/{id}`

### Orders
- `GET/POST /api/v1/orders/`
- `GET/PUT/DELETE /api/v1/orders/{id}`

### Messaging
- `GET/POST /api/v1/messages/conversations/`
- `GET /api/v1/messages/?conversation_id={id}`
- `POST /api/v1/messages/`
- `PUT /api/v1/messages/{id}/read`

### RFQ
- `GET/POST /api/v1/rfq/`
- `GET/PUT /api/v1/rfq/{id}`
- `GET/POST /api/v1/rfq/{id}/responses`

### Reviews
- `GET/POST /api/v1/reviews/`
- `GET/DELETE /api/v1/reviews/{id}`

### Notifications
- `GET/POST /api/v1/notifications/`
- `PUT /api/v1/notifications/{id}`
- `PUT /api/v1/notifications/read-all/`

*(All original real-estate endpoints remain unchanged — see original README sections below.)*

---

## Original Real-Estate Endpoints

- `GET/POST /api/v1/users/`, `GET/PUT/DELETE /api/v1/users/{id}`
- `GET/POST /api/v1/clients/`, `GET/PUT/DELETE /api/v1/clients/{id}`
- `GET/POST /api/v1/properties/`, `GET/PUT/DELETE /api/v1/properties/{id}`
- `GET/POST /api/v1/property-images/`, `GET/DELETE /api/v1/property-images/{id}`
- `GET/POST /api/v1/listings/`, `GET /api/v1/listings/{id}`
- `GET/POST /api/v1/inquiries/`, `GET /api/v1/inquiries/{id}`
- `GET/POST /api/v1/appointments/`, `GET /api/v1/appointments/{id}`
- `GET/POST /api/v1/transactions/`, `GET /api/v1/transactions/{id}`
- `GET/POST /api/v1/payments/`, `GET /api/v1/payments/{id}`

## 🔧 Environment Variables

All runtime configuration is driven by environment variables.  Create a
`.env` file in the `src/` directory (or set the variables in your deployment
platform — e.g. Railway) before starting the application.

| Variable | Required | Default | Description |
|---|---|---|---|
| `DATABASE_URL` | No | `sqlite:///./real_estate.db` | Full database connection URL.  Use `postgresql://user:pass@host:5432/dbname` for production.  Railway provides a `postgres://` URL; the app normalises it automatically. |
| `SECRET_KEY` | **Yes** (prod) | `change-me-in-production` | Secret used to sign JWT tokens.  **Must** be changed before deploying to production. |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | No | `60` | JWT token lifetime in minutes. |
| `CORS_ORIGINS` | No | `*` | Comma-separated list of allowed CORS origins (e.g. `https://your-app.com,https://admin.your-app.com`).  Defaults to `*` (all origins) if not set. |
| `PORT` | No | `8008` | Port the server binds to.  Set automatically by Railway; the `dockerfile` CMD reads `${PORT:-8008}`. |
| `MTN_COLLECTION_USER_ID` | Yes (for MTN top-up) | — | MTN MoMo Collection API user ID. |
| `MTN_COLLECTION_API_KEY` | Yes (for MTN top-up) | — | MTN MoMo Collection API key for the API user. |
| `MTN_COLLECTION_SUBSCRIPTION_KEY` | Yes (for MTN top-up) | — | MTN Ocp-Apim subscription key for Collection product. |
| `MTN_COLLECTION_TARGET_ENV` | No | `live` | MTN target environment (`live` or provider-specific value). |
| `MTN_COLLECTION_BASE_URL` | No | `https://momodeveloper.mtn.com` | MTN Collection base URL. Override for production host as needed. |
| `MTN_COLLECTION_CALLBACK_URL` | No | — | Public callback URL for asynchronous payment status updates. |

### Flutter / Dart-define variables

| Variable | Default | Description |
|---|---|---|
| `API_BASE_URL` | `https://ort.up.railway.app/api/v1` | Backend API base URL used by the Flutter app.  Pass via `--dart-define=API_BASE_URL=<url>` at build/run time. |

### Minimal `.env` for local development with PostgreSQL

```env
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/ort
SECRET_KEY=my-local-dev-secret
```

### MTN Mobile Money live integration

Wallet top-up now supports live MTN Mobile Money request-to-pay calls via `/api/v1/wallet/topup` when `payment_method` is `mtn`.

Required setup:

1. Create/enable an MTN MoMo Collection application.
2. Set the MTN variables above in your environment.
3. Send top-up requests with:
   - `amount`: number of points to credit
   - `payment_method`: `mtn`
   - `reference`: payer MSISDN

Notes:
- Base wallet conversion is **1 point = 1,000 UGX**.
- Wallet responses include:
  - `ugx_value` (points converted to UGX),
  - `display_currency`,
  - `display_amount`,
  - `exchange_rate`.
- Non-MTN methods (`airtel`, `card`) continue to credit wallet points directly.

> SQLite is used automatically when `DATABASE_URL` is not set, so **no
> database setup is needed for local development**.



## 👤 Author

**AllanRye9**

## 📄 License

MIT


## 🏗️ Architecture

This application follows a modern microservices architecture with:
- **FastAPI** - High-performance Python web framework
- **PostgreSQL with PostGIS** - Spatial database for location-based queries (SQLite for local development)
- **Redis** - Caching and message broker
- **Celery** - Asynchronous task processing
- **Docker** - Containerized deployment

## 🚀 Features

### Core Functionality
- **User Management** - Role-based access control (Agents, Admins) with bcrypt password hashing
- **Client Management** - Track buyers, sellers, and renters
- **Property Management** - Comprehensive property listings with images
- **Listing System** - Manage sale and rental listings
- **Inquiry System** - Handle property inquiries
- **Appointments** - Schedule property viewings
- **Transactions** - Track property sales and purchases
- **Payment Processing** - Handle payments and financial transactions

### Property Types
- Houses
- Apartments
- Land
- Commercial Properties

### Property Status Tracking
- Available
- Sold
- Rented
- Pending

## 🛠️ Technology Stack

### Backend
- **FastAPI 0.104.1** - Modern, fast web framework
- **SQLAlchemy 2.0** - ORM with `DeclarativeBase` (non-deprecated API)
- **Pydantic 2.5.0** - Data validation with `field_validator`, `EmailStr`, and `Decimal` for financial fields
- **Alembic 1.12.1** - Database migrations

### Database & Caching
- **PostgreSQL with PostGIS** - Spatial database capabilities (production)
- **SQLite** - Zero-config local development (default when `DATABASE_URL` is not set)
- **GeoAlchemy2 & Shapely** - Geographic data handling
- **Redis 5.0.1** - Caching and task queue

### Asynchronous Processing
- **Celery 5.3.4** - Distributed task queue
- **AsyncPG** - Async PostgreSQL driver

### Authentication & Security
- **python-jose** - JWT token handling
- **passlib with bcrypt** - Password hashing (active — passwords are hashed before storage)

### Development Tools
- **pytest** - Testing framework
- **black, isort, flake8** - Code formatting and linting
- **Docker & Docker Compose** - Containerization

## 📦 Installation & Setup

### Prerequisites
- Docker and Docker Compose installed
- Python 3.11+ (if running locally)

### Using Docker (Recommended)

1. Clone the repository:
```bash
git clone https://github.com/AllanRye9/Ort.git
cd Ort/src
```

2. Create a `.env` file in the `src` directory with your environment variables:
```env
DATABASE_URL=postgresql://postgres:postgres@db:5432/realestate
REDIS_URL=redis://redis:6379/0
SECRET_KEY=your-secret-key-here
CORS_ORIGINS=https://your-frontend.com,https://admin.your-app.com
```

3. Build and run the containers:
```bash
docker-compose up --build
```

4. Access the API:
- **API Documentation**: http://localhost:8000/docs
- **Alternative Docs**: http://localhost:8000/redoc
- **API Base URL**: http://localhost:8000/api/v1
- **Health Check**: http://localhost:8000/health

### Local Development Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Run database migrations:
```bash
alembic upgrade head
```

3. Start the development server:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

> SQLite is used automatically when `DATABASE_URL` is not set, so no database setup is needed for local development.

## 📚 API Documentation

### Pagination

All list endpoints support `skip` and `limit` query parameters for efficient pagination:

```
GET /api/v1/users/?skip=0&limit=50
GET /api/v1/properties/?skip=100&limit=25
```

- `skip` — number of records to skip (default: `0`)
- `limit` — maximum records to return (default: `100`, max: `1000`)

### Available Endpoints

#### Users
- `GET /api/v1/users/` - List users (paginated)
- `GET /api/v1/users/{user_id}` - Get user by ID
- `POST /api/v1/users/` - Create new user (password is bcrypt-hashed)
- `PUT /api/v1/users/{user_id}` - Partial update (only provided fields are changed)
- `DELETE /api/v1/users/{user_id}` - Delete user

#### Clients
- `GET /api/v1/clients/` - List clients (paginated)
- `GET /api/v1/clients/{client_id}` - Get client by ID
- `POST /api/v1/clients/` - Create new client
- `PUT /api/v1/clients/{client_id}` - Partial update
- `DELETE /api/v1/clients/{client_id}` - Delete client

#### Properties
- `GET /api/v1/properties/` - List properties (paginated)
- `GET /api/v1/properties/{property_id}` - Get property by ID
- `POST /api/v1/properties/` - Create new property
- `PUT /api/v1/properties/{property_id}` - Partial update (including status)
- `DELETE /api/v1/properties/{property_id}` - Delete property

#### Property Images
- `GET /api/v1/property-images/` - List property images (paginated)
- `GET /api/v1/property-images/{image_id}` - Get image by ID
- `POST /api/v1/property-images/` - Add image to property
- `DELETE /api/v1/property-images/{image_id}` - Delete image

#### Listings
- `GET /api/v1/listings/` - List listings (paginated)
- `GET /api/v1/listings/{listing_id}` - Get listing by ID
- `POST /api/v1/listings/` - Create listing

#### Inquiries
- `GET /api/v1/inquiries/` - List inquiries (paginated)
- `GET /api/v1/inquiries/{inquiry_id}` - Get inquiry by ID
- `POST /api/v1/inquiries/` - Submit inquiry

#### Appointments
- `GET /api/v1/appointments/` - List appointments (paginated)
- `GET /api/v1/appointments/{appointment_id}` - Get appointment by ID
- `POST /api/v1/appointments/` - Schedule appointment

#### Transactions
- `GET /api/v1/transactions/` - List transactions (paginated)
- `GET /api/v1/transactions/{transaction_id}` - Get transaction by ID
- `POST /api/v1/transactions/` - Record transaction

#### Payments
- `GET /api/v1/payments/` - List payments (paginated)
- `GET /api/v1/payments/{payment_id}` - Get payment by ID
- `POST /api/v1/payments/` - Record payment

Full interactive API documentation is available at `/docs` when the server is running.

## 🏗️ Project Structure

```
Ort/
├── src/
│   ├── app/
│   │   ├── main.py              # FastAPI application entry point
│   │   ├── api/
│   │   │   └── v1/
│   │   │       └── api.py       # API route definitions
│   │   ├── models/
│   │   │   └── models.py        # SQLAlchemy database models (with indexes)
│   │   ├── schemas/
│   │   │   └── schemas.py       # Pydantic v2 validation schemas
│   │   └── database/
│   │       └── database.py      # Database configuration
│   ├── dockerfile               # Docker image definition
│   ├── docker-compose.yml       # Multi-container setup
│   └── requirements.txt         # Python dependencies
└── README.md
```

## 🐳 Docker Services

The application runs with the following services:

1. **api** - FastAPI application (Port 8000)
2. **db** - PostgreSQL with PostGIS (Port 5432)
3. **redis** - Redis cache (Port 6379)
4. **celery_worker** - Background task processor
5. **celery_beat** - Scheduled task scheduler

## 🧪 Testing

Run tests using pytest:

```bash
pytest
pytest --cov  # With coverage report
```

## 🔒 Security

- **Passwords** are hashed with bcrypt via `passlib` before storage — plain-text passwords are never persisted.
- **Duplicate email** registration is rejected with HTTP 409.
- **CORS** origins are configured via the `CORS_ORIGINS` environment variable (comma-separated list). Defaults to `*` when the variable is not set; restrict in production.
- **JWT authentication** middleware and HTTPS/TLS should be configured for production deployments.
- Use environment variables for all secrets (`SECRET_KEY`, `DATABASE_URL`, etc.).

## 📝 Database Schema

### Core Tables
- **users** - System users (agents, admins)
- **clients** - Property clients (buyers, sellers, renters)
- **properties** - Property listings
- **property_images** - Property photos
- **listings** - Sale/rental listings
- **inquiries** - Client inquiries
- **appointments** - Property viewings
- **transactions** - Sales/purchases
- **payments** - Financial transactions

### Indexes
Performance indexes are defined on all foreign key columns and frequently filtered columns (`status`, `city`, `email`).

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 👤 Author

**AllanRye9**

## 🔗 Links

- Repository: [https://github.com/AllanRye9/Ort](https://github.com/AllanRye9/Ort)
- Issues: [https://github.com/AllanRye9/Ort/issues](https://github.com/AllanRye9/Ort/issues)

---
