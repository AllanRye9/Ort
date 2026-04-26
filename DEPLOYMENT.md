# Deployment Guide

## Overview

The Ort platform consists of a FastAPI backend (`src/`) and a Flutter app (`flutter_app/`).
The backend is hosted on Railway; the Flutter web build can be served via Railway or any static CDN.

---

## Backend (Railway)

### Environment Variables

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | ✅ | PostgreSQL connection string (Railway provides `postgres://`; the app auto-converts to `postgresql://`) |
| `SECRET_KEY` | ✅ | JWT signing secret — must be a long random string in production |
| `REDIS_URL` | ✅ | Redis connection URL for Celery broker + backend (e.g. `redis://default:pass@host:6379/0`) |
| `ORT_MEDIAA_KEY` | ✅ | S3-compatible storage access key |
| `ORT_MEDIAA_SECRET` | ✅ | S3-compatible storage secret key |
| `ORT_MEDIAA_NAME` | ✅ | Storage bucket/container name |
| `ORT_MEDIAA_API` | ✅ | S3-compatible endpoint URL |
| `S3_PUBLIC_BASE_URL` | ✅ | Public base URL for uploaded assets |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | optional | JWT expiry (default: 60) |
| `CORS_ORIGINS` | optional | Comma-separated list of allowed CORS origins (default: `*`) |
| `APP_BASE_URL` | optional | Public base URL (default: `https://ort.up.railway.app`) |
| `AWS_ACCESS_KEY_ID` | optional | Legacy AWS key (if not using ORT_MEDIAA_*) |
| `AWS_SECRET_ACCESS_KEY` | optional | Legacy AWS secret |
| `AWS_REGION` | optional | AWS region (default: `us-east-1`) |
| `S3_BUCKET_NAME` | optional | Legacy S3 bucket name |
| `S3_ENDPOINT_URL` | optional | Legacy S3 endpoint URL |

### Services Required on Railway

1. **PostgreSQL** — provided by Railway's PostgreSQL plugin
2. **Redis** — provided by Railway's Redis plugin; set `REDIS_URL` from the plugin's connection URL

### Celery Workers

The Celery worker must be started separately from the web server:

```bash
celery -A app.tasks.celery_app worker --loglevel=info
```

For scheduled tasks (daily challenge reset at midnight UTC), also run Celery Beat:

```bash
celery -A app.tasks.celery_app beat --loglevel=info
```

On Railway, add additional services/processes via the `Procfile`:

```
web: gunicorn -k uvicorn.workers.UvicornWorker -b 0.0.0.0:$PORT src.app.main:app
worker: celery -A app.tasks.celery_app worker --loglevel=info
beat: celery -A app.tasks.celery_app beat --loglevel=info
```

---

## Security Hardening

### Rate Limiting

`slowapi` is configured on the FastAPI app. Auth endpoints are rate-limited:

- `POST /api/v1/auth/login` — 10 requests/minute per IP
- `POST /api/v1/auth/register` — 5 requests/minute per IP

### DDoS & CDN Protection (Cloudflare)

For production deployments, route all traffic through Cloudflare:

1. Point your domain's DNS to Railway's custom domain CNAME.
2. Enable **Cloudflare Proxy** (orange cloud) on the DNS record.
3. Set **Security Level** to *Medium* or *High* in the Cloudflare dashboard.
4. Enable **Bot Fight Mode** and **DDoS protection** under Security → DDoS.
5. Add a **Rate Limiting** rule (Cloudflare plan) to block IPs exceeding 100 requests/minute globally.
6. Use Cloudflare **WAF** rules to block common exploit patterns.

### HTTPS

Railway enforces HTTPS automatically on all custom domains. Do not expose HTTP endpoints in production.

---

## Database Backups

### Automated Backups via Railway

Railway Pro includes automatic daily snapshots. Enable via:
- Project Settings → Databases → Enable Backups

### Manual pg_dump Backup

```bash
pg_dump "$DATABASE_URL" --format=custom --file="backup_$(date +%Y%m%d).dump"
```

To restore:

```bash
pg_restore --dbname="$DATABASE_URL" backup_YYYYMMDD.dump
```

### Celery-Scheduled Backup (optional)

Add a periodic task in `tasks/analytics.py` to run `pg_dump` and upload the result to S3:

```python
@celery_app.task(name="app.tasks.analytics.backup_database")
def backup_database():
    import subprocess, datetime, os, boto3
    filename = f"backup_{datetime.date.today()}.dump"
    subprocess.run(["pg_dump", os.getenv("DATABASE_URL", ""), "-Fc", "-f", f"/tmp/{filename}"], check=True)
    # Upload to S3 ...
```

Schedule this in `beat_schedule` at an appropriate interval.

---

## Flutter Web (PWA)

The Flutter web build is a PWA with `display: standalone`. To deploy:

```bash
cd flutter_app
flutter build web --release --dart-define=API_BASE_URL=https://ort.up.railway.app/api/v1
```

Serve the `build/web/` directory from any static host (Railway static sites, Cloudflare Pages, Vercel, etc.).

The `web/manifest.json` is pre-configured with:
- `"display": "standalone"` — installable PWA
- `"theme_color": "#2E7D32"` — Ort green
- Icons at 192×512px (standard + maskable)

---

## Monitoring

- **Railway Metrics** — CPU, memory, and request metrics are available in the Railway dashboard.
- **Application Logs** — All Python loggers write to stdout (captured by Railway's log drain).
- **Celery Flower** (optional) — Add `flower` to requirements and run `celery -A app.tasks.celery_app flower` for a task monitoring UI.
