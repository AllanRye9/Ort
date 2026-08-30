'use client';

import { useEffect, useState } from 'react';
import { resolveImageUrl } from '@/lib/utils';
import { API_URL } from '@/lib/apiUrl';

export default function BackgroundImage() {
  const [imageUrl, setImageUrl] = useState<string | null>(null);

  useEffect(() => {
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), 5000);

    fetch(`${API_URL}/api/site-media?section=background`, {
      signal: controller.signal,
    })
      .then((response) => (response.ok ? response.json() : null))
      .then((data) => {
        const firstMedia = Array.isArray(data?.media)
          ? data.media.find((item: { cdnUrl?: string | null }) => item?.cdnUrl)
          : null;
        if (firstMedia?.cdnUrl) setImageUrl(resolveImageUrl(firstMedia.cdnUrl));
      })
      .catch(() => {})
      .finally(() => window.clearTimeout(timeout));

    return () => {
      window.clearTimeout(timeout);
      controller.abort();
    };
  }, []);

  if (!imageUrl) return null;

  return (
    <>
      <div
        className="pointer-events-none fixed inset-0 -z-20 bg-cover bg-center bg-no-repeat"
        style={{ backgroundImage: `url("${imageUrl}")` }}
      />
      <div className="site-bg-overlay pointer-events-none fixed inset-0 -z-10" />
    </>
  );
}
