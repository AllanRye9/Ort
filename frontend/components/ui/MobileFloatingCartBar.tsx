'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useCart } from '@/context/CartContext';
import { useCountry } from '@/context/CountryContext';
import { formatCurrency } from '@/lib/utils';

/**
 * Persistent "View cart" bar docked just above the mobile bottom nav,
 * matching the reference mobile grocery-app layout: an item-count badge,
 * "View cart" label, and running total in a single tappable pill. Only
 * rendered once there's something in the cart — an empty-cart bar has
 * nothing useful to say and just eats screen space.
 *
 * Deliberately absent from /cart itself (the destination this bar links
 * to) and from /admin (which has no cart concept at all).
 */
export default function MobileFloatingCartBar() {
  const { totalItems, totalPrice } = useCart();
  const { currency } = useCountry();
  const pathname = usePathname();

  if (totalItems === 0) return null;
  if (pathname === '/cart' || pathname?.startsWith('/checkout') || pathname?.startsWith('/admin')) return null;

  return (
    <div
      className="fixed inset-x-0 z-40 px-3 md:hidden"
      style={{ bottom: 'calc(64px + env(safe-area-inset-bottom, 0px))' }}
    >
      <Link
        href="/cart"
        className="flex items-center justify-between gap-3 w-full max-w-md mx-auto bg-red-600 hover:bg-red-700 active:scale-[0.98] text-white rounded-full shadow-lg shadow-red-600/30 pl-2 pr-4 py-2 transition-all"
        aria-label={`View cart, ${totalItems} item${totalItems === 1 ? '' : 's'}, total ${formatCurrency(totalPrice, currency)}`}
      >
        <span className="flex items-center gap-2 min-w-0">
          <span className="shrink-0 w-7 h-7 rounded-full bg-white/20 flex items-center justify-center text-xs font-extrabold tabular-nums">
            {totalItems}
          </span>
          <span className="font-semibold text-sm truncate">View cart</span>
        </span>
        <span className="font-bold text-sm tabular-nums shrink-0">{formatCurrency(totalPrice, currency)}</span>
      </Link>
    </div>
  );
}
