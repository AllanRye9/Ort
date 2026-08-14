-- Add geolocation fields to Listing for GPS coordinates
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "latitude" DOUBLE PRECISION;
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "longitude" DOUBLE PRECISION;
