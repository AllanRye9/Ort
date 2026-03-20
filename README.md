# Ort - Real Estate Management API

A comprehensive real estate software solution built with **FastAPI** that allows individuals, entrepreneurs, and investors to buy, sell, and rent properties seamlessly.

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
