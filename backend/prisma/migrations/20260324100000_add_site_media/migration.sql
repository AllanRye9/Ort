-- CreateTable
CREATE TABLE IF NOT EXISTS "SiteMedia" (
    "id" TEXT NOT NULL,
    "section" TEXT NOT NULL,
    "cdnUrl" TEXT NOT NULL,
    "altText" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "uploadedBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SiteMedia_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
DO $body$ BEGIN
  ALTER TABLE "SiteMedia" ADD CONSTRAINT "SiteMedia_uploadedBy_fkey" FOREIGN KEY ("uploadedBy") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $body$;
