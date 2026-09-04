'use client';

/**
 * HomeFarmerMarketplace
 *
 * "FARMER MARKETPLACE" homepage section — sits directly below
 * <HomeMarketPrices /> in the same below-the-slideshow slot. Where
 * HomeMarketPrices shows admin-curated everyday commodity prices, this
 * shows real farmer produce posts (quantity, location, availability,
 * minimum price) with a live count of buyer offers and the best delivered
 * price calculated so far, so a visitor sees at a glance that this is a
 * transactional marketplace, not just a price board. Links through to the
 * "Farmer Marketplace" tab on /market-prices for full detail (buyer offers,
 * delivered-price breakdown, regional comparison, price history).
 */

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { api } from '@/lib/api';

interface FarmerPostSummary {
  id: string;
  farmerName: string;
  verifiedSeller: boolean;
  commodity: string;
  quantity: number;
  unit: string;
  location: string;
  qualityGrade: 'A' | 'B' | 'C' | 'UNGRADED';
  availability: 'IMMEDIATE' | 'DATE';
  minPricePerUnit: number;
  currency: string;
  offerCount: number;
  bestDeliveredPricePerUnit: number | null;
}

function formatMoney(value: number, currency: string): string {
  return `${currency} ${value.toLocaleString('en-UG', { maximumFractionDigits: value % 1 === 0 ? 0 : 2 })}`;
}

const COMMODITY_ICONS: Record<string, string> = {
  maize: '🌽', coffee: '☕', beans: '🫘', rice: '🍚', millet: '🌾',
  cassava: '🍠', sorghum: '🌾', sunflower: '🌻', soybean: '🫛', groundnuts: '🥜',
};

function iconFor(name: string): string {
  return COMMODITY_ICONS[name.trim().toLowerCase()] ?? '🌾';
}

function PostCard({ post }: { post: FarmerPostSummary }) {
  return (
    <Link
      href="/market-prices?tab=farmer-marketplace"
      role="listitem"
      className="group relative shrink-0 w-[68%] xs:w-[52%] sm:w-[38%] md:w-[29%] lg:w-[23%] flex flex-col overflow-hidden rounded-xl bg-white shadow hover:shadow-xl transition-all duration-300 hover:-translate-y-1 border border-green-100/60 p-3.5 snap-start"
    >
      <div className="flex items-start justify-between gap-2 mb-2">
        <div className="flex items-center gap-2 min-w-0">
          <div className="w-9 h-9 rounded-lg bg-gradient-to-br from-green-50 to-emerald-50 flex items-center justify-center text-lg shrink-0">
            <span aria-hidden="true">{iconFor(post.commodity)}</span>
          </div>
          <div className="min-w-0">
            <h3 className="font-bold text-gray-900 text-xs xs:text-sm leading-tight truncate" title={post.commodity}>
              {post.commodity}
            </h3>
            <p className="text-[9px] xs:text-[10px] text-gray-400 truncate">{post.farmerName}</p>
          </div>
        </div>
        {post.verifiedSeller && (
          <span className="shrink-0 inline-flex items-center gap-0.5 text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-emerald-100 text-emerald-700" title="Verified seller">
            <svg className="w-2.5 h-2.5" fill="currentColor" viewBox="0 0 20 20"><path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" /></svg>
            Verified
          </span>
        )}
      </div>

      <div className="flex items-center gap-1.5 text-[10px] xs:text-[11px] text-gray-500 mb-1">
        <span className="font-bold text-gray-800">{post.quantity.toLocaleString()} {post.unit}</span>
        <span className="text-gray-300">•</span>
        <span className="truncate">{post.location}</span>
      </div>

      <div className="flex items-center gap-1.5 mb-2">
        <span className={`text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full ${post.availability === 'IMMEDIATE' ? 'bg-orange-100 text-orange-700' : 'bg-slate-100 text-slate-600'}`}>
          {post.availability === 'IMMEDIATE' ? 'Available now' : 'Available soon'}
        </span>
        {post.qualityGrade !== 'UNGRADED' && (
          <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-premium-navy/10 text-premium-navy">
            Grade {post.qualityGrade}
          </span>
        )}
      </div>

      <div className="mt-auto pt-1.5 border-t border-gray-50">
        <p className="text-[9px] text-gray-400">Farmer&apos;s minimum</p>
        <p className="text-sm xs:text-base font-extrabold text-green-700 tabular-nums leading-none">
          {formatMoney(post.minPricePerUnit, post.currency)}<span className="text-[10px] font-semibold text-gray-400">/{post.unit}</span>
        </p>
        {post.offerCount > 0 && post.bestDeliveredPricePerUnit != null ? (
          <p className="text-[9px] xs:text-[10px] text-gray-500 mt-1">
            {post.offerCount} buyer offer{post.offerCount === 1 ? '' : 's'} · best delivered{' '}
            <span className="font-bold text-gray-700">{formatMoney(post.bestDeliveredPricePerUnit, post.currency)}</span>
          </p>
        ) : (
          <p className="text-[9px] xs:text-[10px] text-gray-400 mt-1">No buyer offers yet</p>
        )}
      </div>
    </Link>
  );
}

