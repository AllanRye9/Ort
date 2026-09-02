-- Hotfix: backfill columns/tables that "prisma migrate deploy" marks as
-- applied (via the init migration) but that never actually got created on
-- this database, because it was bootstrapped with `prisma db push` from an
-- older version of prisma/schema.prisma and baselined afterward.
--
-- Confirmed missing on the live Railway DB via `prisma migrate diff
-- --from-url $DATABASE_URL --to-schema-datamodel prisma/schema.prisma`:
--   - table "SearchLog"        (+ 3 indexes, 1 FK)
--   - table "ListingClickLog"  (+ 3 indexes, 2 FKs)
--   - User.kycDocumentBackUrl
--   - User.kycDraftDocumentType
--   - User.kycDraftFullName
--   - User.kycDraftDocumentUrl
--   - User.kycDraftDocumentBackUrl
--   - User.kycDraftSelfieUrl
--   - User.kycDraftUpdatedAt
--
-- Every statement below is idempotent (IF NOT EXISTS / duplicate_object
-- guard) so this file is safe to run again on a database that's already
-- been fixed, and safe to run on a database that never had the drift.

-- ─── SearchLog ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "SearchLog" (
    "id" TEXT NOT NULL,
    "query" TEXT,
    "context" TEXT NOT NULL,
    "resultCount" INTEGER,
    "userId" TEXT,
    "userEmail" TEXT,
    "userPhone" TEXT,
    "ip" TEXT,
    "ipCountry" TEXT,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "locationAccuracy" DOUBLE PRECISION,
    "userAgent" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SearchLog_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "SearchLog_createdAt_idx" ON "SearchLog"("createdAt");
CREATE INDEX IF NOT EXISTS "SearchLog_query_idx" ON "SearchLog"("query");
CREATE INDEX IF NOT EXISTS "SearchLog_userId_createdAt_idx" ON "SearchLog"("userId", "createdAt");

DO $$ BEGIN
  ALTER TABLE "SearchLog" ADD CONSTRAINT "SearchLog_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ─── ListingClickLog ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "ListingClickLog" (
    "id" TEXT NOT NULL,
    "listingId" TEXT,
    "listingTitle" TEXT NOT NULL,
    "listingImage" TEXT,
    "userId" TEXT,
    "userEmail" TEXT,
    "userPhone" TEXT,
    "ip" TEXT,
    "ipCountry" TEXT,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "locationAccuracy" DOUBLE PRECISION,
    "userAgent" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ListingClickLog_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "ListingClickLog_createdAt_idx" ON "ListingClickLog"("createdAt");
CREATE INDEX IF NOT EXISTS "ListingClickLog_listingId_createdAt_idx" ON "ListingClickLog"("listingId", "createdAt");
CREATE INDEX IF NOT EXISTS "ListingClickLog_userId_createdAt_idx" ON "ListingClickLog"("userId", "createdAt");

DO $$ BEGIN
  ALTER TABLE "ListingClickLog" ADD CONSTRAINT "ListingClickLog_listingId_fkey"
    FOREIGN KEY ("listingId") REFERENCES "Listing"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE "ListingClickLog" ADD CONSTRAINT "ListingClickLog_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ─── User: missing KYC draft columns ───────────────────────────────────────
-- "KycDocumentType" enum already exists on this DB (User.kycDocumentType is
-- not in the missing-column list), so it's safe to reference it here without
-- creating it.
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "kycDocumentBackUrl" TEXT;
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "kycDraftDocumentType" "KycDocumentType";
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "kycDraftFullName" TEXT;
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "kycDraftDocumentUrl" TEXT;
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "kycDraftDocumentBackUrl" TEXT;
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "kycDraftSelfieUrl" TEXT;
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "kycDraftUpdatedAt" TIMESTAMP(3);
