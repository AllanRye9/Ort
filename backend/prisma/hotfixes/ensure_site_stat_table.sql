-- Idempotent hotfix: ensure SiteStat table exists (page-view/visitor tracking)
-- and has every column schema.prisma expects, even if migration history in
-- this environment is out of sync with the migrations folder.
CREATE TABLE IF NOT EXISTS "SiteStat" (
    "id"        TEXT NOT NULL DEFAULT 'global',
    "pageViews" BIGINT NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT NOW(),
    CONSTRAINT "SiteStat_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "SiteStat" ADD COLUMN IF NOT EXISTS "dailyVisitors" BIGINT NOT NULL DEFAULT 0;
ALTER TABLE "SiteStat" ADD COLUMN IF NOT EXISTS "lastDailyReset" TIMESTAMP(3) NOT NULL DEFAULT NOW();
ALTER TABLE "SiteStat" ADD COLUMN IF NOT EXISTS "lastResetDayKey" TEXT NOT NULL DEFAULT '';
ALTER TABLE "SiteStat" ADD COLUMN IF NOT EXISTS "visitorCountries" TEXT NOT NULL DEFAULT '[]';
ALTER TABLE "SiteStat" ADD COLUMN IF NOT EXISTS "countryVisitCounts" TEXT NOT NULL DEFAULT '{}';
ALTER TABLE "SiteStat" ADD COLUMN IF NOT EXISTS "uniqueVisitorIds" TEXT NOT NULL DEFAULT '[]';
ALTER TABLE "SiteStat" ADD COLUMN IF NOT EXISTS "dailyVisitorIds" TEXT NOT NULL DEFAULT '[]';

INSERT INTO "SiteStat" ("id", "pageViews", "updatedAt")
VALUES ('global', 0, NOW())
ON CONFLICT ("id") DO NOTHING;
