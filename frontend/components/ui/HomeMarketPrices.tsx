'use client';

/**
 * HomeMarketPrices
 *
 * Full "UGANDA MARKET PRICES" homepage section, styled to match the site's
 * premium orange/red theme (same gradient-header + white-card language as
 * <FlashDeals />, <CountryLatestCollections /> etc.). Shows a handful of
 * commodities as proper cards with a trend badge and a link through to the
 * full filterable /market-prices page.
 */

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { api } from '@/lib/api';

interface CommodityItem {
  id: string;
  name: string;
  unit: string;
  price: number;
  previousPrice: number | null;
  marketType: 'RETAIL' | 'WHOLESALE';
  location: string | null;
}

function formatUGX(value: number): string {
  return `UGX ${value.toLocaleString('en-UG', { maximumFractionDigits: value % 1 === 0 ? 0 : 2 })}`;
}

function trend(item: CommodityItem): 'up' | 'down' | 'flat' {
  if (item.previousPrice == null || item.previousPrice === item.price) return 'flat';
  return item.price > item.previousPrice ? 'up' : 'down';
}

function changePct(item: CommodityItem): number | null {
  if (item.previousPrice == null || item.previousPrice <= 0) return null;
  return ((item.price - item.previousPrice) / item.previousPrice) * 100;
}

const COMMODITY_ICONS: Record<string, string> = {
  sugar: '🍬', coffee: '☕', cement: '🧱', beans: '🫘', 'maize flour': '🌽',
  rice: '🍚', 'cooking oil': '🛢️', salt: '🧂', milk: '🥛', charcoal: '🪵',
  electricity: '⚡', petrol: '⛽', diesel: '⛽',
};

function iconFor(name: string): string {
  return COMMODITY_ICONS[name.trim().toLowerCase()] ?? '🛒';
}

function PriceCard({ item }: { item: CommodityItem }) {
  const dir = trend(item);
  const pct = changePct(item);

  return (
    <Link
      href="/market-prices"
      className="group relative shrink-0 w-[42%] xs:w-[31%] sm:w-[23%] md:w-[18%] lg:w-[15.5%] flex flex-col overflow-hidden rounded-xl bg-white shadow hover:shadow-xl transition-all duration-300 hover:-translate-y-1 border border-red-100/60 p-3"
    >
      <div className="flex items-start justify-between gap-2 mb-2">
        <div className="w-9 h-9 rounded-lg bg-gradient-to-br from-red-50 to-orange-50 flex items-center justify-center text-lg shrink-0">
          <span aria-hidden="true">{iconFor(item.name)}</span>
        </div>
        <span
          className={`shrink-0 text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full ${
            item.marketType === 'WHOLESALE' ? 'bg-premium-navy/10 text-premium-navy' : 'bg-red-100 text-red-700'
          }`}
        >
          {item.marketType === 'WHOLESALE' ? 'Wholesale' : 'Retail'}
        </span>
      </div>

      <h3 className="font-bold text-gray-900 text-xs xs:text-sm leading-tight truncate" title={item.name}>
        {item.name}
      </h3>
      <p className="text-[9px] xs:text-[10px] text-gray-400 mb-1.5">per {item.unit}</p>

      <p className="text-sm xs:text-base font-extrabold text-red-600 tabular-nums leading-none">
        {formatUGX(item.price)}
      </p>

      <div className="flex items-center justify-between mt-1.5">
        {dir === 'flat' ? (
          <span className="text-[9px] xs:text-[10px] font-semibold text-gray-300">— no change</span>
        ) : (
          <span
            className={`inline-flex items-center gap-0.5 text-[9px] xs:text-[10px] font-bold tabular-nums ${
              dir === 'up' ? 'text-emerald-600' : 'text-red-500'
            }`}
          >
            <svg className="w-2.5 h-2.5" fill="currentColor" viewBox="0 0 20 20">
              {dir === 'up' ? <path d="M10 3l6 8h-4v6H8v-6H4l6-8z" /> : <path d="M10 17l-6-8h4V3h4v6h4l-6 8z" />}
            </svg>
            {pct != null ? `${dir === 'up' ? '+' : ''}${pct.toFixed(1)}%` : dir === 'up' ? 'Up' : 'Down'}
          </span>
        )}
        {item.location && (
          <span className="text-[9px] xs:text-[10px] text-gray-400 truncate max-w-[70px]">{item.location}</span>
        )}
      </div>
    </Link>
  );
}

function SkeletonCard() {
  return (
    <div className="shrink-0 w-[42%] xs:w-[31%] sm:w-[23%] md:w-[18%] lg:w-[15.5%] rounded-xl border border-gray-100 overflow-hidden animate-pulse bg-white p-3">
      <div className="w-9 h-9 rounded-lg bg-gray-100 mb-2" />
      <div className="h-2.5 bg-gray-100 rounded w-2/3 mb-1.5" />
      <div className="h-2 bg-gray-100 rounded w-1/2 mb-2" />
      <div className="h-3 bg-gray-100 rounded w-3/4" />
    </div>
  );
}

