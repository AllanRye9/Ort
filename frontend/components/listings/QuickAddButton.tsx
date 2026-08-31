'use client';

import { useState, useEffect, useCallback } from 'react';
import { useCart } from '@/context/CartContext';
import type { Listing } from '@/lib/types';

interface Props {
  listing: Listing;
  /** Slightly smaller footprint when used inside compact cards (e.g. the mobile deals popup) */
  size?: 'sm' | 'md';
}

/**
 * Floating "+" button for adding a listing to the cart directly from a
 * listing card, without navigating to the listing detail page. Once the
 * item is in the cart it stays visually marked with a small green check
 * badge at the bottom-right of the button, so shoppers can see at a glance
 * which items they've already added while browsing a grid.
 */
export function QuickAddButton({ listing, size = 'md' }: Props) {
  const { items, addToCart } = useCart();
  const [justAdded, setJustAdded] = useState(false);

  const alreadyInCart = items.some((i) => i.listing.id === listing.id);
  const added = alreadyInCart || justAdded;

  // Reset the "just added" pulse once the item is confirmed in the cart state.
  useEffect(() => {
    if (alreadyInCart) setJustAdded(false);
  }, [alreadyInCart]);

  const handleAdd = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault();
      e.stopPropagation();
      addToCart(listing);
      setJustAdded(true);
    },
    [addToCart, listing]
  );

  const dims = size === 'sm' ? 'w-6 h-6' : 'w-7 h-7 xs:w-8 xs:h-8';
  const iconDims = size === 'sm' ? 'w-3 h-3' : 'w-3.5 h-3.5 xs:w-4 xs:h-4';
  const badgeDims = size === 'sm' ? 'w-2.5 h-2.5' : 'w-3 h-3';

  return (
    <div className="relative inline-flex">
      <button
        type="button"
        onClick={handleAdd}
        aria-label={added ? 'Added to cart' : 'Add to cart'}
        title={added ? 'Added to cart' : 'Add to cart'}
        className={`${dims} rounded-full flex items-center justify-center shadow transition-colors ${
          added
            ? 'bg-white text-emerald-600 border border-emerald-200'
            : 'bg-white/95 text-gray-700 border border-white/80 hover:bg-red-500 hover:text-white hover:border-red-500'
        }`}
      >
        <svg className={iconDims} fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2.5}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v16m8-8H4" />
        </svg>
      </button>

      {/* Small green "already added" tick — bottom-right of the + button */}
      {added && (
        <span
          className={`absolute -bottom-1 -right-1 ${badgeDims} rounded-full bg-emerald-500 ring-2 ring-white flex items-center justify-center`}
          aria-hidden="true"
        >
          <svg className="w-full h-full p-[2px] text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={3.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
          </svg>
        </span>
      )}
    </div>
  );
}
