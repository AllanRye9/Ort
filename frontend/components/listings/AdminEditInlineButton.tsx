'use client';

import { useState } from 'react';
import Link from 'next/link';

interface Props {
  listingId: string;
  size?: 'sm' | 'md';
}

/**
 * Admin-only inline counterpart to QuickAddButton's `inline` variant — sits
 * in the same slot next to the price on ListingCard, but for an admin
 * viewer it opens the editor instead of adding to cart.
 *
 * "Handling the cases possible for admin editing ongoing": since this is a
 * plain navigation (no server call that can fail on its own), the only
 * state worth surfacing is the transition itself — the pen hides and a
 * small spinner takes its place for the moment before the route change
 * unmounts this card. If the click is somehow interrupted (e.g. the user
 * cancels navigation), the timeout below restores the pen rather than
 * leaving it stuck spinning forever.
 */
export function AdminEditInlineButton({ listingId, size = 'md' }: Props) {
  const [navigating, setNavigating] = useState(false);

  const dims = size === 'sm' ? 'w-6 h-6' : 'w-7 h-7';
  const iconDims = size === 'sm' ? 'w-3 h-3' : 'w-3.5 h-3.5';

  const handleClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    setNavigating(true);
    // Safety net: if navigation gets interrupted (back button, blocked
    // popup, etc.) restore the pen instead of leaving the card stuck.
    window.setTimeout(() => setNavigating(false), 4000);
  };

  if (navigating) {
    return (
      <span
        className={`${dims} shrink-0 rounded-full flex items-center justify-center bg-red-100 text-red-600`}
        role="status"
        aria-label="Opening editor"
        title="Opening editor…"
      >
        <svg className={`${iconDims} animate-spin`} fill="none" viewBox="0 0 24 24">
          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
        </svg>
      </span>
    );
  }

  return (
    <Link
      href={`/listings/create?edit=${listingId}`}
      onClick={handleClick}
      aria-label="Edit listing (admin)"
      title="Edit listing (admin)"
      className={`${dims} shrink-0 rounded-full flex items-center justify-center shadow-sm bg-red-600 text-white hover:bg-red-700 active:scale-95 transition-colors`}
    >
      <svg className={iconDims} fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
      </svg>
    </Link>
  );
}
