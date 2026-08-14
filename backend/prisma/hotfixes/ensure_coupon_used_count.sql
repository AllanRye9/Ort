-- Idempotent compatibility hotfix: ensure Coupon.usedCount column exists.
-- Required for environments where the ecommerce_rebuild migration ran before
-- usedCount was added to the migration file.
ALTER TABLE "Coupon" ADD COLUMN IF NOT EXISTS "usedCount" INTEGER NOT NULL DEFAULT 0;
