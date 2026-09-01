# PiiTrade — Status Update (all sessions)

Supplements the original color-coded tracker. Covers everything changed across
this whole engagement, cross-referenced against the actual code in this zip —
not re-verifying every row of the original report.

Scope note: this zip contains only the files that were modified (18 files
total), not the full codebase. Copy them back into place at the matching paths.

---

## Moved to GREEN

| Doc | Item | What changed |
|---|---|---|
| Doc 1, Cluster 2 | Uganda-only restriction on `/listings/create` & `/admin/bulk-post` | Backend rejects any non-Uganda country on `POST /listings` (exact spec error message) and on both bulk-create endpoints. Frontend country selects locked to Uganda for new listings/rows on both pages. Editing a pre-existing non-Uganda listing still allows its original country. |
| Doc 1, Cluster 2 | Bulk-upload country validation | `validateBulkItems()` flags every offending row in one pass (e.g. "Invalid row(s): 2, 5, 7"). CSV import rejects non-Uganda rows explicitly instead of silently coercing to UAE. |
| Doc 1, Cluster 1 | Cart state transitions (sold/deleted/deactivated/expired/out-of-stock) | New `GET /listings/status?ids=...` endpoint. `CartContext` reconciles the cart on load and on tab focus — deleted listings are dropped automatically, sold/expired/hidden/rejected/out-of-stock listings are flagged. `/cart` shows an "unavailable" reason per item, disables quantity-increase, and blocks checkout until removed. |
| Doc 1, Cluster 1 | "+" add-to-cart icon coverage gap | Found and fixed two real holes: the homepage **Featured Deal** card (`FeaturedProductCard.tsx`) and **Flash Sales** card (`FlashDeals.tsx`) had no add-to-cart button. Both now have it with the same admin/owner/availability gating as `ListingCard`. |
| Doc 2, §5 | Mobile nav: Profile → Account, Home icon → "P" | `MobileBottomNav.tsx`: label renamed to "Account" (incl. the sign-in-redirect check); Home tab's house icon replaced with a bold "P" brand mark in the site orange, filled when active / outlined when inactive. Desktop nav untouched. |
| Doc 2, §3 | Redesigned transactional email templates | All 9 templates in `backend/src/utils/email.ts` rewritten on one shared branded design system (Piitrade orange header/footer, card-based content, table-based layout for client compatibility). No business-logic changes — verified all 9 signatures/subjects/call-sites match exactly. |
| Doc 1, Cluster 4 / Doc 2, §4 | KYC front/back vs. passport single-page dynamic upload | Added `kycDocumentBackUrl` to the `User` model (nullable, only populated for two-sided document types). `POST /kyc/submit` now requires a back-image for `NATIONAL_ID`/`DRIVERS_LICENSE` and rejects it for `PASSPORT`/`BUSINESS_LICENSE`. Admin KYC queue and review page show front/back separately. `/profile/verification` dynamically shows one upload field (passport/business license) or two (front/back), clears stale back-uploads when switching to a single-sided type, and shows a "Required for X" summary. |
| Doc 1, Cluster 5 | Mobile categories — 3 listings/row + swipe + arrows | New reusable `MobileCardCarousel.tsx`: 3-per-row horizontal scroll-snap + arrow navigation on mobile, collapsing to the existing responsive grid at `sm:` and above (one DOM tree, not two layouts to keep in sync). Wired into all 4 homepage sections: Flash Sales (`FlashDeals.tsx`), Recent Across Categories (`CountryRecentAcrossCategories.tsx`), Latest Collections (`CountryLatestCollections.tsx`), Featured Deal (`CountryFeaturedDeal.tsx`). |

### Email redesign detail (Doc 2 §3)
- Shared `emailShell()` / `emailLogoLockup()` / `emailButton()` / `emailCard()` design system.
- Branded header/footer using the site's actual orange (`#FF6500 → #F55906 → #E94B00`), consistent across every email — previously each template had its own ad-hoc blue/green/red/pink and a "Pi" placeholder mark.
- Logo mark is pure CSS/text (no `<img>`) — nothing to show as broken if images are blocked.
- Table-based layout throughout (the old header used `display:inline-flex`, which many Outlook builds ignore).
- Preheader text added to every template; card-based tinted content areas for statuses/warnings/reasons.
- **Not done**: live rendering tests in Gmail/Outlook/Apple Mail — no email client available in this environment. Recommend a manual send-test before production reliance.

### KYC front/back detail (Doc 1 Cluster 4 / Doc 2 §4)
- This is a schema change (`kycDocumentBackUrl` added to `User`). This repo has **no committed Prisma migrations** — it boots via `prisma db push` until the first real migration exists (see `backend/prisma/migrations/README.md`), so `schema.prisma` is the correct and only file to have changed; no separate migration SQL is needed for a fresh/dev database. **If a production database with existing data is already running**, this new nullable column is additive and safe to `db push`/deploy — no backfill needed since it defaults to `null`.

### Mobile carousel detail (Doc 1 Cluster 5)
- `MobileCardCarousel` takes an array of already-rendered card elements as children — it doesn't know or care what kind of card it's wrapping, so it works identically for `ListingCard`, the custom `FlashCard`, and `FeaturedProductCard`.
- Swipe works via native scroll + `scroll-snap-type`, not custom touch-event handling — arrow buttons call `scrollBy` and hide themselves at each end.
- **Not done**: visual QA on a real device/emulator — only reasoned through the CSS (flex+snap on mobile, `sm:grid` override at breakpoint). Worth a manual check before shipping, especially the arrow-hide logic at the scroll boundaries.

---

## Discrepancies found (tracker doesn't match this codebase — not new work)

- **Doc 2 §18** (KYC entry point on Account page): tracker marks this GAP. Already implemented — `/profile/page.tsx` has a compact "Get KYC Verified" banner reading live `kycStatus`. No changes made.
- Originally, the tracker also claimed Doc 1 Cluster 5 was GREEN via a "Session 2" `MobileCardCarousel.tsx` that didn't exist in this zip. That gap is now closed for real (see above) — but it's worth knowing the original GREEN claim was inaccurate before this session's work.

Treat any other "still open"/"GREEN" row in the original tracker as unverified until re-checked against this exact code — two rows checked, two didn't match.

---

## Still open / not started
- Doc 2 §6–§12, §16–§17, §19 and beyond (search intelligence, posting copy, exchange-logo branding, market-price cards, image preview, blog popup, slideshow indicators, store dashboard) — these were explicitly out of scope for the original color-coded pass ("not individually re-verified... not implied to be GAP or GREEN") and haven't been touched this engagement either.
