import logging
import os
import sys
import time
import traceback

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.middleware.base import BaseHTTPMiddleware
from .database.database import engine, Base, run_schema_migrations
from .api.v1.api import router

# Import marketplace models so their tables are registered with Base
from .models import marketplace_models  # noqa: F401

# ---------------------------------------------------------------------------
# Logging – configure root logger so every module's logger writes to stdout.
# Gunicorn captures stdout/stderr and forwards them to Railway's log drain,
# so this is the canonical way to get logs into the Railway dashboard.
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    stream=sys.stdout,
    force=True,
)

logger = logging.getLogger(__name__)

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


# ---------------------------------------------------------------------------
# Request / response logging middleware
# Logs every incoming request and its outcome (status code + duration).
# Errors (5xx) are logged at ERROR level so they stand out in Railway logs.
# ---------------------------------------------------------------------------
class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start = time.perf_counter()
        method = request.method
        path = request.url.path
        query = request.url.query
        display_path = f"{path}?{query}" if query else path

        logger.info("→ %s %s (client=%s)", method, display_path, request.client)

        try:
            response = await call_next(request)
        except Exception as exc:
            duration_ms = (time.perf_counter() - start) * 1000
            logger.error(
                "✗ %s %s — unhandled exception after %.1f ms: %s",
                method,
                display_path,
                duration_ms,
                exc,
                exc_info=True,
            )
            raise

        duration_ms = (time.perf_counter() - start) * 1000
        level = logging.ERROR if response.status_code >= 500 else logging.INFO
        logger.log(
            level,
            "← %s %s %d (%.1f ms)",
            method,
            display_path,
            response.status_code,
            duration_ms,
        )
        return response


app.add_middleware(RequestLoggingMiddleware)


# ---------------------------------------------------------------------------
# Global exception handler – catches any exception that escapes route handlers
# and logs the full traceback before returning a generic 500 response.
# Without this, Starlette swallows the traceback and Railway only sees a
# connection-reset, which shows up as "Application failed to respond".
# ---------------------------------------------------------------------------
@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    tb = traceback.format_exc()
    logger.error(
        "Unhandled exception on %s %s:\n%s",
        request.method,
        request.url.path,
        tb,
    )
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error", "type": type(exc).__name__},
    )


# ---------------------------------------------------------------------------
# Database initialisation
# Wrapped in try/except so a connection failure or migration error surfaces
# as a clear log message rather than a silent crash.
# ---------------------------------------------------------------------------
logger.info("Initialising database schema…")
try:
    Base.metadata.create_all(bind=engine)
    logger.info("create_all() completed successfully")
except Exception as exc:
    logger.error(
        "Failed to create database tables: %s\n%s",
        exc,
        traceback.format_exc(),
    )
    raise

try:
    run_schema_migrations()
    logger.info("Schema migrations completed successfully")
except Exception as exc:
    logger.error(
        "Failed to run schema migrations: %s\n%s",
        exc,
        traceback.format_exc(),
    )
    raise

# Include all routes
app.include_router(router, prefix="/api/v1")

logger.info("Application startup complete — routes registered under /api/v1")

# ---------------------------------------------------------------------------
# Static file serving for locally-stored uploads (stub / no-S3 mode).
# When S3 is not configured the upload endpoint saves images to
# <repo-root>/static/listings/ and returns /static/listings/<uuid>.ext URLs.
# Mount this AFTER the API router so API routes take precedence.
# ---------------------------------------------------------------------------
from pathlib import Path as _Path
_STATIC_DIR = _Path(__file__).parents[2] / "static"
_STATIC_DIR.mkdir(parents=True, exist_ok=True)
(_STATIC_DIR / "listings").mkdir(exist_ok=True)
app.mount("/static", StaticFiles(directory=str(_STATIC_DIR)), name="static")


@app.get("/")
def home():
    return {"message": "Welcome to Real Estate Management API", "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "ok"}
