-- Idempotent hotfix: ensure "SellerPackage" has the "scope" column (and the
-- backing "PackageScope" enum type it depends on).
--
-- Root cause: ensure_seller_subscriptions.sql creates the "SellerPackage"
-- table as a fallback whenever the real migration that introduced it fails
-- partway. That fallback CREATE TABLE never included the "scope" column
-- (schema.prisma has `scope PackageScope @default(LISTING)`), because the
-- CV-package feature (scope = 'LISTING' | 'CV') was added after that
-- fallback was written. On any environment where SellerPackage came into
-- existence via that fallback path rather than a clean
-- `prisma migrate deploy`, the column simply doesn't exist — so every CV
-- package query (`prisma.sellerPackage.findFirst({ where: { scope: 'CV', ... } })`)
-- fails with `column "scope" does not exist`, which the CV payment routes
-- correctly (but confusingly) surface to the frontend as
-- "Database schema is out of date."
--
-- Safe to run repeatedly, and a no-op on databases where the column/type
-- already exist (all statements are guarded).

DO $$ BEGIN
  CREATE TYPE "PackageScope" AS ENUM ('LISTING', 'CV');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Existing rows predate the CV feature and were always listing packages,
-- so backfilling them to 'LISTING' via the column default is correct.
ALTER TABLE "SellerPackage"
  ADD COLUMN IF NOT EXISTS "scope" "PackageScope" NOT NULL DEFAULT 'LISTING';
