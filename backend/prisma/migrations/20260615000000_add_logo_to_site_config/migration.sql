-- Add logo and logoPages fields to SiteConfig
ALTER TABLE "SiteConfig" ADD COLUMN IF NOT EXISTS "logoUrl" TEXT;
ALTER TABLE "SiteConfig" ADD COLUMN IF NOT EXISTS "logoPages" TEXT; -- JSON array of page keys
ALTER TABLE "SiteConfig" ADD COLUMN IF NOT EXISTS "logoAltText" TEXT;
