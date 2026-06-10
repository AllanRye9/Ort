# Ort Marketplace — piitrade.com

Africa's commerce platform for **Agricultural produce**, **Manufacturing goods**, and **Professional services**.  
Built with FastAPI · PostgreSQL · Deployed on Railway.app

**Live site:** https://piitrade.com

---

## Table of Contents

1. [Live URLs](#live-urls)
2. [Architecture Overview](#architecture-overview)
3. [Three Service Modules](#three-service-modules)
4. [Getting Started (Local)](#getting-started-local)
5. [Railway Deployment](#railway-deployment)
6. [Environment Variables](#environment-variables)
7. [API Reference](#api-reference)
8. [Admin Console — /const](#admin-console----const)
9. [Companies & Agents Portal — /medi](#companies--agents-portal----medi)
10. [App Downloads](#app-downloads)
11. [Currency Logic](#currency-logic)
12. [Project Structure](#project-structure)

---

## Live URLs

| Path | Description |
|------|-------------|
| `https://piitrade.com/` | Landing page — app download, service overview |
| `https://piitrade.com/web` | Public marketplace — browse Agriculture, Manufacturing & Services |
| `https://piitrade.com/medi` | Companies, Organizations & Agents portal |
| `https://piitrade.com/const` | Admin console (restricted) |
| `https://piitrade.com/api/v1/` | REST API base |
| `https://piitrade.com/docs` | Interactive Swagger UI |
| `https://piitrade.com/health` | Health check endpoint |

---

## Architecture Overview

```
piitrade.com  (Railway.app — single Docker container)
│
├── /               → Landing page (HTML, no framework)
├── /web            → Public marketplace portal (HTML + vanilla JS)
├── /medi           → Companies & Agents portal (HTML + vanilla JS)
├── /const          → Admin console (HTML + vanilla JS, auth-gated)
├── /api/v1/        → FastAPI REST API
│   ├── /auth/      → Login, register, token refresh
│   ├── /agriculture/
│   ├── /manufacturing/
│   ├── /services/  ← NEW
│   ├── /orders/
│   ├── /messages/
│   ├── /rfq/
│   ├── /reviews/
│   ├── /wallet/
│   ├── /notifications/
│   ├── /admin/     → Admin-only endpoints
│   └── ...
├── /docs           → Swagger UI
└── /static/        → Local file uploads (use S3 in production)
```

**Database:** PostgreSQL (Railway add-on)  
**Auth:** JWT Bearer tokens (python-jose)  
**Storage:** Local `/static/listings/` or AWS S3 (set `AWS_S3_BUCKET`)  

---

## Three Service Modules

Real Estate has been **completely removed**. The platform now offers three independent modules:

### 🌾 Agriculture
- Farm produce, livestock, aquaculture
- Agricultural inputs (seeds, chemicals, fertilizers)
- Farm equipment and machinery
- Export-grade produce listings
- API: `/api/v1/agriculture/`

### 🏭 Manufacturing
- Finished manufactured goods
- Raw materials and industrial inputs
- Production and processing services
- B2B and wholesale listings
- API: `/api/v1/manufacturing/`

### 🛠️ Services
- Professional consulting (legal, financial, management)
- Technical and IT services
- Transport and logistics
- Health, education, and general services
- API: `/api/v1/services/`

Each module is **fully independent** — separate listings, separate filters, separate admin management, separate portal sections.

---

## Getting Started (Local)

### Prerequisites
- Docker and Docker Compose
- Git

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/your-org/ort-marketplace.git
cd ort-marketplace

# 2. Create your local .env file
cp .env.example src/.env
# Edit src/.env — at minimum set SECRET_KEY

# 3. Start services
cd src
docker compose up --build

# 4. The API is now running at:
#    http://localhost:8000
#    http://localhost:8000/docs      (Swagger)
#    http://localhost:8000/web       (Marketplace)
#    http://localhost:8000/medi      (Companies portal)
#    http://localhost:8000/const     (Admin console)
```

### Create the first admin user

```bash
# While the API is running, register then promote via the database:
docker exec -it ort_db psql -U postgres -d ort_marketplace \
  -c "UPDATE users SET role='admin' WHERE email='admin@piitrade.com';"
```

---

## Railway Deployment

### First deploy

1. **Fork / push** this repository to GitHub.
2. On [Railway.app](https://railway.app):
   - **New Project → Deploy from GitHub repo** → select this repo
   - Railway auto-detects `railway.toml` and uses `src/dockerfile`
3. **Add a PostgreSQL service:**
   - Click **+ New** → **Database** → **Add PostgreSQL**
   - Railway sets `DATABASE_URL` automatically — no action needed
4. **Set environment variables** (Settings → Variables):

   | Variable | Value |
   |----------|-------|
   | `SECRET_KEY` | A long random string (use `openssl rand -hex 32`) |
   | `CORS_ORIGINS` | `https://piitrade.com,https://www.piitrade.com` |
   | `ADMIN_EMAIL` | Your admin email |
   | `ADMIN_PASSWORD` | Your admin password |

5. Railway builds and deploys. Visit your Railway domain or **set a custom domain** to `piitrade.com`.

### Custom domain (piitrade.com)

1. Railway dashboard → your service → **Settings → Networking → Custom Domain**
2. Add `piitrade.com` and `www.piitrade.com`
3. Update your DNS:
   - `piitrade.com` → `CNAME` pointing to your Railway domain (e.g. `ort-marketplace-production.up.railway.app`)
   - `www.piitrade.com` → same CNAME
4. Railway handles TLS/SSL automatically.

### Redeploys

Every push to your main branch triggers an automatic redeploy on Railway.

---

## Environment Variables

Copy `.env.example` to `src/.env` for local development.  
Set these in Railway → Settings → Variables for production.

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | ✅ | — | PostgreSQL connection string (Railway sets this automatically) |
| `SECRET_KEY` | ✅ | — | JWT signing secret — use a long random string |
| `ALGORITHM` | | `HS256` | JWT algorithm |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | | `60` | Token lifetime in minutes |
| `CORS_ORIGINS` | | `https://piitrade.com` | Comma-separated allowed origins |
| `APK_DOWNLOAD_URL` | | *(blank)* | Direct APK download link — shown on landing page |
| `IPA_DOWNLOAD_URL` | | *(blank)* | iOS IPA or TestFlight URL — shown on landing page |
| `TESTFLIGHT_URL` | | *(blank)* | TestFlight invite link |
| `AWS_S3_BUCKET` | | *(blank)* | S3 bucket name — leave blank for local disk storage |
| `AWS_ACCESS_KEY_ID` | | *(blank)* | AWS credentials (only if using S3) |
| `AWS_SECRET_ACCESS_KEY` | | *(blank)* | AWS credentials (only if using S3) |
| `AWS_REGION` | | `us-east-1` | AWS region |
| `OPENAI_API_KEY` | | *(blank)* | OpenAI key for AI assistant features |
| `PORT` | | `8080` | Set automatically by Railway — do not set manually |

---

## API Reference

Full interactive docs at: **https://piitrade.com/docs**

### Authentication

```http
POST /api/v1/auth/login
Content-Type: application/x-www-form-urlencoded

username=user@example.com&password=yourpassword
```

Response: `{ "access_token": "...", "token_type": "bearer" }`

Use the token as: `Authorization: Bearer <token>`

### Key Endpoints

#### Agriculture
```
GET    /api/v1/agriculture/              List listings (filterable)
GET    /api/v1/agriculture/{id}          Get single listing
POST   /api/v1/agriculture/              Create listing (auth required)
PUT    /api/v1/agriculture/{id}          Update listing
DELETE /api/v1/agriculture/{id}          Delete listing
```

Query params: `keyword`, `category`, `country`, `city`, `min_price`, `max_price`, `is_flash_deal`, `is_today_deal`, `lat`, `lon`, `radius_km`, `skip`, `limit`

#### Manufacturing
```
GET    /api/v1/manufacturing/            List products
GET    /api/v1/manufacturing/{id}        Get product
POST   /api/v1/manufacturing/            Create product (auth)
PUT    /api/v1/manufacturing/{id}        Update product
DELETE /api/v1/manufacturing/{id}        Delete product
```

#### Services (NEW)
```
GET    /api/v1/services/                 List service listings
GET    /api/v1/services/{id}             Get single service
POST   /api/v1/services/                 Create service (auth)
PUT    /api/v1/services/{id}             Update service
DELETE /api/v1/services/{id}            Delete service
```

Query params: `keyword`, `category`, `service_mode` (onsite/remote/hybrid), `country`, `city`, `min_price`, `max_price`, `is_flash_deal`, `is_today_deal`, `lat`, `lon`, `radius_km`

#### Auth
```
POST   /api/v1/auth/register             Register new user
POST   /api/v1/auth/login                Login (returns JWT)
GET    /api/v1/auth/me                   Current user profile
POST   /api/v1/auth/logout               Logout
```

#### Orders
```
GET    /api/v1/orders/                   List my orders
POST   /api/v1/orders/                   Create order
GET    /api/v1/orders/{id}               Order details
PATCH  /api/v1/orders/{id}/status        Update order status
```

---

## Admin Console — /const

**URL:** https://piitrade.com/const  
**Access:** Admin users only (role = `admin`)

### Features

| Section | Path | Description |
|---------|------|-------------|
| Dashboard | `/const` | Overview stats — users, orders, listings by module |
| Users | `/const` (Users tab) | Browse, search, role management |
| Agriculture | `/const` (Content tab) | Manage all agriculture listings |
| Manufacturing | `/const` (Content tab) | Manage all manufacturing products |
| **Services** | `/const` (Content tab) | Manage all service listings |
| Deleted Items | `/const` (Deleted tab) | View and restore soft-deleted content |
| Flash Deals | `/const` (Flash Deals tab) | Control flash deals (max 100 listings) |
| Today's Deals | `/const` (Today's Deals tab) | Control today's deals |
| Orders | `/const` (Orders tab) | View and manage all orders |
| Messages | `/const` (Messages tab) | Browse conversation logs |
| Reports | `/const` (Reports tab) | Activity charts and stats by date range |
| Settings | `/const` (Settings tab) | WhatsApp number, country switching, currency |
| CV / Payments | `/const` (CV tab) | CV download and payment logs |
| Agents | `/const` (Agents tab) | Manage registered agents |

### Admin API Endpoints
```
GET    /api/v1/admin/dashboard/stats         Overview stats
GET    /api/v1/admin/dashboard/reports       Activity by date range
GET    /api/v1/admin/users/                  List all users
PATCH  /api/v1/admin/users/{id}/role         Change user role
GET    /api/v1/admin/content/agriculture/    List all agriculture
GET    /api/v1/admin/content/manufacturing/  List all manufacturing
GET    /api/v1/admin/content/services/       List all services
GET    /api/v1/admin/deleted/                List soft-deleted items
PATCH  /api/v1/admin/deleted/{type}/{id}/restore   Restore item
DELETE /api/v1/admin/deleted/{type}/{id}     Permanently delete
GET    /api/v1/admin/orders/                 All orders
GET    /api/v1/admin/flash-deals/            Flash deal listings
GET    /api/v1/admin/settings/               Platform settings
```

---

## Companies & Agents Portal — /medi

**URL:** https://piitrade.com/medi  
**Access:** Registered users (companies, organizations, agents)

### What you can do

| Entity Type | Description |
|-------------|-------------|
| **Company** | Register a company profile, manage listings, view dashboard |
| **Organization** | NGOs, cooperatives, farmer groups — non-commercial entities |
| **Agent** | Individual agents representing services or products |

### Features

- **Profile creation** — name, logo, description, contact info, location, verification status
- **Listing management:**
  - 🌾 Agriculture listings — create, edit, delete
  - 🏭 Manufacturing products — create, edit, delete
  - 🛠️ Service listings — create, edit, delete *(new)*
- **Dashboard** — view your own listings, orders, and messages
- **Verification status** — pending → approved flow
- **Separate login/registration** for business entities

### Registration flow

1. Go to https://piitrade.com/medi
2. Click **Register** — choose Company, Organization, or Agent
3. Fill in your profile details
4. Submit for verification (admin reviews and approves)
5. Once approved, start adding listings

---

## App Downloads

The mobile app (Flutter) is available for direct download while Play Store / App Store listings are pending.

| Platform | Status | Link |
|----------|--------|------|
| Android (APK) | Available | Set `APK_DOWNLOAD_URL` env var |
| iOS (IPA / TestFlight) | Available | Set `IPA_DOWNLOAD_URL` or `TESTFLIGHT_URL` env var |
| Google Play Store | **Coming Soon** | — |
| Apple App Store | **Coming Soon** | — |

To activate download buttons on the landing page, set these in Railway environment variables:
```
APK_DOWNLOAD_URL=https://your-cdn.com/ort-latest.apk
IPA_DOWNLOAD_URL=https://your-cdn.com/ort-latest.ipa
```

---

## Currency Logic

- **Base currency:** Ugandan Shillings (**UGX**) — the system anchor
- All other users see prices converted to their local currency based on device locale / geolocation
- Currency conversion uses real-time rates where possible
- Supported currencies include: UGX, KES, TZS, RWF, NGN, GHS, USD, EUR, and all major African currencies
- Users and admins can manually switch country/currency via settings

---

## Project Structure

```
ort-marketplace/
├── railway.toml                  # Railway deployment config
├── .env.example                  # Environment variable reference
├── CHANGES.md                    # Detailed change log
│
├── src/
│   ├── dockerfile                # Production Docker image
│   ├── docker-compose.yml        # Local development stack
│   ├── requirements.txt          # Python dependencies
│   │
│   └── app/
│       ├── main.py               # FastAPI app, middleware, startup
│       ├── dependencies.py       # Auth dependency (get_current_user)
│       ├── exceptions.py         # Custom exception types
│       │
│       ├── api/v1/
│       │   ├── api.py            # Router aggregator
│       │   ├── auth.py           # /auth/* endpoints
│       │   ├── agriculture.py    # /agriculture/* endpoints
│       │   ├── manufacturing.py  # /manufacturing/* endpoints
│       │   ├── services.py       # /services/* endpoints (NEW)
│       │   ├── orders.py         # /orders/* endpoints
│       │   ├── messages.py       # /messages/* endpoints
│       │   ├── rfq.py            # /rfq/* endpoints
│       │   ├── reviews.py        # /reviews/* endpoints
│       │   ├── wallet.py         # /wallet/* endpoints
│       │   ├── notifications.py  # /notifications/* endpoints
│       │   ├── admin.py          # /admin/* endpoints
│       │   ├── agent.py          # /agent/* endpoints
│       │   ├── upload.py         # /upload/* endpoints
│       │   ├── tracking.py       # /tracking/* endpoints
│       │   ├── tenants.py        # /tenants/* endpoints
│       │   ├── landing.py        # / (root landing page)
│       │   ├── web_portal.py     # /web (public marketplace)
│       │   ├── medi_portal.py    # /medi (companies & agents)
│       │   └── const_admin.py    # /const (admin console)
│       │
│       ├── models/
│       │   ├── models.py         # User, Property, Transaction models
│       │   └── marketplace_models.py  # Agriculture, Manufacturing,
│       │                              # Services, Orders, etc.
│       │
│       ├── schemas/
│       │   ├── schemas.py
│       │   └── marketplace_schemas.py
│       │
│       ├── database/
│       │   └── database.py       # Engine, session, schema migrations
│       │
│       └── utils/
│           ├── geo.py            # Haversine distance
│           ├── countries.py      # Country name normalisation
│           └── push.py           # Push notification helpers
│
└── ort_marketplace/              # Flutter mobile app source
    ├── lib/
    │   ├── main.dart
    │   ├── core/                 # Auth, router, theme, API service
    │   ├── models/
    │   ├── screens/              # All app screens
    │   └── widgets/
    ├── android/
    ├── ios/
    └── pubspec.yaml
```

---

## Troubleshooting

### 502 Bad Gateway on Railway
- Check Railway logs: dashboard → your service → **Deployments** → click the latest → **View Logs**
- Most common causes:
  1. `DATABASE_URL` not set — add the PostgreSQL service in Railway
  2. App crashed on startup — check logs for Python traceback
  3. Port mismatch — Railway sets `$PORT`; the Dockerfile CMD uses `${PORT:-8080}` ✅

### Cannot connect to database
- Ensure Railway PostgreSQL add-on is added to your project
- The `DATABASE_URL` variable should be set automatically by Railway
- Verify with: Railway dashboard → Variables → confirm `DATABASE_URL` exists

### Login not working
- Ensure `SECRET_KEY` is set in Railway environment variables
- Default token lifetime is 60 minutes; adjust `ACCESS_TOKEN_EXPIRE_MINUTES`

### CORS errors in browser
- Set `CORS_ORIGINS=https://piitrade.com,https://www.piitrade.com` in Railway variables
- For local dev, `CORS_ORIGINS=*` is acceptable

### Images not loading
- Without S3 configured, images are stored at `/static/listings/` inside the container
- Container storage is ephemeral on Railway — configure `AWS_S3_BUCKET` for persistent image storage

---

*Ort Marketplace · Built for Africa · Anchored in Uganda*
