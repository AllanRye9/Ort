/**
 * CountryThemedHome.tsx
 *
 * Thin client wrapper that was previously used to apply CountryPageWrapper
 * to the homepage. CountryPageWrapper has been removed from the site.
 * This component now renders its children directly without any country-themed
 * decorative wrapper so the homepage is unaffected.
 */
'use client';

export default function CountryThemedHome({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
