-- Cluster 1: timezone-aware daily visitor reset tracking
ALTER TABLE "SiteStat" ADD COLUMN IF NOT EXISTS "lastResetDayKey" TEXT NOT NULL DEFAULT '';

-- Cluster 2: clickable logo + inline-vs-replace display mode
ALTER TABLE "SiteConfig" ADD COLUMN IF NOT EXISTS "logoLinkUrl" TEXT;
ALTER TABLE "SiteConfig" ADD COLUMN IF NOT EXISTS "logoDisplayMode" TEXT;
