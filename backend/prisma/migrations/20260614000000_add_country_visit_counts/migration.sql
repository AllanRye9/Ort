-- Add countryVisitCounts field to SiteStat to track per-country visit counts (JSON map: {"US": 42, "AE": 15})
ALTER TABLE "SiteStat" ADD COLUMN IF NOT EXISTS "countryVisitCounts" TEXT NOT NULL DEFAULT '{}';
