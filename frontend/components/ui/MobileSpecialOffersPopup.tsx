'use client';

import { useEffect, useState, useCallback, useRef } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { api } from '@/lib/api';
import { resolveImageUrl } from '@/lib/utils';
import { useCountry } from '@/context/CountryContext';
import { useCart } from '@/context/CartContext';
import { useSiteConfig } from '@/context/SiteConfigContext';
import { CurrencyDisplay } from '@/components/ui/CurrencyDisplay';
import { QuickAddButton } from '@/components/listings/QuickAddButton';
import type { Listing } from '@/lib/types';

const MIN_DISCOUNT_PERCENT = 30;

// A "revisit" auto-open is offered once this many hours have passed since
// the popup last auto-showed itself — long enough to not nag someone
// browsing across several pages in one sitting, short enough to greet them
// again on a genuinely new visit.
const REVISIT_WINDOW_HOURS = 12;
const SEEN_IDS_KEY = 'piitrade:specialFinds:seenListingIds';
const LAST_SHOWN_KEY = 'piitrade:specialFinds:lastShownAt';
const VISITED_KEY = 'piitrade:specialFinds:visited';

function discountPercent(listing: Listing): number {
  if (!listing.originalPrice || listing.originalPrice <= listing.price) return 0;
  return Math.round(((listing.originalPrice - listing.price) / listing.originalPrice) * 100);
}

function readLocal(key: string): string | null {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeLocal(key: string, value: string) {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // localStorage unavailable (private mode, etc.) — auto-open just won't
    // persist across visits; the manual toggle button still works fine.
  }
}

/**
 * Mobile-only floating popup. Collapsed by default it's just a small
 * round icon docked above the bottom nav; tapping it expands a sheet of
 * currently active listings discounted 30% or more. Closes back down to
 * the icon on a second tap or when a backdrop tap is registered.
 *
 * Auto-open (admin-gated via siteConfig.specialFindsEnabled — see
 * /admin/settings → Feature Settings) additionally pops the sheet open by
 * itself, once per page load, when any of these hold:
 *   - this is the shopper's first-ever visit to the site;
 *   - it's a fresh revisit (more than REVISIT_WINDOW_HOURS since it last
 *     auto-showed);
 *   - new qualifying listings have been added to the pool since the
 *     shopper last saw it.
 * When the admin switch is off, this component renders nothing at all —
 * not even the collapsed docked icon.
 */
