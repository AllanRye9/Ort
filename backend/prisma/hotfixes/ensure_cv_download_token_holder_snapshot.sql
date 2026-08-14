-- Idempotent hotfix: ensure CvDownloadToken has the holder snapshot columns.
-- These are created by the 20260807120000_add_cv_history_snapshot migration.
-- This hotfix is a safety net for environments where that migration failed partway.

ALTER TABLE "CvDownloadToken" ADD COLUMN IF NOT EXISTS "holderName" TEXT;
ALTER TABLE "CvDownloadToken" ADD COLUMN IF NOT EXISTS "holderTitle" TEXT;
ALTER TABLE "CvDownloadToken" ADD COLUMN IF NOT EXISTS "holderEmail" TEXT;
ALTER TABLE "CvDownloadToken" ADD COLUMN IF NOT EXISTS "holderPhone" TEXT;
