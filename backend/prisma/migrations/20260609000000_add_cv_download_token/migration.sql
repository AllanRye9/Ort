-- CreateTable: CvDownloadToken
CREATE TABLE "CvDownloadToken" (
    "id"        TEXT NOT NULL,
    "userId"    TEXT,
    "tokenHash" TEXT NOT NULL,
    "paid"      BOOLEAN NOT NULL DEFAULT false,
    "amount"    DECIMAL NOT NULL,
    "currency"  TEXT NOT NULL,
    "country"   TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "usedAt"    TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "CvDownloadToken_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "CvDownloadToken_tokenHash_key" ON "CvDownloadToken"("tokenHash");
