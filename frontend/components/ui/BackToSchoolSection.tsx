'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { api } from '@/lib/api';
import { useCountry } from '@/context/CountryContext';
import { ListingCard } from '@/components/listings/ListingCard';
import { MobileCardCarousel } from '@/components/ui/MobileCardCarousel';
import type { Listing } from '@/lib/types';

// Categories that plausibly cover "back to school" shopping — school-age
// kids' gear and books/stationery. No dedicated category exists in the
// catalog yet, so this pulls discounted listings from the closest existing
// ones rather than inventing data.
const SOURCE_CATEGORY_SLUGS = ['books-hobbies', 'kids-baby'];

function discountPercent(listing: Listing): number {
  if (!listing.originalPrice || listing.originalPrice <= listing.price) return 0;
  return Math.round(((listing.originalPrice - listing.price) / listing.originalPrice) * 100);
}

export default function BackToSchoolSection() {
  const { country } = useCountry();
  const [listings, setListings] = useState<Listing[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);

    Promise.all(
      SOURCE_CATEGORY_SLUGS.map((category) =>
        api
          .get('/listings', { params: { category, country, limit: 16, sort: 'createdAt' }, signal: controller.signal })
          .then(({ data }) => (data.listings || []) as Listing[])
          .catch(() => [] as Listing[])
      )
    ).then((groups) => {
      if (controller.signal.aborted) return;
      const merged = new Map<string, Listing>();
      groups.flat().forEach((l) => merged.set(l.id, l));
      const discounted = Array.from(merged.values())
        .filter((l) => discountPercent(l) > 0)
        .sort((a, b) => discountPercent(b) - discountPercent(a))
        .slice(0, 8);
      setListings(discounted);
      setLoading(false);
    });

    return () => controller.abort();
  }, [country]);

  if (!loading && listings.length === 0) return null;

  return (
    <section className="sm:hidden">
      <div className="rounded-2xl overflow-hidden bg-[var(--theme-bg-light)] border border-orange-100">
        {/* Banner header */}
        <Link href="/listings?category=books-hobbies" className="flex items-center gap-3 px-3.5 py-3">
          <div className="shrink-0 w-11 h-11 rounded-xl bg-white shadow-sm flex items-center justify-center text-xl">
            🎒
          </div>
          <div className="min-w-0 flex-1">
            <p className="font-black text-gray-900 leading-tight text-[15px] truncate">
              <span className="text-[var(--theme-primary)]">BACK TO SCHOOL</span> FLASH SALE <span aria-hidden="true">⚡</span>
            </p>
            <p className="text-[11px] text-gray-500 truncate">
              Discounted picks for the new term, while stocks last
            </p>
          </div>
          <span className="shrink-0 w-8 h-8 rounded-full bg-white shadow-sm flex items-center justify-center text-gray-700">
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
            </svg>
          </span>
        </Link>

        {/* Three cards per row on mobile (matches the reference layout),
            collapsing into the standard responsive grid at sm+ — same
            MobileCardCarousel + ListingCard pairing used by Flash Deals,
            so this section looks and behaves like the rest of the site
            rather than its own one-off peeking scroller. */}
        <div className="px-3 pb-3 -mt-0.5">
          {loading ? (
            <div className="grid grid-cols-3 gap-2.5">
              {Array.from({ length: 3 }).map((_, i) => (
                <div key={i} className="animate-pulse rounded-xl bg-white/70 aspect-[3/4]" />
              ))}
            </div>
          ) : (
            <MobileCardCarousel gridClassName="sm:grid-cols-3 md:grid-cols-4 gap-2.5" ariaLabel="Back to school flash sale listings">
              {listings.map((listing) => (
                <ListingCard key={listing.id} listing={listing} />
              ))}
            </MobileCardCarousel>
          )}
        </div>
      </div>
    </section>
  );
}
