-- Add partner approval fields to the Store table.
-- These columns are referenced in schema.prisma and stores.ts but were never
-- added to the database, causing every GET /api/stores request to fail with
-- a "column does not exist" error.

ALTER TABLE "Store"
  ADD COLUMN IF NOT EXISTS "partnerApproved"   BOOLEAN   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "partnerLogoUrl"    TEXT,
  ADD COLUMN IF NOT EXISTS "partnerName"       TEXT,
  ADD COLUMN IF NOT EXISTS "partnerWebsite"    TEXT,
  ADD COLUMN IF NOT EXISTS "partnerApprovedAt" TIMESTAMP(3);
