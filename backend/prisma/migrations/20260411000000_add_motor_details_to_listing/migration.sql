-- Add motorDetails JSON field to Listing for vehicle-specific attributes
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "motorDetails" JSONB;
