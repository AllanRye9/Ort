# Ort Marketplace – Change Log

## Summary of Changes

All changes preserve backward compatibility with existing agriculture and
manufacturing data. No existing tables are dropped. The `service_listings`
table is new and created automatically on first startup via `Base.metadata.create_all()`.

---

## 1. Landing Page (`src/app/api/v1/landing.py`) — **NEW FILE**

A fully-designed public landing page served at `/` (root).

### Features
- **Android APK download button** — links to `APK_DOWNLOAD_URL` env var; shows a friendly dialog if not configured
- **iOS download button** — links to `IPA_DOWNLOAD_URL` or `TESTFLIGHT_URL`; shows a friendly dialog if not configured
- **"Play Store – Coming Soon"** badge (no fake store image)
- **"App Store – Coming Soon"** badge (no fake store image)
- Three-service showcase (Agric, Manufacturing, Services)
- Stats bar (3 categories, UGX base currency, 54+ countries, 100% African-focused)
- How It Works section
- About / Currency section (UGX base, auto-converts by locale)
- Portal links (/web, /medi, /const)
- Download CTA section
- Footer with all navigation

### Environment Variables
```
APK_DOWNLOAD_URL=https://your-cdn.example.com/ort-latest.apk
IPA_DOWNLOAD_URL=https://your-cdn.example.com/ort-latest.ipa
TESTFLIGHT_URL=https://testflight.apple.com/join/XXXXXXXX
```

---

## 2. Real Estate Removal

Real Estate is **completely removed from the UI** across all portals:

| File | Change |
|------|--------|
| `web_portal.py` | Removed Properties tab; now shows Agriculture → Manufacturing → Services |
| `const_admin.py` | Removed Properties content buttons, stat cards, chart labels; added Services |
| `medi_portal.py` | No Properties section was present; Services module added |
| `admin.py` | Removed `total_properties` from dashboard stats; removed `new_properties` from reports |

> Note: The `Property` model and its DB table are **not dropped** to preserve existing data and avoid destructive migrations. The `/admin/content/properties/` endpoint still exists in the backend but is not surfaced in any UI.

---

## 3. Three Services Module

### New Model (`src/app/models/marketplace_models.py`)

`ServiceListing` table added with fields:
- `id`, `tenant_id`, `posted_by_user_id`
- `title`, `description`, `category`, `sub_category`, `service_mode`
- `price`, `price_currency` (default `UGX`), `pricing_type`, `pricing_notes`
- `country`, `city`, `address`, `latitude`, `longitude`
- `whatsapp_number`, `contact_email`, `website_url`, `google_maps_url`
- `images`, `documents`, `tags` (JSON)
- `is_flash_deal`, `flash_deal_ends_at`, `is_today_deal`, `is_verified`, `is_deleted`
- `status` (active / inactive / pending_review / rejected)
- `listing_code` (auto-generated: `ORT-SVC-YYYY-XXXXXX`)
- `view_count`, `created_at`, `updated_at`

### New Router (`src/app/api/v1/services.py`)
Full CRUD at `/api/v1/services/`:
- `GET /services/` — list with filters (category, status, keyword, country, city, price range, radius search, flash/today deals)
- `GET /services/{id}` — get single + increment view count
- `POST /services/` — create (auth required)
- `PUT /services/{id}` — update (owner or admin)
- `DELETE /services/{id}` — soft delete (owner or admin)

### Admin Endpoints (`admin.py`)
- `GET /admin/content/services/` — list all services with filters
- `PATCH /admin/content/services/{id}/status` — update status
- `DELETE /admin/content/services/{id}` — soft delete
- Services included in deleted items / restore / purge endpoints
- `total_services` added to dashboard stats
- `new_services` added to reports overview

---

## 4. Web Portal (`/web`) — Updated

- Tab order: **Agriculture → Manufacturing → Services** (Properties removed)
- Mobile bottom nav updated to match
- `?tab=` URL param respected (e.g. `/web?tab=services` from landing page links)
- `getMeta()` helper updated for Services cards
- Card title fallback updated to show "Service" for service listings
- Hero text updated: "Discover Agriculture, Manufacturing & Services"

---

## 5. Admin Console (`/const`) — Updated

- Dashboard stat cards: Agriculture (green) + Manufacturing (blue) + Services (purple)
- Content management buttons: Agriculture + Manufacturing + Services
- Deleted items section: Agriculture + Manufacturing + Services
- Reports chart: Updated labels/values to include Services, remove Properties
- Default content tab: `agriculture` (was `properties`)

---

## 6. Companies & Agents Portal (`/medi`) — Updated

### Services Module Added
- **Service Listings card** in the Postings section (purple theme)
- "+ New Service" button opens a modal form
- Service modal fields: title, category, sub-category, service mode, pricing type, price, currency, country, city, WhatsApp, description, status
- Full CRUD: create, edit, delete service listings
- `loadPostings()` now calls `loadAgriculture() + loadManufacturing() + loadServices()` in parallel

---

## 7. Railway Deployment (`railway.toml`) — **NEW FILE**

```toml
[build]
builder = "dockerfile"
dockerfilePath = "src/dockerfile"

[deploy]
startCommand = "uvicorn app.main:app --host 0.0.0.0 --port $PORT"
healthcheckPath = "/health"
healthcheckTimeout = 30
```

- Uses existing `src/dockerfile` (no changes needed)
- `${PORT:-8080}` already handled in Dockerfile CMD
- Health check at `/health` endpoint (already exists in `main.py`)

---

## 8. Environment Variables (`.env.example`) — **NEW FILE**

Documents all required env vars including the new download URL vars.

---

## 9. API Router Registration (`api.py`)

`services_router` imported and registered at `/api/v1/services/`.

---

## 10. Main Application (`main.py`)

- Old `@app.get("/")` JSON home replaced by full landing page router
- `/health` endpoint retained
- `landing_router` registered before other routers so `/` is correctly handled

---

## Migration Notes

No manual migration needed. On first startup:
1. `Base.metadata.create_all()` runs automatically
2. New `service_listings` table is created
3. All existing tables remain unchanged

For production databases already running, the `service_listings` table will be created automatically. If using strict Alembic migrations, add a migration that creates the table using the schema in `marketplace_models.py`.
