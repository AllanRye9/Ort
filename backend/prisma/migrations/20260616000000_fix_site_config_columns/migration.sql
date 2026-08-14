-- Add interview demo video columns to SiteConfig. These fields were added to
-- schema.prisma when the Interview Demo Video admin feature was built, but no
-- migration was ever generated for them, so the columns never existed in the
-- real database. Every query against SiteConfig (whatsapp number, header
-- theme, today's deals, logo, interview video) upserts the full row, so a
-- missing column here breaks saving/loading for the entire settings page,
-- not just the video.
ALTER TABLE "SiteConfig" ADD COLUMN IF NOT EXISTS "interviewDemoVideoUrl" TEXT;
ALTER TABLE "SiteConfig" ADD COLUMN IF NOT EXISTS "interviewDemoVideoTitle" TEXT;

-- Add generalSettings column so "General Settings" (site name, maintenance
-- mode, allow registration, default country, items per page, max images per
-- listing) persists to the database instead of living in an in-memory JS
-- variable that resets on every server restart/redeploy.
ALTER TABLE "SiteConfig" ADD COLUMN IF NOT EXISTS "generalSettings" JSONB;

-- Fix logoPages: it was migrated as TEXT in 20260615000000_add_logo_to_site_config,
-- but schema.prisma declares it as Json (jsonb). This type mismatch causes the
-- Prisma client to fail when reading/writing the logo's page list. Convert the
-- existing column in place; any current value is either NULL or a valid JSON
-- string, so the cast is safe and no data is lost.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'SiteConfig' AND column_name = 'logoPages' AND data_type <> 'jsonb'
  ) THEN
    ALTER TABLE "SiteConfig"
      ALTER COLUMN "logoPages" TYPE JSONB USING (
        CASE
          WHEN "logoPages" IS NULL OR "logoPages" = '' THEN NULL
          ELSE "logoPages"::jsonb
        END
      );
  END IF;
END $$;
