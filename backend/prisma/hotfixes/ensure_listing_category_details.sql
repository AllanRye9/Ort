-- Ensure propertyDetails and jobDetails columns exist on Listing
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "propertyDetails" JSONB;
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "jobDetails" JSONB;

-- Ensure fieldSchema column exists on Category
ALTER TABLE "Category" ADD COLUMN IF NOT EXISTS "fieldSchema" JSONB;

-- Ensure customFieldValues column exists on Listing — answers to the
-- selected category's admin-defined fieldSchema (see /admin/categories
-- "Custom Fields"), keyed by field name.
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "customFieldValues" JSONB;
