# Summary of changes

## 1. Mobile 3-per-row layout
- `frontend/components/ui/CountryRecentAcrossCategories.tsx` — replaced the
  plain 2-column CSS grid with the shared `MobileCardCarousel` component
  (same pattern already used by Flash Deals, Latest Collections, Featured
  Deal).
- `frontend/app/page.tsx` — the "Latest Collections" 3-image promo strip was
  `grid-cols-2` on mobile; changed to `grid-cols-3` with adjusted image
  heights/`sizes` for legibility at the smaller width.

## 2. Language switcher
- `frontend/components/ui/LocaleSwitcher.tsx` — root cause: routing is
  configured as `no-prefix` (see `intlayer.config.ts`), so every locale
  resolves to the *same* URL. The old `onChange: 'push'` therefore navigated
  to an identical URL, which Next.js treats as a no-op — server components
  (which read the locale via `getLocale()` in `app/layout.tsx`) never
  re-rendered. Fixed by setting `onChange: 'none'` and calling
  `router.refresh()` in `onLocaleChange`, which re-fetches the current
  route's server-rendered content after the locale cookie is set.
- The previously-reported `MobileBottomNav.tsx` content-key mismatch turned
  out to be a false alarm — the code was already correct. The `tsc` error
  was coming from a **stale `.intlayer` build cache** left over from a
  different machine/path. No source change was needed there; deleting
  `.intlayer` and rebuilding dictionaries resolves it (this happens
  automatically on a fresh `npm install` + first build/dev run).

## 3. Homepage blog popup (new feature)
Admin-configurable popup that shows a blog post on the homepage.

**Backend:**
- `backend/prisma/schema.prisma` — added `SiteConfig.blogPopup Json?`
  (`{ enabled, intervalSeconds, postId }`).
- `backend/prisma/migrations/20260906120000_blog_popup_config/migration.sql`
  — hand-written migration adding the column (Prisma client generation is
  blocked in the sandbox this was built in — `binaries.prisma.sh` returns
  403 — so this was written to match the existing migration/schema
  conventions and verified via `tsc` diffing rather than `prisma generate`).
- `backend/src/routes/admin.ts` — `GET/PUT /admin/site-config/blog-popup`
  (validates `intervalSeconds >= 10`, `postId` must reference a real post).
- `backend/src/routes/blog.ts` — `GET /api/blog/popup`, the public
  resolution endpoint: returns `{ enabled: false }` if the feature is off or
  no published post exists; otherwise resolves the pinned `postId` (if still
  `PUBLISHED`) or falls back to the most recently published post.

**Frontend:**
- `frontend/components/admin/BlogPopupSettings.tsx` (new) — admin panel:
  on/off toggle, interval-in-seconds input, and a post picker defaulting to
  "Most recently published". Wired into `/admin/settings` under a new
  "Homepage Blog Popup" section.
- `frontend/components/ui/BlogPopup.tsx` (new) — the public popup. Fetches
  `/api/blog/popup` once on mount; if enabled, shows the post
  `intervalSeconds` after mount, and again `intervalSeconds` after each time
  it's dismissed (a repeating reminder, not a one-per-visit interruption).
- `frontend/app/page.tsx` — mounts `<BlogPopup />` on the homepage only.

## Verification performed
- Full `npm install` + `tsc --noEmit` on both frontend and backend (backend
  Prisma client is a stub in this sandbox due to the network restriction
  noted above — verified no *new* error categories were introduced by
  diffing the error list line-by-line against the pre-existing stub-client
  noise).
- `next build` (full production build) — all 96 routes, including `/` and
  `/admin/settings`, build successfully.
- `eslint` on all changed/new files — clean.
