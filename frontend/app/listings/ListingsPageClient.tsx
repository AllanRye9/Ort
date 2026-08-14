'use client';

import { useState, useEffect, useRef, Suspense } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { Listing, Category } from '@/lib/types';
import { ListingGrid } from '@/components/listings/ListingGrid';
import { FilterSidebar } from '@/components/listings/FilterSidebar';
import { SearchBar } from '@/components/listings/SearchBar';
import { useCountry } from '@/context/CountryContext';
import { FlagIcon } from '@/components/ui/FlagIcon';

function ListingsContent() {
  const params = useSearchParams();
  const router = useRouter();
  const { country } = useCountry();
  const [listings, setListings] = useState<Listing[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [total, setTotal] = useState(0);
  const [pages, setPages] = useState(1);
  const [loading, setLoading] = useState(true);
  const [filterOpen, setFilterOpen] = useState(false);

  const currentPage = parseInt(params ? params.get('page') || '1' : '1');
  const activeSort  = params?.get('sort') || (params?.get('q') ? 'relevance' : 'recommended');

  // Load categories once
  useEffect(() => {
    api.get('/categories').then(({ data }) => setCategories(data)).catch(() => {});
  }, []);

  // Stable ref to track the last fetched param string — prevents duplicate requests
  const prevQueryRef = useRef('');

  useEffect(() => {
    const merged = new URLSearchParams(params ? params.toString() : '');
    // Always inject the selected country unless already in the URL params
    if (!merged.get('country') && country) merged.set('country', country);
    if (!merged.get('sort')) merged.set('sort', merged.get('q') ? 'relevance' : 'recommended');

    const queryKey = merged.toString();
    if (queryKey === prevQueryRef.current) return;
    prevQueryRef.current = queryKey;

    const controller = new AbortController();
    setLoading(true);

    api.get(`/listings?${queryKey}`, { signal: controller.signal })
      .then(({ data }) => {
        setListings(data.listings || []);
        setTotal(data.pagination?.total || 0);
        setPages(data.pagination?.pages || 1);
      })
      .catch((err) => {
        if (err?.code === 'ERR_CANCELED' || err?.name === 'CanceledError') return;
        setListings([]);
      })
      .finally(() => setLoading(false));

    return () => controller.abort();
  }, [params, country]);

  const goToPage = (page: number) => {
    const newParams = new URLSearchParams(params ? params.toString() : '');
    newParams.set('page', String(page));
    router.push(`/listings?${newParams.toString()}`);
  };

  const COUNTRY_META: Record<string, { isoCode: string; label: string }> = {
    UAE:    { isoCode: 'AE', label: 'UAE' },
    UGANDA: { isoCode: 'UG', label: 'Uganda' },
    KENYA:  { isoCode: 'KE', label: 'Kenya' },
    CHINA:  { isoCode: 'CN', label: 'China' },
  };
  const activeCountry = params?.get('country') || country;
  const activeMeta    = COUNTRY_META[activeCountry];
  const activeQ       = params?.get('q') || '';
  const activeCat     = params?.get('category') || '';
  const placement     = params?.get('placement') ?? '';

  const PLACEMENT_LABELS: Record<string, { title: string; subtitle: string; icon: string }> = {
    FEATURED_DEAL:      { title: "Today's Deals",    subtitle: "Hand-picked deals and featured offers.", icon: '🔥' },
    FLASH_SALE:         { title: 'Flash Sales',       subtitle: "Limited-time flash sales — grab them before they're gone!", icon: '⚡' },
    LATEST_COLLECTIONS: { title: 'New Collections',  subtitle: 'Freshly added collections from our best stores.', icon: '✨' },
  };
  const placementMeta = PLACEMENT_LABELS[placement];

  const pageTitle = placementMeta?.title
    ?? (activeQ ? `Results for "${activeQ}"` : activeMeta ? `${activeMeta.label} Listings` : 'Browse All Listings');
  const pageSubtitle = placementMeta?.subtitle
    ?? (activeCat ? `Showing ${activeCat} listings${activeMeta ? ` in ${activeMeta.label}` : ''}` : 'Discover products from verified sellers.');

  return (
    <div>
      {/* Hero header */}
      <div className="relative overflow-hidden bg-gradient-to-br from-sky-500 via-blue-600 to-purple-700 py-5 sm:py-8 px-4">
        <div className="absolute inset-0 opacity-10" style={{ backgroundImage: 'radial-gradient(circle at 25% 50%, #ffffff30 0%, transparent 60%)' }} />
        <div className="relative max-w-4xl mx-auto text-center flex flex-col items-center gap-2">
          {activeMeta && !placement && (
            <div className="rounded-lg overflow-hidden ring-2 ring-white/40 shadow-md">
              <FlagIcon code={activeMeta.isoCode} size={36} />
            </div>
          )}
          {placementMeta && <span className="text-4xl" aria-hidden="true">{placementMeta.icon}</span>}
          <h1 className="text-xl sm:text-2xl font-bold text-white mb-1">{pageTitle}</h1>
          <p className="text-sky-100 text-xs sm:text-sm">{pageSubtitle}</p>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-3 sm:px-4 py-3 sm:py-5">
        {/* Search bar */}
        <div className="mb-3 sm:mb-4">
          <SearchBar
            initialQ={params ? params.get('q') || '' : ''}
            initialLocation={params ? params.get('location') || '' : ''}
          />
        </div>

        {/* Active filters summary */}
        {(activeQ || activeCat) && (
          <div className="flex flex-wrap gap-2 mb-3">
            {activeQ && (
              <span className="inline-flex items-center gap-1.5 bg-sky-100 text-sky-700 text-xs font-semibold px-3 py-1 rounded-full">
                🔍 &quot;{activeQ}&quot;
                <button
                  type="button"
                  onClick={() => {
                    const p = new URLSearchParams(params ? params.toString() : '');
                    p.delete('q');
                    router.push(`/listings?${p.toString()}`);
                  }}
                  className="ml-1 hover:text-sky-900"
                >×</button>
              </span>
            )}
            {activeCat && (
              <span className="inline-flex items-center gap-1.5 bg-violet-100 text-violet-700 text-xs font-semibold px-3 py-1 rounded-full capitalize">
                📂 {activeCat}
                <button
                  type="button"
                  onClick={() => {
                    const p = new URLSearchParams(params ? params.toString() : '');
                    p.delete('category');
                    router.push(`/listings?${p.toString()}`);
                  }}
                  className="ml-1 hover:text-violet-900"
                >×</button>
              </span>
            )}
          </div>
        )}

        {/* Mobile filter toggle */}
        <div className="flex items-center justify-between mb-3 md:hidden">
          <p className="text-gray-500 text-sm font-medium">
            <span className="text-gray-900 font-bold">{total}</span> listings
          </p>
          <button
            onClick={() => setFilterOpen(true)}
            className="flex items-center gap-1.5 bg-white border border-gray-200 text-gray-700 px-3 py-1.5 rounded-xl text-sm font-semibold hover:bg-gray-50 transition-colors shadow-sm"
          >
            <svg className="w-4 h-4 text-sky-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2a1 1 0 01-.293.707L13 13.414V19a1 1 0 01-.553.894l-4 2A1 1 0 017 21v-7.586L3.293 6.707A1 1 0 013 6V4z" />
            </svg>
            Filters
          </button>
        </div>

        <div className="flex gap-5">
          <FilterSidebar categories={categories} isOpen={filterOpen} onClose={() => setFilterOpen(false)} />

          <div className="flex-1 min-w-0">
            <div className="hidden md:flex items-center justify-between mb-4">
              <p className="text-gray-500 text-sm">
                <span className="text-gray-900 font-bold">{total}</span> listings found
              </p>
              <div className="flex items-center gap-2">
                <label htmlFor="sort-top" className="text-xs text-gray-500 whitespace-nowrap">Sort by:</label>
                <select
                  id="sort-top"
                  value={activeSort}
                  onChange={(e) => {
                    const newParams = new URLSearchParams(params ? params.toString() : '');
                    newParams.set('sort', e.target.value);
                    newParams.set('page', '1');
                    router.push(`/listings?${newParams.toString()}`);
                  }}
                  className="text-sm border border-gray-200 rounded-lg px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-sky-300 bg-white text-gray-700"
                >
                  <option value="recommended">Recommended</option>
                  {activeQ && <option value="relevance">Best Match</option>}
                  <option value="createdAt">Most Recent</option>
                  <option value="price_asc">Lowest Price</option>
                  <option value="price_desc">Highest Price</option>
                  <option value="views">Most Popular</option>
                </select>
              </div>
            </div>

            <ListingGrid listings={listings} loading={loading} />

            {!loading && pages > 1 && (
              <div className="flex flex-wrap justify-center gap-1.5 mt-8">
                <button
                  onClick={() => goToPage(Math.max(1, currentPage - 1))}
                  disabled={currentPage === 1}
                  className="px-3 py-2 rounded-lg text-sm font-medium bg-white border border-gray-200 text-gray-600 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                >← Prev</button>
                {Array.from({ length: pages }, (_, i) => i + 1)
                  .filter((p) => Math.abs(p - currentPage) <= 2 || p === 1 || p === pages)
                  .reduce<(number | 'ellipsis')[]>((acc, p, idx, arr) => {
                    if (idx > 0 && p - (arr[idx - 1] as number) > 1) acc.push('ellipsis');
                    acc.push(p);
                    return acc;
                  }, [])
                  .map((p, i) =>
                    p === 'ellipsis'
                      ? <span key={`e-${i}`} className="flex items-center px-1 text-gray-400 text-sm">…</span>
                      : (
                        <button
                          key={p}
                          onClick={() => goToPage(p as number)}
                          className={`w-9 h-9 rounded-lg text-sm font-semibold transition-all ${
                            p === currentPage ? 'bg-sky-600 text-white shadow-md' : 'bg-white text-gray-600 border border-gray-200 hover:bg-gray-50 hover:border-sky-200'
                          }`}
                        >{p}</button>
                      )
                  )}
                <button
                  onClick={() => goToPage(Math.min(pages, currentPage + 1))}
                  disabled={currentPage === pages}
                  className="px-3 py-2 rounded-lg text-sm font-medium bg-white border border-gray-200 text-gray-600 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                >Next →</button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default function ListingsPage() {
  return (
    <Suspense fallback={
      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="h-12 bg-gray-100 animate-pulse rounded-xl mb-6" />
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
          {Array.from({ length: 12 }).map((_, i) => (
            <div key={i} className="bg-white rounded-xl overflow-hidden border border-gray-100">
              <div className="aspect-[4/3] bg-gray-200 animate-pulse" />
              <div className="p-2.5 space-y-2">
                <div className="h-3 bg-gray-200 animate-pulse rounded-full" />
                <div className="h-4 bg-gray-200 animate-pulse rounded-full w-1/2" />
              </div>
            </div>
          ))}
        </div>
      </div>
    }>
      <ListingsContent />
    </Suspense>
  );
}

