-- CreateTable
CREATE TABLE "SiteConfig" (
    "id" TEXT NOT NULL DEFAULT 'global',
    "whatsappNumber" TEXT,
    "todaysDeals" JSONB,
    "headerTheme" TEXT,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SiteConfig_pkey" PRIMARY KEY ("id")
);

-- Seed default row
INSERT INTO "SiteConfig" ("id", "updatedAt") VALUES ('global', NOW()) ON CONFLICT DO NOTHING;
