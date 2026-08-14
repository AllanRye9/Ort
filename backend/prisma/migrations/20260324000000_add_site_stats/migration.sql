-- Add SiteStat table for tracking global page-view counter.
CREATE TABLE IF NOT EXISTS "SiteStat" (
    "id"        TEXT NOT NULL DEFAULT 'global',
    "pageViews" BIGINT NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "SiteStat_pkey" PRIMARY KEY ("id")
);

-- Seed the single global row so increments don't need an initial INSERT.
INSERT INTO "SiteStat" ("id", "pageViews", "updatedAt")
VALUES ('global', 0, NOW())
ON CONFLICT ("id") DO NOTHING;
