# Local testing (production-grade)

There are two compose files, for two different purposes. Both build the
*exact same* Dockerfiles Railway uses — neither one is a "dev mode" compose
with bind-mounts or hot reload.

| File | What it runs | When to use it |
|---|---|---|
| `docker-compose.yml` (root) | Postgres + backend + **frontend** | End-to-end check before deploying — click through the actual UI against the real API and DB |
| `backend/docker-compose.test.yml` | Postgres + backend only | Fast iteration on API/migration/entrypoint changes without waiting on a frontend build |

## Full stack

```bash
cp .env.example .env        # fill in real secrets, or skip this for a quick smoke test
docker compose up --build
```

- Frontend: http://localhost:3000
- Backend: http://localhost:5000/health
- Postgres: localhost:55432 (mapped off 5432 so it won't collide with a
  Postgres you already have running)

Startup order is enforced with health checks, not just container start
order: Postgres must report healthy before the backend starts, and the
backend must pass its `/health` check before the frontend starts (the
frontend's SSR root layout calls the backend on first render).

Tear down, including volumes, for a clean slate:

```bash
docker compose down -v
```

### About `NEXT_PUBLIC_API_URL`

This value is baked into the frontend's client-side JS **at build time** and
is what the browser uses to reach the API — so it must be
`http://localhost:5000` (the host-published port), not `http://backend:5000`
(the internal Docker service name, which your browser can't resolve).

The frontend container's own server-side code (`app/layout.tsx`'s
background-image fetch) reuses this same env var, so it will also try
`localhost:5000` *from inside its own container*, where nothing is
listening on that port. That call is wrapped in a `try/catch` and degrades
gracefully (no background image, nothing else breaks) — this isn't a bug in
the compose file, it's the same graceful-degradation path that runs in
production if that fetch ever fails there too.

If you change `NEXT_PUBLIC_API_URL`, you must rebuild
(`docker compose up --build`) — restarting an existing container won't pick
up the new value, since it's compiled into the JS bundle, not read at
runtime.

## Backend + Postgres only

See `backend/DOCKER_TESTING.md` for the focused workflow (seeding, running
one-off scripts inside the container, etc.).

## What either stack validates that `npm run dev` doesn't

- The real multi-stage Dockerfiles build cleanly from a clean install
  (catches missing files, broken `COPY` paths, TypeScript errors).
- `docker-entrypoint.sh` runs correctly as PID 1, including the
  migration/schema-bootstrap fallback logic (see
  `backend/prisma/migrations/README.md`).
- Both containers run as non-root users, matching production.
- The `HEALTHCHECK`/`healthcheckPath` Railway relies on actually passes.
- The frontend's `output: 'standalone'` build boots correctly from
  `node server.js`, not `next dev`.
