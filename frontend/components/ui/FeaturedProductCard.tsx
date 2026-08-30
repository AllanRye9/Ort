import Link from 'next/link';
import Image from 'next/image';
import { resolveImageUrl } from '@/lib/utils';
import { Listing } from '@/lib/types';

interface FeaturedProductCardProps {
  storeName?: string;
  title?: string;
  description?: string;
  originalPrice?: string;
  discountedPrice?: string;
  /** Optional note shown under the price, e.g. "Listed at AED 100" when the
   *  displayed price has been currency-converted from what the seller posted. */
  listedPriceNote?: string;
  imageUrl?: string;
  href?: string;
  isHandpicked?: boolean;
  className?: string;
  listing?: Listing;
}

export default function FeaturedProductCard({
  storeName,
  title = 'Featured Item',
  description,
  originalPrice,
  discountedPrice,
  listedPriceNote,
  imageUrl,
  href,
  isHandpicked = false,
  className = '',
  listing,
}: FeaturedProductCardProps & { className?: string }) {
  // When a listing is provided its URL always takes precedence over an explicit href.
  const resolvedHref = listing ? `/listings/${listing.id}` : href;

  const navigable = !!resolvedHref;

  const cardBody = (
    <div className={`bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden transition-all duration-300 shine-card${navigable ? ' hover:shadow-lg hover:-translate-y-0.5' : ''}`}>
      {/* Image — no text overlaid */}
      <div className="aspect-[4/3] relative overflow-hidden bg-gray-50">
        {imageUrl ? (
          <Image
            src={resolveImageUrl(imageUrl)}
            alt={title}
            fill
            className="object-cover group-hover:scale-105 transition-transform duration-300"
            sizes="(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 20vw"
            loading="lazy"
          />
        ) : (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-1.5 bg-gray-100">
            <svg className="w-8 h-8 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
            <p className="text-[9px] text-gray-400 text-center px-2">No image available</p>
          </div>
        )}
        {/* Subtle hover overlay */}
        <div className="absolute inset-0 bg-gradient-to-t from-black/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none" />
        {/* Handpicked badge — bottom corner, small and subtle */}
        {isHandpicked && (
          <div className="absolute bottom-1.5 right-1.5">
            <span className="bg-white/90 text-red-600 text-[9px] font-bold px-1.5 py-0.5 rounded-full backdrop-blur-sm shadow-sm flex items-center gap-0.5">
              <svg className="w-2 h-2" fill="currentColor" viewBox="0 0 20 20"><path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" /></svg>
              Pick
            </span>
          </div>
        )}
      </div>

      {/* Text content — all BELOW the image, neatly arranged */}
      <div className="p-2.5 sm:p-3">
        {storeName && (
          <p className="text-[10px] sm:text-xs text-gray-400 font-medium mb-0.5 truncate">{storeName}</p>
        )}
        <h3 className="text-xs sm:text-sm font-bold text-gray-900 line-clamp-2 mb-1 leading-snug">{title}</h3>
        {description && (
          <p className="text-[10px] sm:text-xs text-gray-500 line-clamp-2 mb-1.5 leading-relaxed">{description}</p>
        )}
        {(originalPrice || discountedPrice) && (
          <div className="flex items-center gap-2 flex-wrap mt-1">
            {originalPrice && (
              <span className="text-gray-400 line-through text-[10px] sm:text-xs tabular-nums">{originalPrice}</span>
            )}
            {discountedPrice && (
              <span className="animate-price-pop text-[#F55906] font-extrabold text-sm sm:text-base tabular-nums">{discountedPrice}</span>
            )}
          </div>
        )}
        {listedPriceNote && (
          <p className="text-[9px] sm:text-[10px] text-gray-400 mt-0.5 leading-none">{listedPriceNote}</p>
        )}
      </div>
    </div>
  );

  if (resolvedHref) {
    return <Link href={resolvedHref} className={`block group ${className}`}>{cardBody}</Link>;
  }
  return <div className={className}>{cardBody}</div>;
}
