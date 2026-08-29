import { Request } from 'express';

/**
 * Extracts the client's IP address, honoring the X-Forwarded-For chain set
 * up via `app.set('trust proxy', 1)` in app.ts. Falls back to the raw
 * socket address, then 'unknown' if neither is available (e.g. in tests).
 *
 * This mirrors the identical helper already used for visitor logging in
 * routes/stats.ts — kept here as a shared, reusable copy so the new
 * search/click analytics logging (routes/listings.ts, routes/admin.ts)
 * doesn't need to import across route files.
 */
export function getClientIp(req: Request): string {
  return req.ip || req.socket?.remoteAddress || 'unknown';
}

/**
 * Country code detected from the CDN/edge header (e.g. Cloudflare's
 * cf-ipcountry) — the same always-available, coarse location signal
 * already used for visitor-log country detection in routes/stats.ts.
 * Returns undefined when the header isn't present (e.g. local
 * development, or a CDN that doesn't set it).
 */
export function getIpCountry(req: Request): string | undefined {
  const header = req.headers['cf-ipcountry'];
  const value = Array.isArray(header) ? header[0] : header;
  return value ? value.toUpperCase() : undefined;
}

export interface RequestGeo {
  latitude: number | null;
  longitude: number | null;
  accuracy: number | null;
}

/**
 * Best-effort, high-accuracy geolocation supplied by the frontend as
 * `lat` / `lng` / `locAccuracy` query params (see frontend/lib/geolocation.ts),
 * only ever sent once the browser's Geolocation API has granted permission
 * and returned a fix. Always optional enrichment on top of `getIpCountry`
 * above — never required, and validated here so a malformed/out-of-range
 * value never reaches the database.
 */
export function getRequestGeo(req: Request): RequestGeo {
  const lat = parseFloat((req.query.lat as string) ?? '');
  const lng = parseFloat((req.query.lng as string) ?? '');
  const acc = parseFloat((req.query.locAccuracy as string) ?? '');

  return {
    latitude: Number.isFinite(lat) && lat >= -90 && lat <= 90 ? lat : null,
    longitude: Number.isFinite(lng) && lng >= -180 && lng <= 180 ? lng : null,
    accuracy: Number.isFinite(acc) && acc >= 0 ? acc : null,
  };
}
