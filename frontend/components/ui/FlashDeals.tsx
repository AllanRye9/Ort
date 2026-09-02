'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { Currency, Listing } from '@/lib/types';
import { resolveImageUrl, getCurrency, convertCurrency, formatCurrency } from '@/lib/utils';
import { useCountry } from '@/context/CountryContext';
import { useAuth } from '@/context/AuthContext';
import { QuickAddButton } from '@/components/listings/QuickAddButton';
import { MobileCardCarousel } from '@/components/ui/MobileCardCarousel';

interface FlashMediaItem {
  id: string;
  cdnUrl: string;
  title?: string | null;
  shortDescription?: string | null;
  price?: number | null;
  originalPrice?: number | null;
  currency?: Currency | null;
  altText?: string | null;
  linkUrl?: string | null;
}

interface Props {
  listings: Listing[];
  media?: FlashMediaItem[];
}

interface CardData {
  id: string;
  href: string | null;
  title: string;
  shortDescription?: string | null;
  imageUrl: string | null;
  price: number | null;
  originalPrice: number | null;
  currency: Currency | null;
  listing?: Listing;
}

const truncateTitle = (value: string, max = 26) => (
  value.length <= max ? value : `${value.slice(0, max - 3).trimEnd()}...`
);

const toNumberOrNull = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

/** Returns a pseudo-random integer [min, max] seeded from a string. */
const seededInt = (seed: string, min: number, max: number) => {
  const hash = Array.from(seed).reduce((sum, char) => sum + char.charCodeAt(0), 0);
  return min + (hash % (max - min + 1));
};

function useCountdown(listings: Listing[]) {
  const expiryTime = useMemo(() => {
    const now = Date.now();
    const listingExpiryTimes = listings
      .map((listing) => (listing.placementExpiresAt ? new Date(listing.placementExpiresAt).getTime() : NaN))
      .filter((value) => Number.isFinite(value) && value > now) as number[];

    if (listingExpiryTimes.length > 0) {
      return Math.min(...listingExpiryTimes);
    }

    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);
    return endOfDay.getTime();
  }, [listings]);

  const [timeLeft, setTimeLeft] = useState({ hours: 0, minutes: 0, seconds: 0 });

  useEffect(() => {
    const calc = () => {
      const diff = Math.max(0, expiryTime - Date.now());
      setTimeLeft({
        hours: Math.floor(diff / 3_600_000),
        minutes: Math.floor((diff % 3_600_000) / 60_000),
        seconds: Math.floor((diff % 60_000) / 1_000),
      });
    };

    calc();
    const interval = window.setInterval(calc, 1000);
    return () => window.clearInterval(interval);
  }, [expiryTime]);

  return timeLeft;
}

function useItemsLeft(seed: string): [number, number] {
  const maxItems = useMemo(() => seededInt(seed, 8, 60), [seed]);
  const [count, setCount] = useState<number>(maxItems);
  const resetCountRef = useRef(0);

  useEffect(() => {
    const delay = seededInt(seed + '_delay', 3000, 7000);
    const timer = setInterval(() => {
      setCount((prev) => {
        if (prev <= 1) {
          resetCountRef.current += 1;
          return seededInt(seed + '_reset_' + resetCountRef.current, 8, 60);
        }
        return prev - 1;
      });
    }, delay);
    return () => clearInterval(timer);
  }, [seed]);

  return [count, maxItems];
}

