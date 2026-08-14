'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import Link from 'next/link';
import { resolveImageUrl } from '@/lib/utils';

interface Banner {
  id: string;
  cdnUrl: string;
  title?: string;
  altText?: string;
  linkUrl?: string;
  dimensions: string;
  sortOrder: number;
}

interface Props {
  className?: string;
}

/**
 * StickyHeaderBanner
 *
 * Displays a promotional banner (935 × 45 px) centred in a full-width strip.
 * The outer strip stretches edge-to-edge with a matching background colour so
 * there is never a visible dead-zone on wide screens.
 *
 * Supports images AND animated GIFs — rendered as a plain <img> tag so that
 * GIF animation is preserved (Next/Image re-encodes GIFs as static WebP).
 *
 * The 935 px slot itself is filled exactly with object-fill / width+height attrs.
 */
export default function StickyHeaderBanner({ className = '' }: Props) {
  const [banners, setBanners] = useState<Banner[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  // Background colour sampled from first pixel of banner (fallback: slate-900)
  const [bgColor, setBgColor] = useState('#0f172a');

  useEffect(() => {
    const fetchBanners = async () => {
      try {
        setIsLoading(true);
            const { data } = await api.get('/site-media?section=sticky-header');
        if (data) {
          const items: Banner[] = data.media || data.banners || [];
          if (items.length > 0) setBanners(items);
        }
      } catch {
        // silently fall back — no banners shown
      } finally {
        setIsLoading(false);
      }
    };
    fetchBanners();
  }, []);

  /* Auto-rotate every 8 s when multiple banners exist */
  useEffect(() => {
    if (banners.length <= 1) return;
    const interval = setInterval(() => {
      setCurrentIndex((prev) => (prev + 1) % banners.length);
    }, 8000);
    return () => clearInterval(interval);
  }, [banners.length]);

  /* Sample the edge pixel of the current banner to fill the outer strip */
  useEffect(() => {
    const current = banners[currentIndex];
    if (!current) return;
    const img = new window.Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      try {
        const canvas = document.createElement('canvas');
        canvas.width = 1; canvas.height = 1;
        const ctx = canvas.getContext('2d');
        if (!ctx) return;
        ctx.drawImage(img, 0, 0, 1, 1);
        const [r, g, b] = ctx.getImageData(0, 0, 1, 1).data;
        setBgColor(`rgb(${r},${g},${b})`);
      } catch {
        setBgColor('#0f172a');
      }
    };
    img.onerror = () => setBgColor('#0f172a');
    img.src = resolveImageUrl(current.cdnUrl);
  }, [banners, currentIndex]);

  if (isLoading || banners.length === 0) return null;

  const current = banners[currentIndex];
  if (!current) return null;

  const isGif = current.cdnUrl.toLowerCase().includes('.gif');

  /* The inner 935×45 slot */
  const bannerSlot = (
    /*
     * Full-width strip — background matches the banner edge colour so there
     * is no visible dead-zone on screens wider than 935 px.
     */
    <div
      className="relative w-full flex justify-center items-center overflow-hidden"
      style={{ height: '45px', backgroundColor: bgColor, transition: 'background-color 0.4s ease' }}
    >
      {/* 935 px centred slot — exact fill, no letterbox */}
      <div className="relative shrink-0" style={{ width: '935px', maxWidth: '100vw', height: '45px' }}>
        {isGif ? (
          /* Plain <img> preserves GIF animation — Next/Image would strip it */
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={resolveImageUrl(current.cdnUrl)}
            alt={current.altText || current.title || 'Promotional banner'}
            width={935}
            height={45}
            style={{ width: '100%', height: '45px', objectFit: 'fill', display: 'block' }}
          />
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={resolveImageUrl(current.cdnUrl)}
            alt={current.altText || current.title || 'Promotional banner'}
            width={935}
            height={45}
            style={{ width: '100%', height: '45px', objectFit: 'fill', display: 'block' }}
            loading="eager"
          />
        )}
      </div>

      {/* Dot indicators when multiple banners */}
      {banners.length > 1 && (
        <div className="absolute bottom-1 left-1/2 -translate-x-1/2 z-10 flex gap-1">
          {banners.map((_, idx) => (
            <button
              key={idx}
              onClick={(e) => { e.preventDefault(); e.stopPropagation(); setCurrentIndex(idx); }}
              className={`h-1.5 rounded-full transition-all ${
                idx === currentIndex ? 'bg-white w-4' : 'bg-white/50 hover:bg-white/75 w-1.5'
              }`}
              aria-label={`Go to banner ${idx + 1}`}
            />
          ))}
        </div>
      )}
    </div>
  );

  if (current.linkUrl) {
    return (
      <Link
        href={current.linkUrl}
        target="_blank"
        rel="noopener noreferrer"
        className={`block w-full ${className}`}
        style={{ height: '45px' }}
      >
        {bannerSlot}
      </Link>
    );
  }

  return (
    <div className={`w-full ${className}`} style={{ height: '45px' }}>
      {bannerSlot}
    </div>
  );
}
