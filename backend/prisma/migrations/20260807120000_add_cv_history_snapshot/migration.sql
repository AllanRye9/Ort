-- Snapshot of the CV holder's core details at the moment a download was
-- initiated (free or paid), so the admin dashboard can show a history of
-- created CVs without needing the full builder form state.

ALTER TABLE "CvDownloadToken" ADD COLUMN "holderName" TEXT;
ALTER TABLE "CvDownloadToken" ADD COLUMN "holderTitle" TEXT;
ALTER TABLE "CvDownloadToken" ADD COLUMN "holderEmail" TEXT;
ALTER TABLE "CvDownloadToken" ADD COLUMN "holderPhone" TEXT;
