/**
 * CountryFlashDeals
 * Re-fetches flash-sale listings filtered by selected country on every country change.
 */
'use client';

import { useEffect, useState } from 'react';
import { useCountry } from '@/context/CountryContext';
import FlashDeals from '@/components/ui/FlashDeals';
import type { Listing } from '@/lib/types';
import { API_URL } from '@/lib/api';


interface SiteMediaItem {
  id: string;
  cdnUrl: string;
  title?: string | null;
  shortDescription?: string | null;
  price?: number | null;
  originalPrice?: number | null;
  currency?: string | null;
  altText?: string | null;
  linkUrl?: string | null;
  section?: string;
}

interface Props {
  initialListings: Listing[];
  flashMedia: SiteMediaItem[];
}

export default function CountryFlashDeals({ initialListings, flashMedia }: Props) {
  const { country } = useCountry();
  const [listings, setListings] = useState<Listing[]>(initialListings);

  useEffect(() => {
    let cancelled = false;
    fetch(`${API_URL}/api/listings/flash-sales?limit=6&country=${country}`)
      .then((r) => r.ok ? r.json() : { listings: [] })
      .then((data) => { if (!cancelled) setListings(data.listings || []); })
      .catch(() => { if (!cancelled) setListings([]); });
    return () => { cancelled = true; };
  }, [country]);

  return <FlashDeals listings={listings} media={flashMedia as Parameters<typeof FlashDeals>[0]['media']} />;
}
