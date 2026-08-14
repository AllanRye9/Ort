-- Add linkUrl column to SiteMedia so admins can assign a click-through URL to each uploaded image
ALTER TABLE "SiteMedia" ADD COLUMN IF NOT EXISTS "linkUrl" TEXT;
