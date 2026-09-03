'use client';

import { useState, useEffect, useCallback } from 'react';
import { useCart } from '@/context/CartContext';
import { useToast } from '@/components/ui/Toast';
import type { Listing } from '@/lib/types';

interface Props {
  listing: Listing;
  /** Slightly smaller footprint when used inside compact cards (e.g. the mobile deals popup) */
  size?: 'sm' | 'md';
  /**
   * 'overlay' (default) — floating white/red circle docked in the image's
   * top-right corner, used by the deal-rail style cards (FlashDeals,
   * FeaturedProductCard, BackToSchoolSection, MobileSpecialOffersPopup).
   * 'inline' — solid site-red circle meant to sit next to the price row in
   * ListingCard: it toasts a confirmation and then hides itself once the
   * item is added, rather than staying on-card as a persistent toggle.
   */
  variant?: 'overlay' | 'inline';
}

/**
 * "+" button for adding a listing to the cart directly from a listing card,
 * without navigating to the listing detail page.
 *
 * The button reflects the listing's live availability rather than being
 * permanently disabled after the first click: SOLD/EXPIRED/HIDDEN/REJECTED
 * listings and listings with zero tracked stock render a disabled
 * "unavailable" state instead of an actionable "+".
 */
export function QuickAddButton({ listing, size = 'md', variant = 'overlay' }: Props) {
  const { items, addToCart } = useCart();
  const { success } = useToast();
  const [justAdded, setJustAdded] = useState(false);

  const alreadyInCart = items.some((i) => i.listing.id === listing.id);
  const added = alreadyInCart || justAdded;

  // Unavailable: not currently purchasable. Stock is only enforced when the
  // listing tracks it (stock === undefined means the seller isn't tracking
  // inventory for this item, so it stays available on status alone).
  const outOfStock = typeof listing.stock === 'number' && listing.stock <= 0;
  const unavailable = listing.status !== 'ACTIVE' || outOfStock;
  const unavailableReason =
    listing.status === 'SOLD' ? 'Already sold'
    : listing.status === 'EXPIRED' ? 'Listing expired'
    : listing.status === 'HIDDEN' || listing.status === 'REJECTED' ? 'No longer available'
    : listing.status === 'PENDING' ? 'Pending approval'
    : outOfStock ? 'Out of stock'
    : 'Unavailable';

  // Reset the "just added" pulse once the item is confirmed in the cart state.
  useEffect(() => {
    if (alreadyInCart) setJustAdded(false);
  }, [alreadyInCart]);

  const handleAdd = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault();
      e.stopPropagation();
      if (unavailable) return;
      addToCart(listing);
      setJustAdded(true);
      if (variant === 'inline') success(`Added "${listing.title}" to cart`);
    },
    [addToCart, listing, unavailable, variant, success]
  );

  // 'inline' next to the price: once it's in the cart there's nothing more
  // for this control to do here (the cart drawer/page is the place to
  // remove it), so it hides itself entirely rather than sitting there as a
  // stale checkmark — the toast already confirmed the add.
  if (variant === 'inline' && added && !unavailable) return null;

  const dims = size === 'sm' ? 'w-6 h-6' : 'w-7 h-7 xs:w-8 xs:h-8';
  const iconDims = size === 'sm' ? 'w-3 h-3' : 'w-3.5 h-3.5 xs:w-4 xs:h-4';
  const badgeDims = size === 'sm' ? 'w-2.5 h-2.5' : 'w-3 h-3';

  if (variant === 'inline') {
    const inlineDims = size === 'sm' ? 'w-6 h-6' : 'w-7 h-7';
    const inlineIconDims = size === 'sm' ? 'w-3 h-3' : 'w-3.5 h-3.5';
    return (
      <button
        type="button"
        onClick={handleAdd}
        disabled={unavailable}
        aria-label={unavailable ? unavailableReason : 'Add to cart'}
        title={unavailable ? unavailableReason : 'Add to cart'}
        className={`${inlineDims} shrink-0 rounded-full flex items-center justify-center shadow-sm transition-colors ${
          unavailable
            ? 'bg-gray-200 text-gray-400 cursor-not-allowed'
            : 'bg-red-600 text-white hover:bg-red-700 active:scale-95'
        }`}
      >
        {unavailable ? (
          <svg className={inlineIconDims} fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        ) : (
          <svg className={inlineIconDims} fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v16m8-8H4" />
          </svg>
        )}
      </button>
    );
  }

  return (
    <div className="relative inline-flex">
      <button
        type="button"
        onClick={handleAdd}
        disabled={unavailable}
        aria-label={unavailable ? unavailableReason : added ? 'Added to cart' : 'Add to cart'}
        title={unavailable ? unavailableReason : added ? 'Added to cart' : 'Add to cart'}
        className={`${dims} rounded-full flex items-center justify-center shadow transition-colors ${
          unavailable
            ? 'bg-gray-200 text-gray-400 border border-gray-200 cursor-not-allowed'
            : added
            ? 'bg-white text-emerald-600 border border-emerald-200'
            : 'bg-white/95 text-gray-700 border border-white/80 hover:bg-red-500 hover:text-white hover:border-red-500'
        }`}
      >
        {unavailable ? (
          <svg className={iconDims} fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        ) : (
          <svg className={iconDims} fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v16m8-8H4" />
          </svg>
        )}
      </button>

      {/* Small green "already added" tick — bottom-right of the + button */}
      {!unavailable && added && (
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

