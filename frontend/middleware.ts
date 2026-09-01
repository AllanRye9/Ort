import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { intlayerMiddleware, multipleMiddlewares } from 'next-intlayer/middleware';

const VALID = {
  AE: 'UAE',
  UG: 'UGANDA',
  KE: 'KENYA',
  CN: 'CHINA',
} as const;

const COUNTRY_TO_CURRENCY: Record<string, string> = {
  UAE: 'AED',
  UGANDA: 'UGX',
  KENYA: 'KES',
  CHINA: 'CNY',
};

async function countryMiddleware(req: NextRequest) {
  // If cookie already set, do nothing
  const existing = req.cookies.get('selectedCountry');
  if (existing) return NextResponse.next();

  // Try to use built-in geo if available
  try {
    const geo = (req as any).geo as { country?: string } | undefined;
    const countryCode = (geo?.country || '').toUpperCase();
    const mapped = VALID[countryCode as keyof typeof VALID];
    if (mapped) {
      const res = NextResponse.next();
      const currency = COUNTRY_TO_CURRENCY[mapped] ?? 'USD';
      res.cookies.set('selectedCountry', mapped, { path: '/', httpOnly: false, sameSite: 'lax', maxAge: 60 * 60 * 24 * 30 });
      res.cookies.set('selectedCurrency', currency, { path: '/', httpOnly: false, sameSite: 'lax', maxAge: 60 * 60 * 24 * 30 });
      // mark selection as auto
      res.cookies.set('lastSelection', 'auto', { path: '/', httpOnly: false, sameSite: 'lax', maxAge: 60 * 60 * 24 * 30 });
      return res;
    }
  } catch {
    // ignore
  }

  // Fallback: perform a lightweight IP geolocation request server-side
  try {
    const ipRes = await fetch('https://ipapi.co/json/', { method: 'GET', headers: { Accept: 'application/json' } });
    if (ipRes.ok) {
      const data = await ipRes.json();
      const code = (data.country_code || '').toUpperCase();
      const mapped = VALID[code as keyof typeof VALID];
      if (mapped) {
        const res = NextResponse.next();
        const currency = COUNTRY_TO_CURRENCY[mapped] ?? 'USD';
        res.cookies.set('selectedCountry', mapped, { path: '/', httpOnly: false, sameSite: 'lax', maxAge: 60 * 60 * 24 * 30 });
        res.cookies.set('selectedCurrency', currency, { path: '/', httpOnly: false, sameSite: 'lax', maxAge: 60 * 60 * 24 * 30 });
        res.cookies.set('lastSelection', 'auto', { path: '/', httpOnly: false, sameSite: 'lax', maxAge: 60 * 60 * 24 * 30 });
        return res;
      }
    }
  } catch {
    // ignore
  }

  return NextResponse.next();
}

// Chains the existing country/currency detection with Intlayer's locale
// detection (cookie / Accept-Language, since intlayer.config.ts uses
// `routing.mode: "no-prefix"` — no URL redirect happens). Order doesn't
// matter here since neither middleware short-circuits the other's cookies.
export const middleware = multipleMiddlewares([
  intlayerMiddleware,
  countryMiddleware,
]);

export const config = {
  matcher: ['/', '/cart', '/checkout', '/(.*)'],
};