/** End-of-row tile shown only when there are more commodities than fit in
 *  the single-line strip — a plain arrow card linking through to the full
 *  /market-prices page, rather than cramming extra items into the row or
 *  wrapping onto a second line. */
function ViewAllTile() {
  return (
    <Link
      href="/market-prices"
      aria-label="View all Uganda market prices"
      className="group shrink-0 w-[42%] xs:w-[31%] sm:w-[23%] md:w-[18%] lg:w-[15.5%] flex flex-col items-center justify-center gap-1.5 rounded-xl bg-white/90 hover:bg-white border border-dashed border-white/70 hover:border-white transition-all duration-300 p-3 text-center"
    >
      <span className="w-9 h-9 rounded-full bg-orange-50 text-orange-600 flex items-center justify-center shrink-0 group-hover:translate-x-0.5 transition-transform">
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2.5}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
        </svg>
      </span>
      <span className="text-[10px] xs:text-[11px] font-bold text-gray-700 leading-tight">View All<br />Prices</span>
    </Link>
  );
}

export default function HomeMarketPrices() {
  const [items, setItems] = useState<CommodityItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    api.get('/commodity-prices')
      .then(({ data }: { data: { items?: CommodityItem[] } }) => {
        if (!cancelled) setItems(data?.items || []);
      })
      .catch(() => { if (!cancelled) setItems([]); })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, []);

  // Nothing published yet and we're done loading — quietly skip the section
  // rather than show an empty shell on the homepage.
  if (!loading && items.length === 0) return null;

  // One line, max 6 cards. When there are more commodities than that, the
  // 6th slot becomes a "View All" arrow tile linking through to the full
  // /market-prices page instead of cramming extra items in or wrapping
  // onto a second row.
  const MAX_VISIBLE = 6;
  const hasOverflow = items.length > MAX_VISIBLE;
  const cards = items.slice(0, hasOverflow ? MAX_VISIBLE - 1 : MAX_VISIBLE);

  return (
    <section className="overflow-hidden rounded-2xl shadow-lg animate-fade-up" style={{ background: 'linear-gradient(135deg,#E94B00 0%,#FF6500 50%,#FF8433 100%)' }}>
      {/* Header */}
      <div className="relative flex flex-col gap-2 px-4 py-3 text-white sm:flex-row sm:items-center sm:justify-between overflow-hidden">
        <div className="absolute -top-4 -right-4 w-24 h-24 rounded-full bg-white/10 blur-xl pointer-events-none" />
        <div className="absolute -bottom-6 left-10 w-32 h-32 rounded-full bg-white/10 blur-2xl pointer-events-none" />
        <div className="relative flex items-center gap-2.5">
          <span className="text-2xl drop-shadow-lg" aria-hidden="true">🇺🇬</span>
          <div>
            <h2 className="text-base font-extrabold leading-tight tracking-wide">UGANDA MARKET PRICES</h2>
            <p className="text-[11px] text-white/85">Everyday commodity prices from Uganda&apos;s local markets.</p>
          </div>
        </div>
        <Link
          href="/market-prices"
          aria-label="View all Uganda market prices"
          className="relative text-xs font-semibold text-white/90 hover:text-white border border-white/30 hover:border-white/60 px-3 py-1.5 rounded-full bg-white/10 hover:bg-white/20 transition-all flex items-center gap-1 shrink-0 self-start sm:self-auto"
        >
          View All Prices
          <svg className="w-3.5 h-3.5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </Link>
      </div>

      {/* Cards — a single non-wrapping line, always. Scrolls horizontally
          on narrow screens (no vertical reflow/jump as items settle), and
          never spills onto a second row at any breakpoint. Capped at 6
          slots total; anything beyond that is reached via the arrow tile
          or the "View All Prices" link above, not by showing more cards. */}
      <div className="bg-white/10 backdrop-blur-sm p-3 sm:p-4">
        <div className="flex gap-2 sm:gap-3 overflow-x-auto scrollbar-none snap-x snap-mandatory" role="list" aria-label="Uganda market price listings">
          {loading ? (
            Array.from({ length: 6 }).map((_, i) => <SkeletonCard key={i} />)
          ) : (
            <>
              {cards.map((item) => (
                <div key={item.id} role="listitem" className="snap-start">
                  <PriceCard item={item} />
                </div>
              ))}
              {hasOverflow && (
                <div role="listitem" className="snap-start">
                  <ViewAllTile />
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </section>
  );
}