function SkeletonCard() {
  return (
    <div className="shrink-0 w-[68%] xs:w-[52%] sm:w-[38%] md:w-[29%] lg:w-[23%] snap-start rounded-xl border border-gray-100 overflow-hidden animate-pulse bg-white p-3.5">
      <div className="w-9 h-9 rounded-lg bg-gray-100 mb-2" />
      <div className="h-2.5 bg-gray-100 rounded w-2/3 mb-1.5" />
      <div className="h-2 bg-gray-100 rounded w-1/2 mb-2" />
      <div className="h-3 bg-gray-100 rounded w-3/4" />
    </div>
  );
}

function ViewAllTile() {
  return (
    <Link
      href="/market-prices?tab=farmer-marketplace"
      aria-label="View all farmer marketplace posts"
      role="listitem"
      className="group shrink-0 w-[68%] xs:w-[52%] sm:w-[38%] md:w-[29%] lg:w-[23%] flex flex-col items-center justify-center gap-1.5 rounded-xl bg-white/90 hover:bg-white border border-dashed border-white/70 hover:border-white transition-all duration-300 p-3 text-center snap-start"
    >
      <span className="w-9 h-9 rounded-full bg-green-50 text-green-700 flex items-center justify-center shrink-0 group-hover:translate-x-0.5 transition-transform">
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2.5}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
        </svg>
      </span>
      <span className="text-[10px] xs:text-[11px] font-bold text-gray-700 leading-tight">See All<br />Farmer Posts</span>
    </Link>
  );
}

export default function HomeFarmerMarketplace() {
  const [posts, setPosts] = useState<FarmerPostSummary[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    api.get('/farmer-marketplace/posts?status=OPEN')
      .then(({ data }: { data: { posts?: FarmerPostSummary[] } }) => {
        if (!cancelled) setPosts(data?.posts || []);
      })
      .catch(() => { if (!cancelled) setPosts([]); })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, []);

  // Nothing posted yet and we're done loading — quietly skip the section.
  if (!loading && posts.length === 0) return null;

  const MAX_VISIBLE = 5;
  const hasOverflow = posts.length > MAX_VISIBLE;
  const cards = posts.slice(0, hasOverflow ? MAX_VISIBLE - 1 : MAX_VISIBLE);

  return (
    <section className="overflow-hidden rounded-2xl shadow-lg animate-fade-up" style={{ background: 'linear-gradient(135deg,#0F5132 0%,#1B7A43 50%,#2E9E56 100%)' }}>
      {/* Header */}
      <div className="relative flex flex-col gap-2 px-4 py-3 text-white sm:flex-row sm:items-center sm:justify-between overflow-hidden">
        <div className="absolute -top-4 -right-4 w-24 h-24 rounded-full bg-white/10 blur-xl pointer-events-none" />
        <div className="absolute -bottom-6 left-10 w-32 h-32 rounded-full bg-white/10 blur-2xl pointer-events-none" />
        <div className="relative flex items-center gap-2.5">
          <span className="text-2xl drop-shadow-lg" aria-hidden="true">🚜</span>
          <div>
            <h2 className="text-base font-extrabold leading-tight tracking-wide">FARMER MARKETPLACE</h2>
            <p className="text-[11px] text-white/85">Farmers post produce, buyers across regions quote a delivered price.</p>
          </div>
        </div>
        <Link
          href="/market-prices?tab=farmer-marketplace"
          aria-label="View all farmer marketplace posts"
          className="relative text-xs font-semibold text-white/90 hover:text-white border border-white/30 hover:border-white/60 px-3 py-1.5 rounded-full bg-white/10 hover:bg-white/20 transition-all flex items-center gap-1 shrink-0 self-start sm:self-auto"
        >
          See All Farmer Posts
          <svg className="w-3.5 h-3.5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </Link>
      </div>

      {/* Cards — single non-wrapping scrollable row, same pattern as
          <HomeMarketPrices />, so the two sections read as siblings. */}
      <div className="bg-white/10 backdrop-blur-sm p-3 sm:p-4">
        <div className="flex gap-2 sm:gap-3 overflow-x-auto scrollbar-none snap-x snap-mandatory" role="list" aria-label="Farmer marketplace posts">
          {loading ? (
            Array.from({ length: 4 }).map((_, i) => <SkeletonCard key={i} />)
          ) : (
            <>
              {cards.map((post) => (
                <PostCard key={post.id} post={post} />
              ))}
              {hasOverflow && <ViewAllTile />}
            </>
          )}
        </div>
      </div>
    </section>
  );
}
