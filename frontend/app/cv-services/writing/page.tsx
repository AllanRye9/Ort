'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

/**
 * CV Writing now runs entirely through the in-platform CV builder.
 * The old "Choose Your Package" pricing-tier step has been removed —
 * there is nothing to pick. Build for free, pay only when you download.
 * Send anyone landing on this route straight to the page that starts
 * with "CV, Certificates & Documents".
 */
export default function CVWritingPage() {
  const router = useRouter();
  useEffect(() => { router.replace('/cv-generator'); }, [router]);
  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="text-center">
        <p className="text-sm text-gray-500 mb-1">Redirecting…</p>
        <p className="text-xs text-gray-400">Packages have been removed. Build for free, pay only to download.</p>
      </div>
    </div>
  );
}
