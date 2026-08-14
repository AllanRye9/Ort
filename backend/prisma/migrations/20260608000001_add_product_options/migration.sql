-- Add productOptions to Listing
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "productOptions" JSONB;

-- Add variantSummary to OrderItem
ALTER TABLE "OrderItem" ADD COLUMN IF NOT EXISTS "variantSummary" TEXT;
