-- Create enum for package domain scoping
CREATE TYPE "PackageScope" AS ENUM ('LISTING', 'CV');

-- Scope all existing packages to listing workflows by default
ALTER TABLE "SellerPackage"
ADD COLUMN "scope" "PackageScope" NOT NULL DEFAULT 'LISTING';
