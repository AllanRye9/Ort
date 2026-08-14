-- Idempotent compatibility hotfix: ensure CvDownloadToken has every column,
-- index, and foreign key schema.prisma expects for the CV download history
-- feature (deviceId for rate-limiting guest downloads, packageId for the CV
-- package that governed the download, and the holder* snapshot fields shown
-- in the admin CV history dashboard). These were added to schema.prisma
-- without a matching migration ever being generated, so environments whose
-- migration history predates this feature are missing them entirely — this
-- is a safety net for those environments, mirroring the other hotfixes in
-- this folder.

ALTER TABLE "CvDownloadToken" ADD COLUMN IF NOT EXISTS "deviceId" TEXT;
ALTER TABLE "CvDownloadToken" ADD COLUMN IF NOT EXISTS "packageId" TEXT;
ALTER TABLE "CvDownloadToken" ADD COLUMN IF NOT EXISTS "holderName" TEXT;
ALTER TABLE "CvDownloadToken" ADD COLUMN IF NOT EXISTS "holderTitle" TEXT;
ALTER TABLE "CvDownloadToken" ADD COLUMN IF NOT EXISTS "holderEmail" TEXT;
ALTER TABLE "CvDownloadToken" ADD COLUMN IF NOT EXISTS "holderPhone" TEXT;

DO $body$ BEGIN
  ALTER TABLE "CvDownloadToken" ADD CONSTRAINT "CvDownloadToken_userId_fkey"
      FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $body$;

DO $body$ BEGIN
  ALTER TABLE "CvDownloadToken" ADD CONSTRAINT "CvDownloadToken_packageId_fkey"
      FOREIGN KEY ("packageId") REFERENCES "SellerPackage"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $body$;

CREATE INDEX IF NOT EXISTS "CvDownloadToken_packageId_userId_idx" ON "CvDownloadToken"("packageId", "userId");
CREATE INDEX IF NOT EXISTS "CvDownloadToken_packageId_deviceId_idx" ON "CvDownloadToken"("packageId", "deviceId");
