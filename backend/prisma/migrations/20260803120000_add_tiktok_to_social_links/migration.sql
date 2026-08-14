-- Add TikTok URL field to SocialLinks (admin-configured social links shown in the footer)
ALTER TABLE "SocialLinks" ADD COLUMN IF NOT EXISTS "tiktok" TEXT;