/** Single flash sale card with its own live items-left counter. */
function FlashCard({ card, displayCurrency }: { card: CardData; displayCurrency: Currency }) {
  const [itemsLeft, maxItems] = useItemsLeft(card.id);
  const pct = Math.round((itemsLeft / maxItems) * 100);
  const isLow = itemsLeft <= 5;
  // Tracks whether the resolved image actually failed to load (e.g. the
  // backend's local-disk upload fallback got wiped by a redeploy and now
  // 404s). Falls back to the "Coming soon" placeholder instead of leaving
  // a broken image + a failed network request nagging the console.
  const [imgFailed, setImgFailed] = useState(false);
  const showImage = !!card.imageUrl && !imgFailed;

  // Buyer quick-add — same gating as ListingCard/FeaturedProductCard: only
  // for signed-in non-admin buyers who aren't the listing's own seller,
  // and only for real listing-backed cards (media-only placeholder cards
  // have no listing to add to a cart).
  const { user } = useAuth();
  const isAdmin = user?.role === 'ADMIN';
  const isOwnListing = !!card.listing && !!user && user.id === card.listing.userId;
  const showQuickAdd = !!card.listing && !!user && !isAdmin && !isOwnListing;

  // Convert price to display currency if needed
  const displayPrice = card.price !== null && card.currency
    ? convertCurrency(card.price, card.currency, displayCurrency)
    : null;
  const displayOriginal = card.originalPrice !== null && card.currency
    ? convertCurrency(card.originalPrice, card.currency, displayCurrency)
    : null;
  const discountPercent =
    displayOriginal != null && displayPrice != null && displayOriginal > displayPrice && displayOriginal > 0
      ? Math.round(((displayOriginal - displayPrice) / displayOriginal) * 100)
      : null;

  const inner = (
    <>
      {/* Glow effect on hover */}
      <div className="absolute inset-0 rounded-xl opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none"
        style={{ boxShadow: 'inset 0 0 0 1.5px rgba(251,146,60,0.5)' }} />

      <div className="relative aspect-square overflow-hidden bg-gradient-to-br from-orange-50 to-amber-50">
        {showImage ? (
          <Image
            src={card.imageUrl as string}
            alt={card.title}
            fill
            className="object-cover transition-transform duration-500 group-hover:scale-110"
            sizes="(max-width: 640px) 33vw, 16vw"
            loading="lazy"
            onError={() => setImgFailed(true)}
          />
        ) : (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-1">
            <span className="text-3xl opacity-30">⚡</span>
            <span className="text-[9px] text-amber-400 font-semibold">Coming soon</span>
          </div>
        )}
        {/* Gradient overlay at bottom */}
        <div className="absolute inset-0 bg-gradient-to-t from-black/40 via-transparent to-transparent pointer-events-none" />
        {/* Hot deal badge + savings badge, stacked */}
        <div className="absolute left-1.5 top-1.5 flex flex-col items-start gap-1">
          <div
            className="flex items-center gap-0.5 rounded-full bg-gradient-to-r from-red-500 to-orange-500 px-1.5 py-0.5 text-[9px] font-extrabold text-white shadow-md animate-pulse"
            aria-label="Hot deal"
          >
            <span aria-hidden="true">🔥</span>
            <span>HOT</span>
          </div>
          {discountPercent != null && discountPercent > 0 && (
            <span className="inline-flex items-center rounded-md bg-lime-400 text-emerald-950 text-[9px] font-extrabold px-1.5 py-0.5 shadow-sm">
              Save {discountPercent}%
            </span>
          )}
        </div>
        {/* Buyer quick-add — top-right, stops propagation so it doesn't
            trigger the card's own Link navigation. */}
        {showQuickAdd && (
          <div className="absolute top-1.5 right-1.5">
            <QuickAddButton listing={card.listing as Listing} size="sm" />
          </div>
        )}
      </div>

      <div className="p-2 space-y-1.5">
        <p className="text-[10px] font-semibold leading-snug text-gray-800 line-clamp-2 min-h-[2.2em]">
          {card.title}
        </p>
        {card.shortDescription && (
          <p className="text-[9px] text-gray-500 truncate" title={card.shortDescription}>
            {card.shortDescription}
          </p>
        )}
        {/* Price in selected country currency */}
        {displayPrice !== null && (
          <div className="flex items-baseline gap-1.5 flex-wrap">
            {displayOriginal !== null && displayOriginal > 0 && displayPrice > 0 && displayOriginal > displayPrice && (
              <span className="text-[9px] text-gray-400 line-through tabular-nums">
                {formatCurrency(displayOriginal, displayCurrency)}
              </span>
            )}
            <span className="animate-price-pop text-[11px] font-extrabold text-orange-600 tabular-nums">
              {formatCurrency(displayPrice, displayCurrency)}
            </span>
            {/* Show original currency if converted */}
            {card.currency && card.currency !== displayCurrency && card.price !== null && (
              <span className="text-[8px] text-gray-400 tabular-nums">
                ({formatCurrency(card.price, card.currency)})
              </span>
            )}
          </div>
        )}
        <div className="flex items-center justify-between">
          <span className="text-[9px] text-slate-400 font-medium">Left</span>
          <span className={`text-[10px] font-extrabold tabular-nums ${isLow ? 'text-red-500 animate-pulse' : 'text-emerald-600'}`}>
            {itemsLeft}
          </span>
        </div>
        <div className="h-1 overflow-hidden rounded-full bg-slate-100">
          <div
            className="h-full rounded-full transition-all duration-700"
            style={{
              width: `${pct}%`,
              background: isLow
                ? 'linear-gradient(90deg,#ef4444,#f97316)'
                : 'linear-gradient(90deg,#10b981,#84cc16,#eab308)',
            }}
          />
        </div>
      </div>
    </>
  );

  if (card.listing) {
    return (
      <Link href={`/listings/${card.listing.id}`} className="group relative overflow-hidden rounded-xl bg-white shadow hover:shadow-xl transition-all duration-300 hover:-translate-y-1 border border-orange-100/60">
        {inner}
      </Link>
    );
  }

  if (card.href) {
    return <Link href={card.href} className="group relative overflow-hidden rounded-xl bg-white shadow hover:shadow-xl transition-all duration-300 hover:-translate-y-1 border border-orange-100/60">{inner}</Link>;
  }
  return <div className="relative overflow-hidden rounded-xl bg-white shadow border border-orange-100/60">{inner}</div>;
}

