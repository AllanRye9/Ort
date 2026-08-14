'use client';
/**
 * TrackPageView — invisible client component that fires a best-effort
 * POST /api/stats/track on every homepage render so the page-view counter
 * is incremented in the database.  Also detects the visitor's country via
 * a lightweight geolocation API and sends it so new countries are recorded.
 */
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';

const COUNTRY_CACHE_KEY = '3re_visitor_country';
const DEVICE_ID_KEY = '3re_device_id';

function generateDeviceId(): string {
  // Simple UUID v4-like generator
  return 'device_' + Math.random().toString(36).substring(2, 11) + '_' + Date.now().toString(36);
}

function getOrCreateDeviceId(): string {
  if (typeof window === 'undefined') return '';
  
  try {
    let deviceId = localStorage.getItem(DEVICE_ID_KEY);
    if (!deviceId) {
      deviceId = generateDeviceId();
      localStorage.setItem(DEVICE_ID_KEY, deviceId);
    }
    return deviceId;
  } catch {
    // localStorage may not be available
    return generateDeviceId();
  }
}
async function detectCountry(): Promise<string | null> {
  // Check localStorage cache first so we only call the API once per browser
  try {
    const cached = localStorage.getItem(COUNTRY_CACHE_KEY);
    if (cached) return cached;
  } catch {
    // localStorage may not be available
  }

  try {
    const res = await fetch('https://api.country.is/', { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return null;
    const data = await res.json();
    const country = data?.country as string | undefined;
    if (country && /^[A-Z]{2}$/.test(country)) {
      try { localStorage.setItem(COUNTRY_CACHE_KEY, country); } catch { /* ignore */ }
      return country;
    }
  } catch {
    // Best-effort — silently fail if geolocation is unavailable
  }
  return null;
}

export default function TrackPageView() {
    const [deviceId] = useState(() => getOrCreateDeviceId());

  useEffect(() => {
    detectCountry().then((country) => {
      api.post('/stats/track', { deviceId, country })
        .catch((err) => {
          if (process.env.NODE_ENV === 'development') {
            console.warn('Page view tracking failed:', err);
          }
        });
    });
  }, [deviceId]);
  return null;
}
