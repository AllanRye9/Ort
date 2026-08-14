-- Add visitorCountries column to SiteStat for tracking unique visitor countries
ALTER TABLE "SiteStat" ADD COLUMN IF NOT EXISTS "visitorCountries" TEXT NOT NULL DEFAULT '[]';
