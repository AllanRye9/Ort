'use client';

/**
 * Best-effort, high-accuracy location for search/click analytics.
 *
 * This is deliberately non-blocking and never delays or fails the request
 * it's attached to: `readCachedLocation` is a synchronous, instant read of
 * whatever's already cached (nothing on the very first call of a session),
 * and `warmLocationCache` kicks off the browser's Geolocation API in the
 * background purely to have a fix ready for the *next* search/click. If the
 * visitor denies permission, the browser doesn't support geolocation, or no
 * fix arrives, callers simply proceed without location — the IP/country
 * signal recorded server-side is always there as a fallback.
 */

const GEO_CACHE_KEY = '3re_geo_position';
const GEO_CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes

interface CachedGeo {
  lat: number;
  lng: number;
  accuracy: number;
  fetchedAt: number;
}

export interface GeoPosition {
  lat: number;
  lng: number;
  accuracy: number;
}

function readCache(): CachedGeo | null {
  if (typeof window === 'undefined') return null;
  try {
    const raw = window.sessionStorage.getItem(GEO_CACHE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as CachedGeo;
    if (Date.now() - parsed.fetchedAt > GEO_CACHE_TTL_MS) return null;
    return parsed;
  } catch {
    return null;
  }
}

function writeCache(geo: CachedGeo) {
  try {
    window.sessionStorage.setItem(GEO_CACHE_KEY, JSON.stringify(geo));
  } catch {
    // sessionStorage may be unavailable (private mode, etc.) — fine, this
    // is best-effort enrichment only.
  }
}

/** Synchronous, instant read of whatever location is already cached from a
 *  previous successful geolocation fix this session. Never prompts, never
 *  blocks — returns null if nothing's cached yet or the cache has expired. */
export function readCachedLocation(): GeoPosition | null {
  const cached = readCache();
  if (!cached) return null;
  return { lat: cached.lat, lng: cached.lng, accuracy: cached.accuracy };
}

/**
 * Fire-and-forget: if geolocation is supported and nothing's cached yet,
 * asks the browser for the visitor's position (this is what triggers the
 * native permission prompt, if not already answered) and caches the result
 * for subsequent calls this session. Callers should invoke this once on
 * mount and not await it — it exists purely to warm the cache for the
 * *next* search/click, never to delay the current one.
 */
export function warmLocationCache(): void {
  if (typeof window === 'undefined' || !('geolocation' in navigator)) return;
  if (readCache()) return; // already warm

  navigator.geolocation.getCurrentPosition(
    (position) => {
      writeCache({
        lat: position.coords.latitude,
        lng: position.coords.longitude,
        accuracy: position.coords.accuracy,
        fetchedAt: Date.now(),
      });
    },
    () => {
      // Permission denied, unavailable, or timed out — fail silently.
      // Search/click logging still works, just without a precise location.
    },
    { enableHighAccuracy: true, timeout: 8000, maximumAge: GEO_CACHE_TTL_MS },
  );
}

/** Appends `lat`/`lng`/`locAccuracy` to `params` in place, only if a
 *  location is already cached — never blocks waiting for one. */
export function attachCachedLocation(params: URLSearchParams): void {
  const geo = readCachedLocation();
  if (!geo) return;
  params.set('lat', String(geo.lat));
  params.set('lng', String(geo.lng));
  params.set('locAccuracy', String(geo.accuracy));
}

/** Same as `attachCachedLocation`, for callers (e.g. axios `params` objects)
 *  that use a plain object instead of `URLSearchParams`. */
export function attachCachedLocationToParams(params: Record<string, string>): void {
  const geo = readCachedLocation();
  if (!geo) return;
  params.lat = String(geo.lat);
  params.lng = String(geo.lng);
  params.locAccuracy = String(geo.accuracy);
}
