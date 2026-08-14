-- AlterTable
ALTER TABLE "SiteStat" ADD COLUMN "uniqueVisitorIds" TEXT NOT NULL DEFAULT '[]',
ADD COLUMN "dailyVisitorIds" TEXT NOT NULL DEFAULT '[]';
