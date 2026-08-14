-- Extend CvDownloadToken for the CV download history feature:
--   deviceId   — client-generated id, used to rate-limit guest downloads
--   packageId  — the CV package that governed this download, if any
--   holder*    — a snapshot of the CV holder's details, captured at
--                download time, so the admin dashboard can show a history
--                of created CVs without needing to store (or re-derive)
--                the full builder form state.
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