export default function FlashDeals({ listings, media = [] }: Props) {
  const { hours, minutes, seconds } = useCountdown(listings);
  const { country } = useCountry();
  const displayCurrency = getCurrency(country);

  const cards: CardData[] = listings.length > 0
    ? listings.slice(0, 6).map((listing) => {
        // Use productImages first (CDN), then fall back to images array
        const productImgUrl = (listing.productImages as Array<{ cdnUrl: string }> | undefined)?.find(p => p.cdnUrl)?.cdnUrl;
        const rawImageUrl = productImgUrl || listing.images?.[0] || null;
        return {
          id: listing.id,
          href: `/listings/${listing.id}`,
          title: truncateTitle(listing.title, 30),
          shortDescription: listing.description || null,
          imageUrl: rawImageUrl ? (resolveImageUrl(rawImageUrl) || null) : null,
          price: listing.price,
          originalPrice: listing.originalPrice ?? null,
          currency: listing.currency,
          listing,
        };
      })
    : media.slice(0, 6).map((item, index) => ({
        id: item.id,
        href: item.linkUrl || '/flash-sales',
        title: truncateTitle(item.title || item.altText || `Flash Sale Item ${index + 1}`, 30),
        shortDescription: item.shortDescription || null,
        imageUrl: resolveImageUrl(item.cdnUrl) || null,
        price: toNumberOrNull(item.price),
        originalPrice: toNumberOrNull(item.originalPrice),
        currency: item.currency ?? null,
      }));

  if (cards.length === 0) {
    return (
      <section className="overflow-hidden rounded-2xl shadow-lg animate-fade-up" style={{ background: 'linear-gradient(135deg,#7c3aed 0%,#db2777 40%,#ea580c 100%)' }}>
        <div className="flex flex-col gap-2 px-4 py-3 text-white sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-2">
            <span className="text-2xl drop-shadow-lg animate-bounce" aria-hidden="true">🔥</span>
            <div>
              <h2 className="text-base font-extrabold leading-tight tracking-wide">FLASH SALES</h2>
              <p className="text-[11px] text-white/80">Limited-time drops from our authorized marketplace partners.</p>
              <p className="text-[10px] text-white/70 mt-0.5">High-demand items from vetted vendors. These independent listings are admin-approved and available only until the timer hits zero.</p>
            </div>
          </div>
        </div>
        <div className="bg-white/5 backdrop-blur-sm grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2 p-3 sm:p-4">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="rounded-xl border border-white/10 overflow-hidden animate-pulse bg-white/10">
              <div className="aspect-square bg-white/20" />
              <div className="p-2 space-y-1.5">
                <div className="h-2 bg-white/20 rounded w-3/4" />
                <div className="h-1.5 bg-white/20 rounded w-1/2" />
                <div className="h-1 bg-white/20 rounded" />
              </div>
            </div>
          ))}
        </div>
      </section>
    );
  }

  return (
    <section className="overflow-hidden rounded-2xl shadow-lg animate-fade-up" style={{ background: 'linear-gradient(135deg,#7c3aed 0%,#db2777 40%,#ea580c 100%)' }}>
      {/* Header */}
      <div className="relative flex flex-col gap-2 px-4 py-3 text-white sm:flex-row sm:items-center sm:justify-between overflow-hidden">
        {/* Decorative blobs */}
        <div className="absolute -top-4 -right-4 w-24 h-24 rounded-full bg-white/10 blur-xl pointer-events-none" />
        <div className="absolute -bottom-6 left-10 w-32 h-32 rounded-full bg-white/10 blur-2xl pointer-events-none" />
        <div className="relative flex items-center gap-2.5">
          <span className="text-2xl drop-shadow-lg animate-bounce" aria-hidden="true">🔥</span>
          <div>
            <h2 className="text-base font-extrabold leading-tight tracking-wide">FLASH SALES</h2>
            <p className="text-[11px] text-white/80">Limited-time drops from our authorized marketplace partners.</p>
            <p className="text-[10px] text-white/70 mt-0.5">High-demand items from vetted vendors. These independent listings are admin-approved and available only until the timer hits zero.</p>
          </div>
        </div>
        <div className="relative flex items-center gap-2 self-start sm:self-auto">
          <Link
            href="/flash-sales"
            aria-label="View all flash sales"
            className="text-xs font-semibold text-white/90 hover:text-white border border-white/30 hover:border-white/60 px-3 py-1.5 rounded-full bg-white/10 hover:bg-white/20 transition-all flex items-center gap-1"
          >
            View All Live Sales
            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
            </svg>
          </Link>
          <div
            className="flex items-center gap-1.5 rounded-full border border-white/30 bg-white/15 px-3 py-1.5 text-xs font-bold backdrop-blur-sm tabular-nums shadow-inner"
            aria-label={`Time left: ${String(hours).padStart(2, '0')} hours, ${String(minutes).padStart(2, '0')} minutes, ${String(seconds).padStart(2, '0')} seconds`}
            aria-live="polite"
          >
            <span className="w-2 h-2 rounded-full bg-red-400 animate-ping absolute opacity-60" aria-hidden="true" />
            <span className="w-2 h-2 rounded-full bg-red-400 relative" aria-hidden="true" />
            <span aria-hidden="true">
              {String(hours).padStart(2, '0')}:{String(minutes).padStart(2, '0')}:{String(seconds).padStart(2, '0')}
            </span>
          </div>
        </div>
      </div>

      {/* Cards — mobile carousel (3/row, swipe + arrows), grid at sm+ */}
      <div className="bg-white/5 backdrop-blur-sm p-3 sm:p-4">
        <MobileCardCarousel gridClassName="sm:grid-cols-3 lg:grid-cols-6 gap-2" ariaLabel="Flash Sales listings">
          {cards.map((card) => (
            <FlashCard key={card.id} card={card} displayCurrency={displayCurrency} />
          ))}
        </MobileCardCarousel>
      </div>
    </section>
  );
}


