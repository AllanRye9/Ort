-- Add richer metadata fields for section media cards (featured/flash/collection).
ALTER TABLE "SiteMedia"
ADD COLUMN "title" TEXT,
ADD COLUMN "shortDescription" TEXT,
ADD COLUMN "price" DECIMAL(65,30),
ADD COLUMN "originalPrice" DECIMAL(65,30),
ADD COLUMN "currency" "Currency";
