-- Track which CV package (if any) governed a given CV download token, and a
-- client-generated deviceId so guest (unauthenticated) downloads can also be
-- rate-limited against a package's "max generated CV" rule.

ALTER TABLE "CvDownloadToken" ADD COLUMN "deviceId" TEXT;
ALTER TABLE "CvDownloadToken" ADD COLUMN "packageId" TEXT;

DO $body$ BEGIN
  ALTER TABLE "CvDownloadToken" ADD CONSTRAINT "CvDownloadToken_packageId_fkey"
      FOREIGN KEY ("packageId") REFERENCES "SellerPackage"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $body$;

CREATE INDEX IF NOT EXISTS "CvDownloadToken_packageId_userId_idx" ON "CvDownloadToken"("packageId", "userId");
CREATE INDEX IF NOT EXISTS "CvDownloadToken_packageId_deviceId_idx" ON "CvDownloadToken"("packageId", "deviceId");
