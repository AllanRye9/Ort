# Ort - Real Estate Management API

A comprehensive real estate software solution built with **FastAPI** that allows individuals, entrepreneurs, and investors to buy, sell, and rent properties seamlessly.

## 🏗️ Architecture

This application follows a modern microservices architecture with:
- **FastAPI** - High-performance Python web framework
- **PostgreSQL with PostGIS** - Spatial database for location-based queries
- **Redis** - Caching and message broker
- **Celery** - Asynchronous task processing
- **Docker** - Containerized deployment

## 🚀 Features

### Core Functionality
- **User Management** - Role-based access control (Agents, Admins)
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
- **SQLAlchemy 2.0.23** - ORM for database interactions
- **Pydantic 2.5.0** - Data validation using Python type annotations
- **Alembic 1.12.1** - Database migrations

### Database & Caching
- **PostgreSQL with PostGIS** - Spatial database capabilities
- **GeoAlchemy2 & Shapely** - Geographic data handling
- **Redis 5.0.1** - Caching and task queue

### Asynchronous Processing
- **Celery 5.3.4** - Distributed task queue
- **AsyncPG** - Async PostgreSQL driver

### Authentication & Security
- **python-jose** - JWT token handling
- **passlib with bcrypt** - Password hashing

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
```

3. Build and run the containers:
```bash
docker-compose up --build
```

4. Access the API:
- **API Documentation**: http://localhost:8000/docs
- **Alternative Docs**: http://localhost:8000/redoc
- **API Base URL**: http://localhost:8000/api/v1

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

## 📚 API Documentation

### Available Endpoints

#### Users
- `GET /api/v1/users/` - List all users
- `GET /api/v1/users/{user_id}` - Get user by ID
- `POST /api/v1/users/` - Create new user
- `PUT /api/v1/users/{user_id}` - Update user
- `DELETE /api/v1/users/{user_id}` - Delete user

#### Clients
- `GET /api/v1/clients/` - List all clients
- `GET /api/v1/clients/{client_id}` - Get client by ID
- `POST /api/v1/clients/` - Create new client

*(Similar patterns exist for Properties, Listings, Inquiries, Appointments, Transactions, and Payments)*

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
│   │   │   └── models.py        # SQLAlchemy database models
│   │   ├── schemas/
│   │   │   └── schemas.py       # Pydantic validation schemas
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

## 🔒 Security Notes

⚠️ **Important**: The current implementation includes placeholder password hashing. In production:
- Implement proper password hashing with `passlib`
- Add JWT authentication middleware
- Enable HTTPS/TLS
- Configure proper CORS origins
- Use environment variables for all secrets

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
