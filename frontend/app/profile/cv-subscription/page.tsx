'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

/**
 * CV subscriptions have been removed.
 * CV services are free to use; users pay only when they download.
 * Redirect anyone landing here to the CV builder.
 */
export default function CVSubscriptionPage() {
  const router = useRouter();
  useEffect(() => { router.replace('/cv-generator'); }, [router]);
  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="text-center">
        <p className="text-sm text-gray-500 mb-1">Redirecting…</p>
        <p className="text-xs text-gray-400">CV subscriptions are no longer required. Build for free, pay only to download.</p>
      </div>
    </div>
  );
}
