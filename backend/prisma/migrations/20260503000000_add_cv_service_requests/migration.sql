-- Create CvServiceRequest table
CREATE TABLE IF NOT EXISTS "CvServiceRequest" (
  "id"          TEXT NOT NULL,
  "serviceType" TEXT NOT NULL,
  "name"        TEXT NOT NULL,
  "email"       TEXT NOT NULL,
  "phone"       TEXT,
  "linkedinUrl" TEXT,
  "jobTitle"    TEXT,
  "goal"        TEXT,
  "message"     TEXT,
  "packageName" TEXT,
  "status"      TEXT NOT NULL DEFAULT 'pending',
  "createdAt"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "CvServiceRequest_pkey" PRIMARY KEY ("id")
);
