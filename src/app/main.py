import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .database.database import engine, Base
from .api.v1.api import router

app = FastAPI(
    title="Real Estate Management API",
    version="1.0.0",
    description="A comprehensive real estate management API for buying, selling, and renting properties.",
)

_cors_origins_env = os.getenv("CORS_ORIGINS", "")
cors_origins = [o.strip() for o in _cors_origins_env.split(",") if o.strip()] or ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
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
