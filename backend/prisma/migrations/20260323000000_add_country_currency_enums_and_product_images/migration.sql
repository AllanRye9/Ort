-- AlterEnum: add KENYA and CHINA to Country
ALTER TYPE "Country" ADD VALUE IF NOT EXISTS 'KENYA';
ALTER TYPE "Country" ADD VALUE IF NOT EXISTS 'CHINA';

-- AlterEnum: add KES and CNY to Currency
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'KES';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'CNY';

-- CreateEnum
DO $$ BEGIN
    CREATE TYPE "ImageStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- CreateTable
CREATE TABLE IF NOT EXISTS "ProductImage" (
    "id" TEXT NOT NULL,
    "listingId" TEXT,
    "sellerId" TEXT NOT NULL,
    "tempPath" TEXT NOT NULL,
    "status" "ImageStatus" NOT NULL DEFAULT 'PENDING',
    "cdnUrl" TEXT,
    "uploadedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reviewedAt" TIMESTAMP(3),
    "reviewedBy" TEXT,
    "rejectionReason" TEXT,

    CONSTRAINT "ProductImage_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
DO $$ BEGIN
    ALTER TABLE "ProductImage" ADD CONSTRAINT "ProductImage_listingId_fkey"
        FOREIGN KEY ("listingId") REFERENCES "Listing"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- AddForeignKey
DO $$ BEGIN
    ALTER TABLE "ProductImage" ADD CONSTRAINT "ProductImage_sellerId_fkey"
        FOREIGN KEY ("sellerId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;
