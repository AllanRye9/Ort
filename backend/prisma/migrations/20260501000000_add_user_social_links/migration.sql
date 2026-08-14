-- Add socialLinks JSONB column to User table for storing per-user social media links
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "socialLinks" JSONB;
