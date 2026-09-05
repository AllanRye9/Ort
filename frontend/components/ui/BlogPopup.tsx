'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { api } from '@/lib/api';
import { resolveImageUrl } from '@/lib/utils';

interface BlogPopupPost {
  id: string;
  title: string;
  slug: string;
  excerpt: string | null;
  featuredImage: string | null;
}

interface BlogPopupResponse {
  enabled: boolean;
  intervalSeconds?: number;
  post?: BlogPopupPost;
}

/**
 * Homepage-only popup that surfaces a blog post (admin-configured from
 * /admin/settings → Homepage Blog Popup). Fully admin-gated: renders
 * nothing until GET /api/blog/popup confirms the feature is on and a
 * publishable post exists.
 *
 * Cadence: the popup first appears `intervalSeconds` after this component
 * mounts, and — if dismissed — reappears `intervalSeconds` after each
 * dismissal for as long as the shopper stays on the homepage. This mirrors
 * a plain repeating reminder rather than a one-per-visit interruption,
 * which is what "admin-configurable interval" calls for.
 */
export default function BlogPopup() {
  const [post, setPost] = useState<BlogPopupPost | null>(null);
  const [intervalSeconds, setIntervalSeconds] = useState(60);
  const [open, setOpen] = useState(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const clearTimer = () => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }
  };

  const scheduleNextShow = useCallback((delaySeconds: number) => {
    clearTimer();
    timerRef.current = setTimeout(() => setOpen(true), Math.max(0, delaySeconds) * 1000);
  }, []);

  // Load the admin-configured popup once on mount.
  useEffect(() => {
    let cancelled = false;
    api
      .get<BlogPopupResponse>('/blog/popup')
      .then(({ data }) => {
        if (cancelled || !data.enabled || !data.post) return;
        setPost(data.post);
        setIntervalSeconds(data.intervalSeconds || 60);
      })
      .catch(() => {
        // Best-effort — popup simply never appears if the request fails.
      });
    return () => { cancelled = true; };
  }, []);

  // Once we know the post + interval, arm the first appearance.
  useEffect(() => {
    if (!post) return;
    scheduleNextShow(intervalSeconds);
    return clearTimer;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [post, intervalSeconds]);

  const close = () => {
    setOpen(false);
    scheduleNextShow(intervalSeconds);
  };

  if (!post || !open) return null;

  const image = resolveImageUrl(post.featuredImage || '');

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/50" role="dialog" aria-modal="true" aria-label="Blog post">
      <div className="relative w-full max-w-sm bg-white rounded-2xl shadow-2xl overflow-hidden animate-scale-in">
        <button
          type="button"
          onClick={close}
          aria-label="Close"
          className="absolute top-3 right-3 z-10 w-8 h-8 rounded-full bg-white/90 shadow flex items-center justify-center text-gray-600 hover:text-gray-900"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>

        {image && (
          <div className="relative w-full h-44">
            <Image src={image} alt={post.title} fill className="object-cover" sizes="384px" />
          </div>
        )}

        <div className="p-5">
          <p className="text-[10px] font-bold text-premium-gold uppercase tracking-wider mb-1">From our blog</p>
          <h3 className="text-lg font-extrabold text-gray-900 leading-snug mb-2">{post.title}</h3>
          {post.excerpt && (
            <p className="text-sm text-gray-500 leading-relaxed mb-4 line-clamp-3">{post.excerpt}</p>
          )}
          <Link
            href={`/blog/${post.slug}`}
            onClick={close}
            className="inline-flex items-center gap-1.5 text-sm font-semibold text-white bg-premium-gold hover:bg-premium-gold-dark px-4 py-2 rounded-lg transition-colors"
          >
            Read more
            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
            </svg>
          </Link>
        </div>
      </div>
    </div>
  );
}
