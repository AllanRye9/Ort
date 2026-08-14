'use client';

import { useState, useEffect } from 'react';
import { api } from '@/lib/api';

/**
 * Fetches ACTIVE listing counts per category/subcategory slug, scoped to a
 * country, from GET /categories/active-counts. Used by the public category
 * pages (CategoryPageTemplate's "Browse by Type" grid and
 * CategorySubcategoryTemplate's "Other Categories" list) as well as the
 * global navigation (CategoryBar's mega menus, the home page's "All
 * Categories" sidebar) to hide categories/subcategories that don't have any
 * listings yet.
 *
 * IMPORTANT: this hook is for public discovery surfaces only. It must never
 * be used to filter the "create listing" category picker or any admin
 * category screen — sellers need to be able to see and post into an empty
 * subcategory, otherwise it could never receive its first listing.
 *
 * On a failed fetch, `counts` stays `null` (not `{}`) so callers can tell
 * "we don't know yet / the request failed" apart from "we know these are
 * genuinely empty" — the former should fall back to showing everything
 * rather than hiding the whole page's subcategories.
 */

// Module-level cache shared across components/pages, keyed by country.
// Short TTL: this only gates presentational visibility, so a brief staleness
// window (a subcategory appearing/disappearing a few seconds late) is a fine
// trade-off for not re-fetching on every render across a full category page.
const CACHE_TTL = 60 * 1000; // 1 minute
const _cache = new Map<string, { counts: Record<string, number>; expiry: number }>();

// De-dupes concurrent fetches for the same country. The global nav
// (CategoryBar, the home page's CategorySideNav) and a page's own category
// template can all mount this hook within the same tick — without this,
// each would fire its own request to /categories/active-counts before any
// of them had a chance to populate the cache above.
const _inflight = new Map<string, Promise<Record<string, number>>>();

function fetchCounts(country: string): Promise<Record<string, number>> {
  const cacheKey = country || '__global__';
  const existing = _inflight.get(cacheKey);
  if (existing) return existing;

  const request = api
    .get('/categories/active-counts', { params: country ? { country } : undefined })
    .then(({ data }) => {
      const fetched = (data?.counts || {}) as Record<string, number>;
      _cache.set(cacheKey, { counts: fetched, expiry: Date.now() + CACHE_TTL });
      return fetched;
    })
    .finally(() => {
      _inflight.delete(cacheKey);
    });

  _inflight.set(cacheKey, request);
  return request;
}

export function useActiveSubcategoryCounts(country: string) {
  const [counts, setCounts] = useState<Record<string, number> | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const cacheKey = country || '__global__';
    const cached = _cache.get(cacheKey);
    if (cached && cached.expiry > Date.now()) {
      setCounts(cached.counts);
      setLoading(false);
      return;
    }

    let cancelled = false;
    setLoading(true);

    fetchCounts(country)
      .then((fetched) => {
        if (cancelled) return;
        setCounts(fetched);
      })
      .catch((err) => {
        if (cancelled) return;
        // Don't cache failures, and don't treat "we couldn't check" as
        // "these are all empty" — leave counts null so callers show
        // everything rather than hiding the whole subcategory grid.
        console.error('[useActiveSubcategoryCounts] failed to load counts:', err?.response?.status, err?.message);
        setCounts(null);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => { cancelled = true; };
  }, [country]);

  return { counts, loading };
}
