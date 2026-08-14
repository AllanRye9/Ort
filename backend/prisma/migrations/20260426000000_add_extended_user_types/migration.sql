-- Add AGENT, ORGANIZATION, COMPANY to the Role enum
ALTER TYPE "Role" ADD VALUE IF NOT EXISTS 'AGENT';
ALTER TYPE "Role" ADD VALUE IF NOT EXISTS 'ORGANIZATION';
ALTER TYPE "Role" ADD VALUE IF NOT EXISTS 'COMPANY';

-- Add extended profile fields to User for the new account types
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "companyName"         TEXT;
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "registrationNumber"  TEXT;
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "agentLicense"        TEXT;
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "agentType"           TEXT;
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "website"             TEXT;
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "businessDescription" TEXT;
