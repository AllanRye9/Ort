'use client';

import Link from 'next/link';
import { useState } from 'react';
import { useRouter } from 'next/navigation';

export default function NotFound() {
  const [query, setQuery] = useState('');
  const router = useRouter();

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (query.trim()) {
      router.push(`/listings?q=${encodeURIComponent(query.trim())}`);
    }
  };

  return (
    <div className="min-h-[60vh] flex flex-col items-center justify-center px-4 py-8 text-center">
      {/* Visual */}
      <div className="relative mb-4">
        <div className="text-[120px] font-extrabold leading-none select-none bg-gradient-to-br from-sky-400 to-blue-600 bg-clip-text text-transparent">
          404
        </div>
        <div className="absolute -bottom-3 left-1/2 -translate-x-1/2 text-5xl">🔍</div>
      </div>

      <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 mb-3 mt-4">
        Page Not Found
      </h1>
      <p className="text-gray-500 max-w-md mb-4 text-sm sm:text-base">
        We couldn&apos;t find the page you were looking for. It may have been moved, deleted, or never existed.
        Try searching for what you need below.
      </p>

      {/* Search bar */}
      <form onSubmit={handleSearch} className="w-full max-w-md mb-4">
        <div className="flex gap-2">
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search listings..."
            className="flex-1 border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-sky-300 focus:border-sky-400"
            aria-label="Search listings"
          />
          <button
            type="submit"
            className="px-5 py-2.5 bg-sky-500 hover:bg-sky-600 text-white font-semibold text-sm rounded-xl transition-colors"
          >
            Search
          </button>
        </div>
      </form>

      {/* Quick links */}
      <div className="flex flex-wrap justify-center gap-3">
        <Link
          href="/"
          className="px-5 py-2 rounded-xl border border-gray-200 text-gray-700 hover:border-sky-300 hover:text-sky-600 font-medium text-sm transition-colors"
        >
          🏠 Home
        </Link>
        <Link
          href="/listings"
          className="px-5 py-2 rounded-xl border border-gray-200 text-gray-700 hover:border-sky-300 hover:text-sky-600 font-medium text-sm transition-colors"
        >
          🔍 Browse Listings
        </Link>
        <Link
          href="/dashboard"
          className="px-5 py-2 rounded-xl border border-gray-200 text-gray-700 hover:border-sky-300 hover:text-sky-600 font-medium text-sm transition-colors"
        >
          📊 Dashboard
        </Link>
        <Link
          href="/help"
          className="px-5 py-2 rounded-xl border border-gray-200 text-gray-700 hover:border-sky-300 hover:text-sky-600 font-medium text-sm transition-colors"
        >
          ❓ Help
        </Link>
      </div>
    </div>
  );
}
