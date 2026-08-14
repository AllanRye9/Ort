-- Idempotent hotfix: ensure UserDocument table and DocumentType enum exist.
-- These are created by the 20260325000000_add_user_documents migration.
-- This hotfix is a safety net for environments where that migration failed.

DO $$ BEGIN
  CREATE TYPE "DocumentType" AS ENUM ('CV', 'CERTIFICATE', 'PORTFOLIO', 'OTHER');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS "UserDocument" (
  "id"          TEXT         NOT NULL,
  "userId"      TEXT         NOT NULL,
  "type"        "DocumentType" NOT NULL DEFAULT 'OTHER',
  "title"       TEXT         NOT NULL,
  "description" TEXT,
  "fileUrl"     TEXT         NOT NULL,
  "fileName"    TEXT         NOT NULL,
  "fileSize"    INTEGER,
  "isPublic"    BOOLEAN      NOT NULL DEFAULT true,
  "createdAt"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "UserDocument_pkey" PRIMARY KEY ("id")
);

DO $$ BEGIN
  ALTER TABLE "UserDocument"
    ADD CONSTRAINT "UserDocument_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;
