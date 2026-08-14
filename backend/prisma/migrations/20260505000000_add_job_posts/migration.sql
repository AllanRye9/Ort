-- CreateEnum
CREATE TYPE "JobStatus" AS ENUM ('ACTIVE', 'CLOSED', 'DRAFT');

-- CreateTable
CREATE TABLE IF NOT EXISTS "JobPost" (
    "id"            TEXT NOT NULL,
    "title"         TEXT NOT NULL,
    "company"       TEXT NOT NULL,
    "location"      TEXT NOT NULL DEFAULT '',
    "type"          TEXT NOT NULL,
    "category"      TEXT NOT NULL,
    "qualification" TEXT NOT NULL,
    "description"   TEXT NOT NULL,
    "salary"        TEXT,
    "deadline"      TEXT,
    "imageUrl"      TEXT,
    "country"       TEXT NOT NULL DEFAULT 'UAE',
    "status"        "JobStatus" NOT NULL DEFAULT 'ACTIVE',
    "postedById"    TEXT NOT NULL,
    "createdAt"     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "JobPost_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "JobPost_status_idx" ON "JobPost"("status");
CREATE INDEX IF NOT EXISTS "JobPost_country_idx" ON "JobPost"("country");
CREATE INDEX IF NOT EXISTS "JobPost_type_idx" ON "JobPost"("type");
CREATE INDEX IF NOT EXISTS "JobPost_category_idx" ON "JobPost"("category");
