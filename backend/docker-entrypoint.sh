#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# Production entrypoint for the marketplace backend container.
#
# Responsibilities:
#   1. Resolve a Prisma CLI DATABASE_URL from DATABASE_PRIVATE_URL when needed.
#   2. Run the single db setup script for migration/hotfix orchestration.
#   3. Set AUTO_MIGRATE_ON_START=false and exec the Node process so the app
#      does not run the setup logic a second time in-process.
# ─────────────────────────────────────────────────────────────────────────────
set -e

echo "[docker-entrypoint] Starting marketplace backend container..."

if [ -z "$DATABASE_URL" ] && [ -z "$DATABASE_PRIVATE_URL" ]; then
  echo "[docker-entrypoint] ERROR: neither DATABASE_URL nor DATABASE_PRIVATE_URL is set." >&2
  echo "[docker-entrypoint] Set one of them to a valid PostgreSQL connection string." >&2
  exit 1
fi

if [ -z "$DATABASE_URL" ]; then
  export DATABASE_URL="$DATABASE_PRIVATE_URL"
  echo "[docker-entrypoint] DATABASE_URL not set — using DATABASE_PRIVATE_URL for Prisma CLI calls."
fi

export AUTO_MIGRATE_ON_START=false

echo "[docker-entrypoint] Running database setup (migrations + hotfixes)..."
if ! npx ts-node --project tsconfig.node.json --transpile-only scripts/db-setup.ts; then
  echo "[docker-entrypoint] FATAL: database setup failed. Refusing to start the API." >&2
  exit 1
fi

echo "[docker-entrypoint] Handing off to: $*"
exec "$@"
