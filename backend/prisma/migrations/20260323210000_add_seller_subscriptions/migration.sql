-- Add seller packages, subscriptions, and related enum values.
-- Adds: SubscriptionStatus enum, SellerPackage model, SellerSubscription model
-- Also adds SUBSCRIPTION_ACTIVATED and SUBSCRIPTION_EXPIRED values to NotificationType.

-- SubscriptionStatus enum
DO $$ BEGIN
  CREATE TYPE "SubscriptionStatus" AS ENUM ('ACTIVE', 'EXPIRED', 'CANCELLED', 'PENDING_PAYMENT');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Extend NotificationType with subscription events
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'SUBSCRIPTION_ACTIVATED';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'SUBSCRIPTION_EXPIRED';

-- SellerPackage model
CREATE TABLE IF NOT EXISTS "SellerPackage" (
    "id"           TEXT NOT NULL,
    "name"         TEXT NOT NULL,
    "description"  TEXT,
    "isFree"       BOOLEAN NOT NULL DEFAULT false,
    "price"        DOUBLE PRECISION NOT NULL DEFAULT 0,
    "currency"     "Currency" NOT NULL DEFAULT 'AED',
    "durationDays" INTEGER NOT NULL,
    "maxListings"  INTEGER,
    "isActive"     BOOLEAN NOT NULL DEFAULT true,
    "createdAt"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"    TIMESTAMP(3) NOT NULL,
    CONSTRAINT "SellerPackage_pkey" PRIMARY KEY ("id")
);

-- SellerSubscription model
CREATE TABLE IF NOT EXISTS "SellerSubscription" (
    "id"         TEXT NOT NULL,
    "userId"     TEXT NOT NULL,
    "packageId"  TEXT NOT NULL,
    "status"     "SubscriptionStatus" NOT NULL DEFAULT 'ACTIVE',
    "startDate"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endDate"    TIMESTAMP(3) NOT NULL,
    "paymentRef" TEXT,
    "createdAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"  TIMESTAMP(3) NOT NULL,
    CONSTRAINT "SellerSubscription_pkey" PRIMARY KEY ("id")
);
-- NOTE: "ALTER TABLE ... ADD CONSTRAINT IF NOT EXISTS" is not valid PostgreSQL
-- syntax (unlike "ADD COLUMN IF NOT EXISTS", which is supported). The
-- idiomatic idempotent pattern is a DO block that swallows the
-- "duplicate_object" error, matching the enum guard above.
DO $$ BEGIN
  ALTER TABLE "SellerSubscription" ADD CONSTRAINT "SellerSubscription_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  ALTER TABLE "SellerSubscription" ADD CONSTRAINT "SellerSubscription_packageId_fkey"
    FOREIGN KEY ("packageId") REFERENCES "SellerPackage"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;
