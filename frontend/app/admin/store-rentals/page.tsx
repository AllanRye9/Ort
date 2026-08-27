'use client';

/**
 * /admin/store-rentals has been consolidated into /admin/partners
 * (see "Applications & Rentals" tab). This page just redirects there
 * so old bookmarks/links keep working.
 */

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

export default function AdminStoreRentalsRedirect() {
  const router = useRouter();

  useEffect(() => {
    router.replace('/admin/partners?tab=rentals');
  }, [router]);

  return (
    <div className="flex items-center justify-center min-h-screen">
      <div className="w-8 h-8 border-4 border-red-500 border-t-transparent rounded-full animate-spin" />
    </div>
  );
}
