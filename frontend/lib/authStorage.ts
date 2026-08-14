/**
 * authStorage.ts
 *
 * Persists the access token in localStorage so users remain logged in
 * across page refreshes, new tabs, and browser restarts. The refresh token
 * is no longer stored here — the backend sets it as an httpOnly cookie
 * (see backend/src/utils/authCookies.ts), so frontend JS never has access
 * to it and it survives a browser restart on its own via the cookie.
 *
 * Migration: on first load, any tokens still in sessionStorage (legacy) are
 * moved to localStorage, and any leftover refreshToken value from before
 * this change is deleted from both storages — it's no longer read or
 * written anywhere, so there's no reason to keep it sitting in localStorage
 * where a future XSS bug could read it.
 */

const ACCESS_TOKEN_KEY      = 'accessToken';
const LEGACY_REFRESH_TOKEN_KEY = 'refreshToken';
const LAST_ACTIVITY_AT_KEY  = 'auth:lastActivityAt';

// Throttle activity-timestamp writes to at most once per minute.
const ACTIVITY_WRITE_INTERVAL_MS = 60_000;

function hasWindow(): boolean {
  return typeof window !== 'undefined';
}

/** Returns the persistent localStorage, or null in SSR. */
function getPersistentStorage(): Storage | null {
  try {
    return hasWindow() ? window.localStorage : null;
  } catch {
    // localStorage blocked by privacy settings
    return null;
  }
}

/**
 * migrateLegacyAuthSession
 * Copies any access token still in sessionStorage into localStorage so
 * existing sessions survive the upgrade from the old sessionStorage-based
 * storage, and removes any leftover refreshToken value (from before the
 * refresh token moved to an httpOnly cookie) from both storages.
 */
export function migrateLegacyAuthSession(): void {
  const persistent = getPersistentStorage();
  if (!persistent) return;

  try {
    const session = hasWindow() ? window.sessionStorage : null;
    if (session) {
      for (const key of [ACCESS_TOKEN_KEY, LAST_ACTIVITY_AT_KEY]) {
        const value = session.getItem(key);
        if (value && !persistent.getItem(key)) {
          persistent.setItem(key, value);
        }
        session.removeItem(key);
      }
      session.removeItem(LEGACY_REFRESH_TOKEN_KEY);
    }
  } catch {
    // sessionStorage may be blocked in strict privacy contexts — safe to skip
  }

  // No longer read or written anywhere — drop it if an older session left
  // one behind.
  persistent.removeItem(LEGACY_REFRESH_TOKEN_KEY);
}

export function getAccessToken(): string | null {
  return getPersistentStorage()?.getItem(ACCESS_TOKEN_KEY) ?? null;
}

export function hasStoredAuthSession(): boolean {
  return Boolean(getAccessToken());
}

export function getLastActivityAt(): number | null {
  const value = getPersistentStorage()?.getItem(LAST_ACTIVITY_AT_KEY);
  return value ? Number(value) : null;
}

/**
 * Sessions never expire automatically — they live until explicit logout.
 * Kept for API compatibility.
 */
export function isAuthSessionExpired(): boolean {
  return false;
}

export function getRemainingAuthSessionTime(): number {
  return Number.MAX_SAFE_INTEGER;
}

/** Update the last-activity timestamp (throttled to once per minute). */
export function touchAuthActivity(force = false): void {
  const storage = getPersistentStorage();
  if (!storage || !hasStoredAuthSession()) return;

  const now          = Date.now();
  const lastActivity = getLastActivityAt() ?? 0;
  if (!force && now - lastActivity < ACTIVITY_WRITE_INTERVAL_MS) return;

  storage.setItem(LAST_ACTIVITY_AT_KEY, String(now));
}

/**
 * Persist a new auth session after login/refresh. The refresh token is set
 * separately by the backend as an httpOnly cookie — only the access token
 * is stored here.
 */
export function setAuthSession(accessToken: string): void {
  const storage = getPersistentStorage();
  if (!storage) return;

  storage.setItem(ACCESS_TOKEN_KEY,     accessToken);
  storage.setItem(LAST_ACTIVITY_AT_KEY, String(Date.now()));
}

/** Remove the auth session on explicit logout. */
export function clearAuthSession(): void {
  const storage = getPersistentStorage();
  if (!storage) return;

  storage.removeItem(ACCESS_TOKEN_KEY);
  storage.removeItem(LAST_ACTIVITY_AT_KEY);
  storage.removeItem(LEGACY_REFRESH_TOKEN_KEY);

  // Also clean any sessionStorage remnants
  try {
    if (hasWindow()) {
      window.sessionStorage.removeItem(ACCESS_TOKEN_KEY);
      window.sessionStorage.removeItem(LEGACY_REFRESH_TOKEN_KEY);
      window.sessionStorage.removeItem(LAST_ACTIVITY_AT_KEY);
    }
  } catch {
    // ignore
  }
}

