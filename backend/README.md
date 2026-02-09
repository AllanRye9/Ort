# Real Estate Management API - Backend

A comprehensive FastAPI-based backend for managing real estate properties, users, clients, and transactions with JWT authentication and role-based access control.

## Features

- **JWT Authentication**: Secure token-based authentication with bcrypt password hashing
- **Role-Based Access Control**: Separate permissions for agents and admins
- **RESTful API**: Clean, intuitive endpoints following REST principles
- **Database Support**: SQLite for development, PostgreSQL for production
- **Comprehensive Models**: Users, Clients, Properties, Transactions, Payments, and more
- **API Documentation**: Auto-generated with Swagger UI and ReDoc
- **Docker Support**: Easy deployment with Docker and Docker Compose

## Tech Stack

- **FastAPI**: Modern, fast web framework for building APIs
- **SQLAlchemy**: SQL toolkit and ORM
- **Pydantic**: Data validation using Python type annotations
- **JWT (python-jose)**: JSON Web Token implementation
- **Bcrypt (passlib)**: Password hashing
- **Uvicorn**: ASGI server
- **Gunicorn**: Production WSGI server

## Project Structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI application entry point
│   ├── config.py            # Configuration management
│   ├── auth.py              # JWT authentication & authorization
│   ├── database.py          # Database connection & session
│   ├── models/              # SQLAlchemy models
│   │   ├── __init__.py
│   │   ├── user.py          # User and Client models
│   │   ├── property.py      # Property-related models
│   │   └── transaction.py   # Transaction and Payment models
│   ├── schemas/             # Pydantic schemas
│   │   ├── __init__.py
│   │   ├── user.py          # User schemas
│   │   ├── property.py      # Property schemas
│   │   └── transaction.py   # Transaction schemas
│   └── routers/             # API route handlers
│       ├── __init__.py
│       ├── auth.py          # Authentication endpoints
│       ├── users.py         # User & client endpoints
│       ├── properties.py    # Property endpoints
│       └── transactions.py  # Transaction endpoints
├── requirements.txt         # Python dependencies
├── Dockerfile              # Docker configuration
├── .env.example            # Environment variables example
└── README.md               # This file
```

## Installation

### Prerequisites

- Python 3.11+
- pip
- virtualenv (recommended)

### Local Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd backend
   ```

2. **Create a virtual environment**:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Set up environment variables**:
   ```bash
   cp .env.example .env
   # Edit .env and update configuration values
   ```

5. **Generate a secure secret key**:
   ```bash
   openssl rand -hex 32
   # Copy the output and set it as SECRET_KEY in .env
   ```

6. **Run the application**:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

7. **Access the API**:
   - API: http://localhost:8000
   - Swagger UI: http://localhost:8000/docs
   - ReDoc: http://localhost:8000/redoc

## Docker Deployment

### Using Docker

1. **Build the image**:
   ```bash
   docker build -t real-estate-api .
   ```

2. **Run the container**:
   ```bash
   docker run -d -p 8000:8000 --env-file .env real-estate-api
   ```

### Using Docker Compose

1. **Create docker-compose.yml** (example):
   ```yaml
   version: '3.8'
   services:
     api:
       build: .
       ports:
         - "8000:8000"
       env_file:
         - .env
       volumes:
         - ./data:/app/data
   ```

2. **Start the services**:
   ```bash
   docker-compose up -d
   ```

## API Endpoints

### Authentication

- `POST /api/v1/auth/register` - Register a new user
- `POST /api/v1/auth/login` - Login and get JWT token
- `GET /api/v1/auth/me` - Get current user info
- `POST /api/v1/auth/change-password` - Change user password

### Users & Clients

- `GET /api/v1/users/` - List all users (authenticated)
- `GET /api/v1/users/{user_id}` - Get user by ID
- `POST /api/v1/users/` - Create new user (admin only)
- `PUT /api/v1/users/{user_id}` - Update user
- `DELETE /api/v1/users/{user_id}` - Delete user (admin only)
- `GET /api/v1/users/clients/all` - List all clients
- `POST /api/v1/users/clients/` - Create new client
- `PUT /api/v1/users/clients/{client_id}` - Update client
- `DELETE /api/v1/users/clients/{client_id}` - Delete client

### Properties

