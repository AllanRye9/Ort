# Deploying Lapit (Piitrade) to Railway

This repo is a monorepo with two deployable services:

```
backend/    Express + Prisma API      → backend/Dockerfile, backend/railway.json
frontend/   Next.js 15 app            → frontend/Dockerfile, frontend/railway.json
```

Railway builds each service from its own Dockerfile and its own
`railway.json` (root-directory config-as-code — see
[Railway's monorepo docs](https://docs.railway.com/guides/deploying-a-monorepo)).
There is no single file that deploys "the whole repo" — you create **three**
Railway services in one project: a managed PostgreSQL database, the backend,
and the frontend.

## 1. Create the project and database

1. In the Railway dashboard: **New Project → Deploy PostgreSQL**.
2. This provisions a `Postgres` plugin service and exposes
   `DATABASE_URL` / `DATABASE_PUBLIC_URL` variables you'll reference below.

## 2. Add the backend service

1. **New → GitHub Repo** → select this repo.
2. In the new service's **Settings**:
   - **Root Directory**: `backend`
   - **Config-as-code Path**: `/backend/railway.json` (Railway does not
     resolve the config file relative to Root Directory — always give the
     absolute repo path)
   - Build automatically uses `backend/Dockerfile` (Dockerfile builder is
     already set in `railway.json`).
3. **Variables** (Settings → Variables). Reference the Postgres plugin's
   variables instead of hardcoding a URL:

   | Variable | Value |
   |---|---|
   | `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` |
   | `DATABASE_PRIVATE_URL` | `${{Postgres.DATABASE_PRIVATE_URL}}` (internal network — faster, no egress cost) |
   | `JWT_SECRET` | generate a long random string |
   | `JWT_REFRESH_SECRET` | generate a different long random string |
   | `JWT_EXPIRES_IN` | `1h` |
   | `JWT_REFRESH_EXPIRES_IN` | `7d` |
   | `NODE_ENV` | `production` |
   | `CORS_ORIGIN` | `https://<your-frontend>.up.railway.app` (add your real domain(s) later, comma-separated) |
   | `API_BASE_URL` | `https://<this-backend-service>.up.railway.app` |
   | `ADMIN_PASSWORD` / `ADMIN_SECRET` | strong secrets |
   | `ACCESS_KEY_ID` / `SECRET_ACCESS_KEY` / `BUCKET` / `ENDPOINT` | only if using S3-compatible storage (e.g. a Railway Bucket) — otherwise uploads fall back to local disk, which is **not persistent across deploys** unless you attach a [Railway Volume](https://docs.railway.com/reference/volumes) mounted at `/app/uploads` |
   | `RESEND_API_KEY` / `RESEND_FROM_EMAIL` | transactional email (optional) |

4. **Generate a domain**: Settings → Networking → Generate Domain.
5. Deploy. `docker-entrypoint.sh` runs automatically on every start:
   applies Prisma migrations (or bootstraps the schema via `prisma db push`
   if no migration history exists yet — see `backend/prisma/migrations/README.md`),
   runs compatibility hotfixes, then starts the API. Health check: `/health`.

## 3. Add the frontend service

1. **New → GitHub Repo** → same repo, again.
2. **Settings**:
   - **Root Directory**: `frontend`
   - **Config-as-code Path**: `/frontend/railway.json`
3. **Variables**:

   | Variable | Value |
   |---|---|
   | `NEXT_PUBLIC_API_URL` | `https://<your-backend-service>.up.railway.app` |

   `NEXT_PUBLIC_*` values are baked into the client bundle at **build** time.
   Railway passes service variables as Docker build args automatically when
   they're referenced as `ARG`s in the Dockerfile (already done in
   `frontend/Dockerfile`) — if you change this variable later, trigger a new
   deploy so the app rebuilds with the new value.

4. **Generate a domain**, then go back to the backend service and set its
   `CORS_ORIGIN` to that domain (Railway lets you reference it directly as
   `${{frontend.RAILWAY_PUBLIC_DOMAIN}}` prefixed with `https://`).
5. Deploy. Health check: `/`.

## 4. First-deploy checklist

- [ ] Postgres plugin is running and `DATABASE_URL`/`DATABASE_PRIVATE_URL` are
      wired into the backend service.
- [ ] Backend deploy logs show `Migrations applied successfully` (or
      `Schema bootstrap complete` on the very first deploy) followed by
      `Database connected` and `Server running on port …`.
- [ ] `https://<backend-domain>/health` returns `{"status":"ok"}`.
- [ ] Frontend deploy succeeded and `NEXT_PUBLIC_API_URL` points at the
      backend's public domain.
- [ ] Backend `CORS_ORIGIN` includes the frontend's public domain.
- [ ] Log in from the deployed frontend and confirm the session cookie is
      set (`authCookies.ts` already handles `secure`/`sameSite` correctly
      behind Railway's proxy via `trust proxy`).
- [ ] If you need persistent uploaded files without S3, attach a
      [Volume](https://docs.railway.com/reference/volumes) to the backend
      service mounted at `/app/uploads`.

## 5. Ongoing schema changes

Once `backend/prisma/migrations/` contains at least one real migration
(see `backend/prisma/migrations/README.md` for the one-time bootstrap
command), every subsequent deploy runs `prisma migrate deploy` — commit new
migrations with `npx prisma migrate dev --name <description>` and push; the
next Railway deploy applies them automatically before the API starts.

## 6. Testing locally before you push

See `backend/docker-compose.test.yml` — it builds the exact same
`backend/Dockerfile` used on Railway against a real PostgreSQL container, so
you can catch migration/entrypoint issues before they hit production.

```bash
cd backend
docker compose -f docker-compose.test.yml up --build
curl http://localhost:5000/health
docker compose -f docker-compose.test.yml down -v   # clean slate
```