export default function MobileSpecialOffersPopup() {
  const { country, currency: displayCurrency } = useCountry();
  const { totalItems } = useCart();
  const { specialFindsEnabled } = useSiteConfig();
  const [expanded, setExpanded] = useState(false);
  const [listings, setListings] = useState<Listing[]>([]);
  const [loading, setLoading] = useState(false);
  const [fetched, setFetched] = useState(false);
  const autoOpenCheckedRef = useRef(false);

  const loadOffers = useCallback(() => {
    if (fetched) return;
    setLoading(true);
    api
      .get(`/listings/flash-sales`, { params: { country, limit: 40 } })
      .then(({ data }) => {
        const pool: Listing[] = data.listings || [];
        setListings(pool.filter((l) => discountPercent(l) >= MIN_DISCOUNT_PERCENT));
      })
      .catch(() => {})
      .finally(() => {
        setLoading(false);
        setFetched(true);
      });
  }, [country, fetched]);

  // Refresh the offer pool whenever the shopper switches country/market.
  useEffect(() => {
    setFetched(false);
    autoOpenCheckedRef.current = false;
  }, [country]);

  // Always load the offer pool up front (not just lazily on tap) so the
  // auto-open decision below has real data to react to.
  useEffect(() => {
    if (specialFindsEnabled) loadOffers();
  }, [specialFindsEnabled, loadOffers]);

  // Decide, once per fetch, whether to auto-open.
  useEffect(() => {
    if (!specialFindsEnabled || !fetched || autoOpenCheckedRef.current) return;
    autoOpenCheckedRef.current = true;
    if (listings.length === 0) return;

    const currentIds = listings.map((l) => l.id).sort();
    const isFirstVisit = readLocal(VISITED_KEY) === null;

    const lastShownRaw = readLocal(LAST_SHOWN_KEY);
    const lastShown = lastShownRaw ? Number(lastShownRaw) : 0;
    const hoursSinceShown = lastShown ? (Date.now() - lastShown) / (1000 * 60 * 60) : Infinity;
    const isRevisit = !isFirstVisit && hoursSinceShown >= REVISIT_WINDOW_HOURS;

    const seenIdsRaw = readLocal(SEEN_IDS_KEY);
    let seenIds: string[] = [];
    if (seenIdsRaw) {
      try {
        seenIds = JSON.parse(seenIdsRaw);
      } catch {
        seenIds = [];
      }
    }
    const hasNewListings = currentIds.some((id) => !seenIds.includes(id));

    writeLocal(VISITED_KEY, '1');

    if (isFirstVisit || isRevisit || hasNewListings) {
      setExpanded(true);
      writeLocal(LAST_SHOWN_KEY, String(Date.now()));
      writeLocal(SEEN_IDS_KEY, JSON.stringify(currentIds));
    }
  }, [specialFindsEnabled, fetched, listings]);

  const toggle = () => {
    const next = !expanded;
    setExpanded(next);
    if (next) loadOffers();
  };

  // Admin master switch: hide the popup — collapsed icon included — entirely.
  if (!specialFindsEnabled) return null;

  return (
    <div className="sm:hidden">
      {/* Backdrop when expanded */}
      {expanded && (
        <div
          className="fixed inset-0 z-40 bg-black/40"
          onClick={() => setExpanded(false)}
          aria-hidden="true"
        />
      )}

      {/* Collapsed icon (default state) / expand-toggle handle */}
      <button
        type="button"
        onClick={toggle}
        aria-expanded={expanded}
        aria-label={expanded ? 'Hide special offers' : `Show special offers of ${MIN_DISCOUNT_PERCENT}% off and up`}
        className="fixed z-50 bottom-20 right-4 w-12 h-12 rounded-full bg-red-600 text-white shadow-lg flex items-center justify-center border-2 border-white active:scale-95 transition-transform"
        style={{
          // Clears the persistent "View cart" bar (see MobileFloatingCartBar)
          // when it's showing, so the two floating controls never overlap.
          bottom: expanded
            ? undefined
            : totalItems > 0
            ? 'calc(9rem + env(safe-area-inset-bottom, 0px))'
            : 'calc(5rem + env(safe-area-inset-bottom, 0px))',
        }}
      >
        {expanded ? (
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        ) : (
          <span className="flex flex-col items-center leading-none">
            <span className="text-[13px] font-black">%</span>
            <span className="text-[7px] font-bold tracking-tight">{MIN_DISCOUNT_PERCENT}%+</span>
          </span>
        )}
      </button>

      {/* Expanded sheet — styled after the "New finds" reference: cream
          banner header with a bold "up to X% off" chip, close (X) button
          top-left, then a vertical list of deal rows (image, name, quick
          facts, discount chip) rather than a grid. */}
      {expanded && (
        <div
          className="fixed inset-x-0 bottom-0 z-50 max-h-[85vh] bg-white rounded-t-2xl shadow-2xl flex flex-col overflow-hidden"
          style={{ paddingBottom: 'env(safe-area-inset-bottom, 0px)' }}
        >
          <div className="relative bg-[var(--theme-bg-light)] px-4 pt-4 pb-5">
            <button
              type="button"
              onClick={() => setExpanded(false)}
              aria-label="Close special offers"
              className="absolute top-3 left-3 w-8 h-8 rounded-full bg-white shadow flex items-center justify-center text-gray-600"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
            <div className="pt-9 flex flex-col items-start gap-1.5">
              <p className="text-2xl font-black text-gray-900 leading-none">Special finds</p>
              <span className="inline-block bg-gray-900 text-lime-300 font-black text-sm px-3 py-1 rounded-md -rotate-1">
                up to {MIN_DISCOUNT_PERCENT}%+ off
              </span>
              <p className="text-[12px] text-gray-500 mt-0.5">Discover deep discounts and save more</p>
            </div>
          </div>

          <div className="overflow-y-auto px-3 py-3 divide-y divide-gray-50">
            {loading &&
              Array.from({ length: 4 }).map((_, i) => (
                <div key={i} className="flex gap-3 py-3">
                  <div className="w-20 h-20 shrink-0 rounded-xl bg-gray-100 animate-pulse" />
                  <div className="flex-1 space-y-2 py-1">
                    <div className="h-3 w-2/3 bg-gray-100 rounded animate-pulse" />
                    <div className="h-3 w-1/3 bg-gray-100 rounded animate-pulse" />
                  </div>
                </div>
              ))}

            {!loading && listings.length === 0 && (
              <p className="text-center text-sm text-gray-400 py-8">No {MIN_DISCOUNT_PERCENT}%+ offers right now — check back soon.</p>
            )}

            {!loading &&
              listings.map((listing) => {
                const img = listing.productImages?.find((i) => i.cdnUrl)?.cdnUrl ?? listing.images?.[0] ?? null;
                const pct = discountPercent(listing);
                return (
                  <div key={listing.id} className="relative flex gap-3 py-3">
                    <Link href={`/listings/${listing.id}`} onClick={() => setExpanded(false)} className="flex gap-3 flex-1 min-w-0">
                      <div className="relative w-20 h-20 shrink-0 rounded-xl overflow-hidden bg-gray-50">
                        {resolveImageUrl(img) ? (
                          <Image src={resolveImageUrl(img)!} alt={listing.title} fill className="object-cover" sizes="80px" />
                        ) : (
                          <div className="absolute inset-0 flex items-center justify-center text-gray-300 text-[10px]">No image</div>
                        )}
                      </div>
                      <div className="min-w-0 flex-1 py-0.5">
                        <p className="text-sm font-bold text-gray-900 truncate pr-8">{listing.title}</p>
                        <p className="text-[11px] text-gray-500 mt-0.5 truncate">{listing.category?.name} · {listing.location}</p>
                        <div className="flex items-baseline gap-1.5 mt-1">
                          <CurrencyDisplay
                            amount={listing.price}
                            currency={listing.currency}
                            displayCurrency={displayCurrency}
                            className="text-red-600 font-extrabold text-sm leading-none"
                          />
                          <CurrencyDisplay
                            amount={listing.originalPrice!}
                            currency={listing.currency}
                            displayCurrency={displayCurrency}
                            className="text-gray-400 line-through text-[11px] leading-none"
                          />
                        </div>
                        <span className="inline-block mt-1.5 bg-lime-300 text-gray-900 text-[10px] font-bold px-1.5 py-0.5 rounded leading-none">
                          Save {pct}% off
                        </span>
                      </div>
                    </Link>
                    <div className="absolute bottom-0.5 right-0">
                      <QuickAddButton listing={listing} size="sm" />
                    </div>
                  </div>
                );
              })}
          </div>
        </div>
      )}
    </div>
  );
}
