-- Admin-configurable homepage blog popup: { enabled, intervalSeconds, postId }
-- stored as a JSON blob on the singleton SiteConfig row, following the same
-- convention as generalSettings/todaysDeals. Nullable — a missing value is
-- treated as "feature off" by the API (see GET /api/blog/popup).
ALTER TABLE "SiteConfig" ADD COLUMN "blogPopup" JSONB;
