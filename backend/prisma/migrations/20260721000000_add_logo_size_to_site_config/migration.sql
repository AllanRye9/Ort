-- Add admin-adjustable logo size (px) to SiteConfig
ALTER TABLE "SiteConfig" ADD COLUMN IF NOT EXISTS "logoSize" INTEGER;
