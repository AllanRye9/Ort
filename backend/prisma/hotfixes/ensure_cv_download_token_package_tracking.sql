-- Idempotent hotfix: ensure CvDownloadToken has deviceId/packageId columns.
-- These are created by the 20260807000000_add_cv_package_tracking migration.
-- This hotfix is a safety net for environments where that migration failed partway.

ALTER TABLE "CvDownloadToken" ADD COLUMN IF NOT EXISTS "deviceId" TEXT;
ALTER TABLE "CvDownloadToken" ADD COLUMN IF NOT EXISTS "packageId" TEXT;

DO $body$ BEGIN
  ALTER TABLE "CvDownloadToken" ADD CONSTRAINT "CvDownloadToken_packageId_fkey"
      FOREIGN KEY ("packageId") REFERENCES "SellerPackage"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $body$;

CREATE INDEX IF NOT EXISTS "CvDownloadToken_packageId_userId_idx" ON "CvDownloadToken"("packageId", "userId");
CREATE INDEX IF NOT EXISTS "CvDownloadToken_packageId_deviceId_idx" ON "CvDownloadToken"("packageId", "deviceId");
