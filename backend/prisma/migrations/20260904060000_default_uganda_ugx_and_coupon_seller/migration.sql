-- Cluster 1: Default all site functionality to Uganda / UGX.
-- These ALTER COLUMN ... SET DEFAULT statements only change the default
-- applied to *new* rows going forward (matching the updated schema.prisma
-- defaults). They intentionally do NOT touch existing data — a store or
-- listing that was explicitly created for UAE/AED should not be silently
-- reassigned. Use a one-off admin/data-migration script if backfilling
-- historical rows to Uganda/UGX is ever required.

ALTER TABLE "User"          ALTER COLUMN "country"  SET DEFAULT 'UGANDA';
ALTER TABLE "Listing"       ALTER COLUMN "country"  SET DEFAULT 'UGANDA';
ALTER TABLE "Listing"       ALTER COLUMN "currency" SET DEFAULT 'UGX';
ALTER TABLE "Order"         ALTER COLUMN "currency" SET DEFAULT 'UGX';
ALTER TABLE "OrderItem"     ALTER COLUMN "currency" SET DEFAULT 'UGX';
ALTER TABLE "Payment"       ALTER COLUMN "currency" SET DEFAULT 'UGX';
ALTER TABLE "Withdrawal"    ALTER COLUMN "currency" SET DEFAULT 'UGX';
ALTER TABLE "SellerPackage" ALTER COLUMN "currency" SET DEFAULT 'UGX';
ALTER TABLE "StoreRental"   ALTER COLUMN "currency" SET DEFAULT 'UGX';
ALTER TABLE "JobPost"       ALTER COLUMN "country"  SET DEFAULT 'UGANDA';

-- Cluster 3: Web Store "Promotion and discount setup" tool — coupons a
-- store owner creates from their own dashboard are scoped to their store
-- via sellerId (platform-wide coupons from /admin/coupons keep sellerId
-- NULL, unaffected).
ALTER TABLE "Coupon" ADD COLUMN "sellerId"    TEXT;
ALTER TABLE "Coupon" ADD COLUMN "description" TEXT;

CREATE INDEX "Coupon_sellerId_idx" ON "Coupon"("sellerId");

ALTER TABLE "Coupon"
  ADD CONSTRAINT "Coupon_sellerId_fkey"
  FOREIGN KEY ("sellerId") REFERENCES "User"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
