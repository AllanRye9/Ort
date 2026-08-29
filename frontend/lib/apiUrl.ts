// TRUE single source of truth for the backend base URL — safe to import from
// both Server Components and Client Components.
//
// This lives in its own file, deliberately with NO other imports, because
// lib/api.ts (the axios client) pulls in lib/sessionRefreshScheduler.ts,
// which is a 'use client' module that calls registerProactiveRefresh() at
// module top-level. That's fine when lib/api.ts is only ever bundled into
// client code, but Server Components that only need the base URL (e.g. for
// a plain `fetch` during SSR/static generation) must NOT import lib/api.ts —
// doing so pulls the client-only session-refresh machinery into the server
// bundle and fails the build with:
//   "Attempted to call registerProactiveRefresh() from the server but
//    registerProactiveRefresh is on the client."
//
// Server Components: `import { API_URL } from '@/lib/apiUrl'`
// Client Components / anything using the shared axios instance:
//   `import { API_URL, api } from '@/lib/api'` (api.ts re-exports API_URL
//   from here, so existing client imports don't need to change).

// Strip trailing slashes so that template literals like `${API_URL}/api`
// never produce a double-slash (e.g. "https://example.com//api").
const configuredApiUrl = process.env.NEXT_PUBLIC_API_URL || '';
const normalizedConfiguredApiUrl = configuredApiUrl.replace(/\/+$/, '');

// Previously several files each hardcoded their own fallback
// (`|| 'http://localhost:5000'`, `|| ''`, or a
// `window.location.hostname === 'piitrade.com'` special case), and they
// disagreed in production: when NEXT_PUBLIC_API_URL wasn't baked into the
// build, some calls silently fell back to a same-origin relative URL (which
// returned Next.js's own generic 404 for paths like /api/site-media,
// /api/stats/public, /api/categories/active-counts, and
// /api/public/site-config), and others tried an unreachable localhost. Both
// failure modes looked identical to a "missing backend route" and were hard
// to diagnose. Now there is exactly one fallback path, and it fails loudly
// instead of silently.
function resolveApiUrl(): string {
  if (normalizedConfiguredApiUrl) {
    return normalizedConfiguredApiUrl;
  }

  // NEXT_PUBLIC_* vars are inlined at BUILD time, not read at runtime, so
  // setting this in the hosting provider's dashboard after the image was
  // built has no effect — it must be present when `next build` runs.
  if (typeof window !== 'undefined') {
    // eslint-disable-next-line no-console
    console.error(
      '[api] NEXT_PUBLIC_API_URL is not set. Falling back to http://localhost:5000, ' +
        'which is almost certainly wrong outside local development — API calls will fail. ' +
        'Set NEXT_PUBLIC_API_URL to the deployed backend URL and rebuild the frontend.'
    );
    return 'http://localhost:5000';
  }

  // Server-side (SSR/server components/build-time fetches): safe default for
  // local docker-compose, where the backend service is reachable by its
  // compose service name.
  return 'http://backend:5000';
}

export const API_URL = resolveApiUrl();
