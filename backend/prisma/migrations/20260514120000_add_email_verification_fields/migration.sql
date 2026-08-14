-- Add dedicated email verification fields to User
ALTER TABLE "User"
  ADD COLUMN IF NOT EXISTS "emailVerificationToken" TEXT,
  ADD COLUMN IF NOT EXISTS "emailVerificationExpiry" TIMESTAMP(3);

-- Keep one active verification token per user and prevent accidental duplicates
CREATE UNIQUE INDEX IF NOT EXISTS "User_emailVerificationToken_key"
  ON "User" ("emailVerificationToken");
