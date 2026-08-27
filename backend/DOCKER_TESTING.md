# Local Docker testing (backend + PostgreSQL)

`docker-compose.test.yml` in this directory spins up the **production**
backend image (`backend/Dockerfile` — the same one Railway builds) against a
real PostgreSQL 16 container, so you can catch Docker/Prisma/entrypoint
issues locally before pushing.

## Quick start

```bash
cd backend
docker compose -f docker-compose.test.yml up --build
```

This will:
1. Build `backend/Dockerfile` (multi-stage: install → `prisma generate` +
   `tsc` build → minimal non-root runtime image).
2. Start `postgres:16-alpine` and wait for it to report healthy
   (`pg_isready`) before starting the backend.
3. Run `docker-entrypoint.sh` inside the backend container: applies Prisma
   migrations (or bootstraps the schema on a fresh DB — see
   `prisma/migrations/README.md`), applies any `prisma/hotfixes/*.sql`, then
   starts `node dist/index.js`.
4. Expose the API on `http://localhost:5000` and Postgres on
   `localhost:55432` (kept off the default `5432` so it won't collide with a
   Postgres you already have running locally).

Check it worked:

```bash
curl http://localhost:5000/health
# {"status":"ok"}
```

## Using your own secrets

```bash
cp .env.example .env.test
# edit .env.test — set real JWT secrets, admin password, etc.
docker compose --env-file .env.test -f docker-compose.test.yml up --build
```

Every variable in `docker-compose.test.yml` has a development-safe default
(`${VAR:-default}`), so running without `--env-file` at all also works for a
quick smoke test — just don't reuse those defaults anywhere real.

## Seeding data

Run the seed script inside the running container. The production image
doesn't ship `ts-node` as a devDependency-free image — it keeps
devDependencies specifically so tooling like this works (see comment at the
top of `Dockerfile`):

```bash
docker compose -f docker-compose.test.yml exec backend npx ts-node prisma/seed.ts

# or, for the ad-hoc brand-fields backfill:
docker compose -f docker-compose.test.yml exec backend npx ts-node --transpile-only scripts/seed-brand-fields.ts
```

## Resetting

```bash
docker compose -f docker-compose.test.yml down -v   # drops the DB volume too
```

## What this validates that `npm run dev` doesn't

- The actual multi-stage `Dockerfile` builds cleanly (catches missing
  files, broken `COPY` paths, TypeScript errors under a clean install).
- `docker-entrypoint.sh` runs correctly as PID 1 inside the container,
  including the migration/bootstrap fallback logic.
- The container runs as the non-root `nodeuser`, matching production.
- The `/health` Docker `HEALTHCHECK` passes the way Railway's health check
  will.
