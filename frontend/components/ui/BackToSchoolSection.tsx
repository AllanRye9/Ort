'use client';

import { useEffect, useState } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { api } from '@/lib/api';
import { useCountry } from '@/context/CountryContext';
import { CurrencyDisplay } from '@/components/ui/CurrencyDisplay';
import { QuickAddButton } from '@/components/listings/QuickAddButton';
import { resolveImageUrl } from '@/lib/utils';
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
  const { country, currency: displayCurrency } = useCountry();
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

        {/* Horizontally-scrolling deal cards, peeking the next card like the reference layout */}
        <div className="px-3 pb-3 -mt-0.5">
          {loading ? (
            <div className="flex gap-2.5 overflow-hidden">
              {Array.from({ length: 3 }).map((_, i) => (
                <div key={i} className="w-[46%] shrink-0 animate-pulse rounded-xl bg-white/70 aspect-[4/5]" />
              ))}
            </div>
          ) : (
            <div className="flex gap-2.5 overflow-x-auto snap-x snap-mandatory scrollbar-none">
              {listings.map((listing) => {
                const img = listing.productImages?.find((i) => i.cdnUrl)?.cdnUrl ?? listing.images?.[0] ?? null;
                const pct = discountPercent(listing);
                return (
                  <div
                    key={listing.id}
                    className="relative w-[46%] shrink-0 snap-start rounded-xl bg-white border border-gray-100 overflow-hidden"
                  >
                    <Link href={`/listings/${listing.id}`} className="block">
                      <div className="relative aspect-square bg-gray-50">
                        {resolveImageUrl(img) ? (
                          <Image src={resolveImageUrl(img)!} alt={listing.title} fill className="object-cover" sizes="46vw" />
                        ) : (
                          <div className="absolute inset-0 flex items-center justify-center text-gray-300 text-xs">No image</div>
                        )}
                        {/* "Save X%" highlighter chip, bottom-left over the image like the reference */}
                        <span className="absolute left-1.5 bottom-1.5 bg-lime-300 text-gray-900 text-[9px] font-extrabold px-1.5 py-0.5 rounded leading-none">
                          Save {pct}%
                        </span>
                      </div>
                      <div className="p-2">
                        <p className="text-[11px] font-semibold text-gray-800 leading-tight truncate">{listing.title}</p>
                        <div className="flex items-baseline gap-1 mt-1 flex-wrap">
                          <CurrencyDisplay
                            amount={listing.price}
                            currency={listing.currency}
                            displayCurrency={displayCurrency}
                            className="text-gray-900 font-extrabold text-xs leading-none"
                          />
                          <CurrencyDisplay
                            amount={listing.originalPrice!}
                            currency={listing.currency}
                            displayCurrency={displayCurrency}
                            className="text-gray-400 line-through text-[9px] leading-none"
                          />
                        </div>
                      </div>
                    </Link>
                    <div className="absolute top-1.5 right-1.5">
                      <QuickAddButton listing={listing} size="sm" />
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
