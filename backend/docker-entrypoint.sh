#!/bin/sh
set -e

if [ -n "${DATABASE_PRIVATE_URL}" ]; then
	export DATABASE_URL="${DATABASE_PRIVATE_URL}"
fi

echo "Running database migrations..."
DEPLOY_OUTPUT=$(npx prisma migrate deploy 2>&1) && DEPLOY_OK=1 || DEPLOY_OK=0
echo "$DEPLOY_OUTPUT"

if [ "$DEPLOY_OK" = "0" ]; then
	echo ""
	echo "prisma migrate deploy failed – attempting to resolve failed migrations..."

	# Extract failed migration names from the deploy output.
	# Prisma outputs lines like: The `<name>` migration started at … failed
	# The migration SQL uses IF NOT EXISTS guards, so marking as rolled-back
	# and re-deploying is safe.
	FAILED_MIGRATIONS=$(echo "$DEPLOY_OUTPUT" | sed -n 's/.*`\([^`]*\)` migration.*failed.*/\1/p')

	if [ -n "$FAILED_MIGRATIONS" ]; then
		for mig in $FAILED_MIGRATIONS; do
			echo "Marking migration $mig as rolled back..."
			npx prisma migrate resolve --rolled-back "$mig" || true
		done

		echo "Retrying prisma migrate deploy..."
		if ! npx prisma migrate deploy; then
			if [ -n "${RAILWAY_ENVIRONMENT_ID:-}${RAILWAY_PROJECT_ID:-}" ]; then
				echo "Prisma migrate deploy still failed during Railway startup; proceeding to compatibility hotfix check."
			else
				exit 1
			fi
		fi
	else
		if [ -n "${RAILWAY_ENVIRONMENT_ID:-}${RAILWAY_PROJECT_ID:-}" ]; then
			echo "Prisma migrate deploy failed during Railway startup; proceeding to compatibility hotfix check."
		else
			exit 1
		fi
	fi
fi

echo "Ensuring Listing compatibility columns exist..."
if ! npx prisma db execute --file ./prisma/hotfixes/ensure_listing_inventory_columns.sql --schema ./prisma/schema.prisma; then
	echo "Compatibility hotfix failed; startup cannot continue safely."
	exit 1
fi

echo "Ensuring Coupon.usedCount column exists..."
if ! npx prisma db execute --file ./prisma/hotfixes/ensure_coupon_used_count.sql --schema ./prisma/schema.prisma; then
	echo "Coupon compatibility hotfix failed; check that the Coupon table exists and the database user has ALTER TABLE privileges."
	exit 1
fi

echo "Ensuring SiteStat table exists..."
if ! npx prisma db execute --file ./prisma/hotfixes/ensure_site_stat_table.sql --schema ./prisma/schema.prisma; then
	echo "SiteStat hotfix failed; continuing anyway."
fi

echo "Ensuring SellerPackage and SellerSubscription tables exist..."
if ! npx prisma db execute --file ./prisma/hotfixes/ensure_seller_subscriptions.sql --schema ./prisma/schema.prisma; then
	echo "SellerSubscription compatibility hotfix failed; check that the Currency/NotificationType enums exist and the database user has CREATE TABLE privileges."
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

echo "Ensuring UserDocument table exists..."
if ! npx prisma db execute --file ./prisma/hotfixes/ensure_user_documents.sql --schema ./prisma/schema.prisma; then
	echo "UserDocument compatibility hotfix failed; check that the database user has CREATE TABLE privileges."
	exit 1
fi

echo "Seeding default listing packages (free/monthly/yearly)..."
if ! npx prisma db execute --file ./prisma/hotfixes/ensure_default_packages.sql --schema ./prisma/schema.prisma; then
	echo "Default packages seed failed; continuing anyway."
fi

echo "Ensuring listing/category details columns exist..."
if ! npx prisma db execute --file ./prisma/hotfixes/ensure_listing_category_details.sql --schema ./prisma/schema.prisma; then
  echo "listing/category details hotfix failed; continuing anyway."
fi

echo "Ensuring SiteConfig columns exist (interview video, general settings, logo pages type)..."
if ! npx prisma db execute --file ./prisma/hotfixes/ensure_site_config_columns.sql --schema ./prisma/schema.prisma; then
  echo "SiteConfig compatibility hotfix failed; settings page saves may not persist."
fi

# Entry point already attempted migrations. Prevent duplicate startup attempt in node process.
export AUTO_MIGRATE_ON_START=false

echo "Starting server..."
exec node dist/index.js
