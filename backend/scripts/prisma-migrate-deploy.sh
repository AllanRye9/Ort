#!/bin/sh
set -e

if [ -f ./.env ]; then
  set -a
  . ./.env
  set +a
fi

if [ -n "${DATABASE_PRIVATE_URL}" ]; then
  export DATABASE_URL="${DATABASE_PRIVATE_URL}"
fi

# Optional signals from callers (e.g. deployment scripts) that code changed.
MIGRATION_FILES_CHANGED="${MIGRATION_FILES_CHANGED:-false}"
SCHEMA_CHANGED="${SCHEMA_CHANGED:-false}"

echo "Checking Prisma migration status..."
STATUS_OUTPUT="$(npx prisma migrate status --schema ./prisma/schema.prisma 2>&1 || true)"
echo "$STATUS_OUTPUT"

HAS_PENDING=false
if echo "$STATUS_OUTPUT" | grep -Ei "pending|not yet been applied|have not yet been applied" >/dev/null 2>&1; then
  HAS_PENDING=true
fi

if [ "$MIGRATION_FILES_CHANGED" = "true" ] || [ "$SCHEMA_CHANGED" = "true" ] || [ "$HAS_PENDING" = "true" ]; then
  echo "Applying Prisma migrations (detected changes or pending migrations)..."
  if ! npx prisma migrate deploy; then
    echo "Prisma migrate deploy failed."
    echo "Resolve the failed migration record before retrying:"
    echo "  npx prisma migrate resolve --rolled-back 20260322100000_add_personal_id"
    echo "or, if the schema change already exists in the database:"
    echo "  npx prisma migrate resolve --applied 20260322100000_add_personal_id"
    exit 1
  fi

  echo "Prisma migrations applied successfully."
else
  echo "No migration changes detected and no pending migrations. Skipping deploy."
fi

echo "Ensuring Listing compatibility columns exist..."
if ! npx prisma db execute --file ./prisma/hotfixes/ensure_listing_inventory_columns.sql --schema ./prisma/schema.prisma; then
  echo "Failed to apply Listing compatibility hotfix."
  exit 1
fi

echo "Ensuring Coupon.usedCount column exists..."
if ! npx prisma db execute --file ./prisma/hotfixes/ensure_coupon_used_count.sql --schema ./prisma/schema.prisma; then
  echo "Failed to apply Coupon compatibility hotfix. Ensure the Coupon table exists and the database user has ALTER TABLE privileges."
  exit 1
fi

echo "Ensuring SellerPackage.scope column exists (CV vs LISTING packages)..."
if ! npx prisma db execute --file ./prisma/hotfixes/ensure_cv_package_scope_column.sql --schema ./prisma/schema.prisma; then
  echo "SellerPackage.scope hotfix failed; CV package pricing lookups will keep failing with 'Database schema is out of date.'"
  exit 1
fi

echo "Ensuring CvDownloadToken has deviceId/packageId/holder* columns..."
if ! npx prisma db execute --file ./prisma/hotfixes/ensure_cv_download_token_columns.sql --schema ./prisma/schema.prisma; then
  echo "CvDownloadToken compatibility hotfix failed; CV payment/history routes may error."
  exit 1
fi

echo "Listing compatibility check completed."
