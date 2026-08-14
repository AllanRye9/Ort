-- Add dailyVisitors and lastDailyReset to SiteStat
ALTER TABLE "SiteStat" ADD COLUMN IF NOT EXISTS "dailyVisitors" BIGINT NOT NULL DEFAULT 0;
ALTER TABLE "SiteStat" ADD COLUMN IF NOT EXISTS "lastDailyReset" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- Create BlogStatus enum
DO $$ BEGIN
  CREATE TYPE "BlogStatus" AS ENUM ('DRAFT', 'PUBLISHED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Create BlogPost table
CREATE TABLE IF NOT EXISTS "BlogPost" (
  "id"            TEXT NOT NULL,
  "title"         TEXT NOT NULL,
  "slug"          TEXT NOT NULL,
  "content"       TEXT NOT NULL,
  "excerpt"       TEXT,
  "featuredImage" TEXT,
  "status"        "BlogStatus" NOT NULL DEFAULT 'DRAFT',
  "authorId"      TEXT NOT NULL,
  "publishedAt"   TIMESTAMP(3),
  "createdAt"     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "BlogPost_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "BlogPost_authorId_fkey" FOREIGN KEY ("authorId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS "BlogPost_slug_key" ON "BlogPost"("slug");

-- Create SocialLinks table (singleton row)
CREATE TABLE IF NOT EXISTS "SocialLinks" (
  "id"        TEXT NOT NULL DEFAULT 'global',
  "facebook"  TEXT,
  "instagram" TEXT,
  "linkedin"  TEXT,
  "x"         TEXT,
  "whatsapp"  TEXT,
  "youtube"   TEXT,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "SocialLinks_pkey" PRIMARY KEY ("id")
);

-- Create RentalStatus enum
DO $$ BEGIN
  CREATE TYPE "RentalStatus" AS ENUM ('PENDING', 'ACTIVE', 'EXPIRED', 'CANCELLED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Create RentalEntityType enum
DO $$ BEGIN
  CREATE TYPE "RentalEntityType" AS ENUM ('USER', 'AGENT', 'COMPANY', 'ORGANIZATION');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Create StoreRental table
CREATE TABLE IF NOT EXISTS "StoreRental" (
  "id"          TEXT NOT NULL,
  "userId"      TEXT NOT NULL,
  "entityType"  "RentalEntityType" NOT NULL DEFAULT 'USER',
  "fee"         DOUBLE PRECISION NOT NULL DEFAULT 0,
  "currency"    "Currency" NOT NULL DEFAULT 'AED',
  "startDate"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "endDate"     TIMESTAMP(3) NOT NULL,
  "maxListings" INTEGER NOT NULL DEFAULT 100,
  "status"      "RentalStatus" NOT NULL DEFAULT 'PENDING',
  "placements"  JSONB,
  "createdAt"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "StoreRental_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "StoreRental_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
