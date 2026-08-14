-- Add customFieldValues JSON field to Listing — answers to the selected
-- category's admin-defined fieldSchema (see Category.fieldSchema, managed
-- under /admin/categories "Custom Fields"), keyed by field name, e.g.
-- {"engine_capacity":"2.0L"}.
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "customFieldValues" JSONB;
