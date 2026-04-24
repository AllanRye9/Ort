import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .database.database import engine, Base
from .api.v1.api import router

# Import marketplace models so their tables are registered with Base
from .models import marketplace_models  # noqa: F401

app = FastAPI(
    title="Unified Commerce Marketplace API",
    version="2.0.0",
    description=(
        "A comprehensive SaaS marketplace API for properties, agriculture, "
        "and locally manufactured goods."
    ),
)

_cors_origins_env = os.getenv("CORS_ORIGINS", "")
cors_origins = [o.strip() for o in _cors_origins_env.split(",") if o.strip()] or ["*"]

# Explicit header list ensures preflight is accepted by all browsers,
# including those that do not honour the Access-Control-Allow-Headers: *
# wildcard (e.g. older WebKit/Safari builds used by Flutter Web on iOS).
_CORS_ALLOW_HEADERS = [
    "Authorization",
    "Content-Type",
    "Accept",
    "Origin",
    "X-Requested-With",
    "X-CSRF-Token",
    "Cache-Control",
    "Pragma",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"],
    allow_headers=_CORS_ALLOW_HEADERS,
    expose_headers=["Content-Length", "X-Request-Id"],
    max_age=600,
)

# Create tables
Base.metadata.create_all(bind=engine)

# Include all routes
app.include_router(router, prefix="/api/v1")


@app.get("/")
def home():
    return {"message": "Welcome to Real Estate Management API", "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "ok"}
