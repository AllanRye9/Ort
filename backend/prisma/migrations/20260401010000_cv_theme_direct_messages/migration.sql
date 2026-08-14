-- Add cvThemeColor to User for per-candidate CV page theming
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "cvThemeColor" TEXT;

-- Make Message.listingId nullable to support direct CV-contact messages
ALTER TABLE "Message" ALTER COLUMN "listingId" DROP NOT NULL;
