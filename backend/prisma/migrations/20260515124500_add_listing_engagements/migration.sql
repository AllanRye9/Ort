-- Track dwell time and other listing engagement signals for recommendations
CREATE TABLE "ListingEngagement" (
    "id" TEXT NOT NULL,
    "durationSeconds" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "userId" TEXT,
    "listingId" TEXT NOT NULL,

    CONSTRAINT "ListingEngagement_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ListingEngagement_userId_createdAt_idx" ON "ListingEngagement"("userId", "createdAt");
CREATE INDEX "ListingEngagement_listingId_createdAt_idx" ON "ListingEngagement"("listingId", "createdAt");

ALTER TABLE "ListingEngagement"
ADD CONSTRAINT "ListingEngagement_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "ListingEngagement"
ADD CONSTRAINT "ListingEngagement_listingId_fkey"
FOREIGN KEY ("listingId") REFERENCES "Listing"("id") ON DELETE CASCADE ON UPDATE CASCADE;
