#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# Production entrypoint for the marketplace backend container.
#
# Responsibilities:
#   1. Run `prisma migrate deploy` against DATABASE_URL / DATABASE_PRIVATE_URL
#      before the Node process starts, so the API never serves traffic
#      against a schema it doesn't understand.
#   2. Apply idempotent compatibility hotfixes (prisma/hotfixes/*.sql) the
#      same way src/index.ts does, as a drift-recovery safety net.
#   3. Set AUTO_MIGRATE_ON_START=false and exec the Node process, so
#      src/index.ts does NOT try to run migrations a second time in-process.
#
# A failing migration is fatal (exit non-zero) because starting the API
# against an out-of-date schema is worse than not starting at all. A failing
# individual hotfix is NOT fatal — same reasoning as the in-process fallback
# in src/index.ts: one broken/inapplicable SQL file must never take down the
# whole API.
# ─────────────────────────────────────────────────────────────────────────────
set -e

echo "[docker-entrypoint] Starting marketplace backend container..."

if [ -z "$DATABASE_URL" ] && [ -z "$DATABASE_PRIVATE_URL" ]; then
  echo "[docker-entrypoint] ERROR: neither DATABASE_URL nor DATABASE_PRIVATE_URL is set." >&2
  echo "[docker-entrypoint] Set one of them to a valid PostgreSQL connection string." >&2
  exit 1
fi

# schema.prisma only declares `url = env("DATABASE_URL")` — the Prisma CLI
# (migrate deploy / db push / db execute, all called below) reads that
# variable directly from the OS environment and has NO knowledge of the
# DATABASE_PRIVATE_URL fallback that src/utils/prisma.ts implements in code.
# On Railway, where DATABASE_PRIVATE_URL is the recommended variable to set,
# leaving DATABASE_URL unset caused every `npx prisma ...` call below to fail
# with "Environment variable not found: DATABASE_URL", which — because of
# `set -e` — killed the container before the API ever started. That looked
# like a CORS/network error from the frontend's perspective (no backend was
# ever there to respond) when the real cause was this mismatch. Bridge it
# here so either variable works for the CLI exactly as it already does for
# the running app.
if [ -z "$DATABASE_URL" ]; then
  export DATABASE_URL="$DATABASE_PRIVATE_URL"
  echo "[docker-entrypoint] DATABASE_URL not set — using DATABASE_PRIVATE_URL for Prisma CLI calls."
fi

# Prevent src/index.ts from running its own in-process migration/hotfix pass;
# this script is the single source of truth for schema setup in containers.
export AUTO_MIGRATE_ON_START=false

# Count real migration folders (directories under prisma/migrations, other
# than migration_lock.toml/README.md which are not migrations themselves).
migration_count=0
if [ -d "prisma/migrations" ]; then
  migration_count=$(find prisma/migrations -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
fi

if [ "$migration_count" -eq 0 ]; then
  # No migration history has been committed yet (see prisma/migrations/README.md).
  # Bootstrap a fresh database by pushing the schema directly. This is only
  # safe because a database with zero migrations applied has no data that
  # `db push --accept-data-loss` could destroy. As soon as a real migration
  # is committed, this branch is skipped forever in favor of `migrate deploy`.
  echo "[docker-entrypoint] No committed migrations found — bootstrapping schema with 'prisma db push'..."
  if ! npx prisma db push --accept-data-loss --skip-generate; then
    echo "[docker-entrypoint] FATAL: prisma db push failed. Refusing to start the API." >&2
    exit 1
  fi
  echo "[docker-entrypoint] Schema bootstrap complete."
else
  echo "[docker-entrypoint] Running prisma migrate deploy ($migration_count migration(s) found)..."
  if ! npx prisma migrate deploy; then
    echo "[docker-entrypoint] FATAL: prisma migrate deploy failed. Refusing to start the API." >&2
    exit 1
  fi
  echo "[docker-entrypoint] Migrations applied successfully."
fi

if [ -d "prisma/hotfixes" ]; then
  echo "[docker-entrypoint] Applying compatibility hotfixes..."
  for file in prisma/hotfixes/*.sql; do
    [ -e "$file" ] || continue
    echo "[docker-entrypoint]   -> $file"
    if ! npx prisma db execute --file "$file" --schema prisma/schema.prisma; then
      echo "[docker-entrypoint]   WARNING: hotfix $file failed — continuing (non-fatal)." >&2
    fi
  done
  echo "[docker-entrypoint] Compatibility hotfixes complete."
fi

echo "[docker-entrypoint] Handing off to: $*"
exec "$@"
