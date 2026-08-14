-- Idempotent hotfix: seed the three standard marketplace listing packages.
-- Inserts 7-Day Free Trial, Monthly ($3), and Yearly ($18) packages if no
-- packages exist yet. Uses gen_random_uuid() so IDs are stable per DB instance.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM "SellerPackage" LIMIT 1) THEN
    INSERT INTO "SellerPackage" ("id", "name", "description", "isFree", "price", "currency", "durationDays", "maxListings", "isActive", "createdAt", "updatedAt")
    VALUES
      (gen_random_uuid()::text, '7-Day Free Trial',  'Post your first listing free for 7 days — no payment needed.', true,  0,  'USD', 7,   1,    true, NOW(), NOW()),
      (gen_random_uuid()::text, 'Monthly Plan',      'Keep your listings active for a full month.',                  false, 3,  'USD', 30,  NULL, true, NOW(), NOW()),
      (gen_random_uuid()::text, 'Yearly Plan',       'Best value — keep your listings active for a full year.',     false, 18, 'USD', 365, NULL, true, NOW(), NOW());
  END IF;
END $$;
