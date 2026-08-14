-- Idempotent compatibility hotfix for environments where Listing inventory columns
-- are missing due to schema drift or skipped migrations.
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "stock" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "sku" TEXT;
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "weightKg" DOUBLE PRECISION;
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "lengthCm" DOUBLE PRECISION;
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "widthCm" DOUBLE PRECISION;
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "heightCm" DOUBLE PRECISION;
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "tags" TEXT[] DEFAULT ARRAY[]::TEXT[];
