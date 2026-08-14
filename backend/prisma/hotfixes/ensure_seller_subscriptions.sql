-- Idempotent hotfix: ensure SellerPackage and SellerSubscription tables exist.
-- These tables are created by the 20260323210000_add_seller_subscriptions migration.
-- This hotfix is a safety net for environments where that migration failed partway.

DO $$ BEGIN
  CREATE TYPE "SubscriptionStatus" AS ENUM ('ACTIVE', 'EXPIRED', 'CANCELLED', 'PENDING_PAYMENT');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'SUBSCRIPTION_ACTIVATED';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'SUBSCRIPTION_EXPIRED';

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
    "updatedAt"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "SellerPackage_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "SellerSubscription" (
    "id"         TEXT NOT NULL,
    "userId"     TEXT NOT NULL,
    "packageId"  TEXT NOT NULL,
    "status"     "SubscriptionStatus" NOT NULL DEFAULT 'ACTIVE',
    "startDate"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endDate"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "paymentRef" TEXT,
    "createdAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "SellerSubscription_pkey" PRIMARY KEY ("id")
);

DO $body$ BEGIN
  ALTER TABLE "SellerSubscription" ADD CONSTRAINT "SellerSubscription_userId_fkey"
      FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $body$;

DO $body$ BEGIN
  ALTER TABLE "SellerSubscription" ADD CONSTRAINT "SellerSubscription_packageId_fkey"
      FOREIGN KEY ("packageId") REFERENCES "SellerPackage"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $body$;