- `GET /api/v1/properties/` - List all properties (public)
- `GET /api/v1/properties/{property_id}` - Get property by ID
- `POST /api/v1/properties/` - Create new property (authenticated)
- `PUT /api/v1/properties/{property_id}` - Update property
- `DELETE /api/v1/properties/{property_id}` - Delete property
- `GET /api/v1/properties/images/all` - List property images
- `POST /api/v1/properties/images/` - Add property image
- `GET /api/v1/properties/listings/all` - List all listings
- `POST /api/v1/properties/listings/` - Create listing
- `GET /api/v1/properties/inquiries/all` - List inquiries
- `POST /api/v1/properties/inquiries/` - Create inquiry (public)
- `GET /api/v1/properties/appointments/all` - List appointments
- `POST /api/v1/properties/appointments/` - Create appointment

### Transactions

- `GET /api/v1/transactions/` - List all transactions (authenticated)
- `GET /api/v1/transactions/{transaction_id}` - Get transaction by ID
- `POST /api/v1/transactions/` - Create new transaction
- `PUT /api/v1/transactions/{transaction_id}` - Update transaction
- `DELETE /api/v1/transactions/{transaction_id}` - Delete transaction (admin only)
- `GET /api/v1/transactions/payments/all` - List all payments
- `POST /api/v1/transactions/payments/` - Create payment

## Authentication

The API uses JWT (JSON Web Tokens) for authentication. To access protected endpoints:

1. **Register or login** to get an access token
2. **Include the token** in the Authorization header:
   ```
   Authorization: Bearer <your-token-here>
   ```

### Example using curl:

```bash
# Login
curl -X POST "http://localhost:8000/api/v1/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=user@example.com&password=yourpassword"

# Use token for authenticated requests
curl -X GET "http://localhost:8000/api/v1/users/" \
  -H "Authorization: Bearer <token>"
```

## Role-Based Access Control

The API implements role-based access control with two roles:

- **Agent**: Can manage properties, clients, and view transactions
- **Admin**: Full access to all endpoints including user management

## Database Models

### User
- Users (agents and admins)
- Authentication credentials
- Profile information

### Client
- Buyers, sellers, and renters
- Contact information
- Relationship with agent

### Property
- Property details (title, type, price, etc.)
- Status (available, sold, rented, pending)
- Images and listings

### Transaction
- Sales records
- Commission tracking
- Payment history

## Environment Variables

Key environment variables (see `.env.example` for all options):

- `DATABASE_URL`: Database connection string
- `SECRET_KEY`: JWT secret key (use `openssl rand -hex 32`)
- `ACCESS_TOKEN_EXPIRE_MINUTES`: Token expiration time
- `CORS_ORIGINS`: Allowed CORS origins
- `DEBUG`: Enable debug mode (development only)

## Development

### Running in Development Mode

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Running Tests

```bash
pytest
```

### Code Quality

```bash
# Format code
black app/

# Sort imports
isort app/

# Lint code
flake8 app/
```

## Production Deployment

### Using Gunicorn

```bash
gunicorn -k uvicorn.workers.UvicornWorker app.main:app \
  --bind 0.0.0.0:8000 \
  --workers 4 \
  --access-logfile - \
  --error-logfile -
```

### Best Practices

1. **Use PostgreSQL** for production database
2. **Set strong SECRET_KEY** (use `openssl rand -hex 32`)
3. **Enable HTTPS** with reverse proxy (nginx/Apache)
4. **Set DEBUG=False** in production
5. **Use environment variables** for sensitive data
6. **Implement rate limiting** for API endpoints
7. **Set up monitoring** and logging
8. **Regular database backups**

## Security Features

- **Password Hashing**: Bcrypt with configurable rounds
- **JWT Tokens**: Secure token-based authentication
- **Role-Based Access**: Granular permission control
- **CORS Protection**: Configurable allowed origins
- **SQL Injection Protection**: SQLAlchemy ORM
- **Input Validation**: Pydantic schemas

## API Documentation

Once the server is running, comprehensive API documentation is available at:

- **Swagger UI**: http://localhost:8000/docs
  - Interactive API documentation
  - Try out endpoints directly in the browser
  
- **ReDoc**: http://localhost:8000/redoc
  - Alternative documentation format
  - Clean, three-panel design

## Troubleshooting

### Database Issues

If you encounter database errors:
```bash
# Delete the database file (SQLite)
rm real_estate.db

# Restart the application (tables will be recreated)
uvicorn app.main:app --reload
```

### Import Errors

```bash
# Ensure you're in the virtual environment
source venv/bin/activate

# Reinstall dependencies
pip install -r requirements.txt
```

### Port Already in Use

```bash
# Use a different port
uvicorn app.main:app --port 8001
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Write/update tests
5. Submit a pull request

## License

[Specify your license here]

## Support

For issues, questions, or contributions, please [create an issue](link-to-issues) or contact the development team.
