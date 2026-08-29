'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { useAuth } from '@/context/AuthContext';
import { api } from '@/lib/api';
import { useRouter } from 'next/navigation';

interface SearchLog {
  id: string;
  query: string | null;
  context: string;
  resultCount: number | null;
  userId: string | null;
  userEmail: string | null;
  userPhone: string | null;
  ip: string | null;
  ipCountry: string | null;
  latitude: number | null;
  longitude: number | null;
  locationAccuracy: number | null;
  createdAt: string;
}

function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString('en-US', {
    month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit', second: '2-digit',
  });
}

/** Renders the search context JSON as a compact, human-readable summary —
 *  e.g. "category=electronics, priceMax=500" — instead of raw JSON. */
function formatContext(contextJson: string): string {
  try {
    const parsed = JSON.parse(contextJson) as Record<string, unknown>;
    const parts = Object.entries(parsed)
      .filter(([key, value]) => value !== undefined && value !== null && value !== '' && key !== 'q')
      .map(([key, value]) => `${key}=${value}`);
    return parts.length ? parts.join(', ') : '—';
  } catch {
    return contextJson;
  }
}

function formatLocation(log: SearchLog): string {
  if (log.latitude !== null && log.longitude !== null) {
    const precision = log.locationAccuracy !== null ? ` (±${Math.round(log.locationAccuracy)}m)` : '';
    return `${log.latitude.toFixed(4)}, ${log.longitude.toFixed(4)}${precision}`;
  }
  return log.ipCountry ?? '—';
}

export default function AdminSearchLogsPage() {
  const { user, loading } = useAuth();
  const router = useRouter();

  const [logs, setLogs] = useState<SearchLog[]>([]);
  const [total, setTotal] = useState(0);
  const [fetching, setFetching] = useState(true);
  const [error, setError] = useState('');

  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const limit = 25;
  const debounceRef = useRef<NodeJS.Timeout | null>(null);

  const fetchLogs = useCallback(async (query: string, pageNum: number) => {
    try {
      setFetching(true);
      setError('');
      const params: Record<string, string | number> = { page: pageNum, limit };
      if (query) params.search = query;
      const { data } = await api.get('/admin/search-logs', { params });
      setLogs(data.logs);
      setTotal(data.pagination.total);
    } catch {
      setError('Failed to load search logs.');
    } finally {
      setFetching(false);
    }
  }, []);

  useEffect(() => {
    if (!loading && (!user || user.role !== 'ADMIN')) router.push('/admin/auth/login');
  }, [user, loading, router]);

  useEffect(() => {
    if (user?.role !== 'ADMIN') return;
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => fetchLogs(search, page), 300);
    return () => { if (debounceRef.current) clearTimeout(debounceRef.current); };
  }, [search, page, user, fetchLogs]);

  useEffect(() => { setPage(1); }, [search]);

  const totalPages = Math.max(1, Math.ceil(total / limit));

  if (loading) return <div className="p-8 text-center">Loading...</div>;

  return (
    <div className="p-4 sm:p-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
        <div>
          <h1 className="text-xl font-bold text-gray-900">Search Logs</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            Every search made on the site — the term/filters searched are always recorded; signed-in
            user details and precise location are shown when available.
          </p>
        </div>
        <div className="text-center text-sm">
          <div className="text-lg font-bold text-gray-900 tabular-nums">{total.toLocaleString()}</div>
          <div className="text-[11px] text-gray-400 uppercase tracking-wide">Searches logged</div>
        </div>
      </div>

      <div className="mb-4">
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by term, email, phone, IP, or country…"
          className="w-full sm:max-w-md border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-red-400"
        />
      </div>

      {error && <p className="text-sm text-red-600 mb-3">{error}</p>}

      <div className="bg-white rounded-xl shadow-sm overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100">
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Time</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Search term</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Filters</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Results</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">User</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Phone</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Location</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">IP</th>
            </tr>
          </thead>
          <tbody>
            {fetching ? (
              <tr><td colSpan={8} className="text-center py-8 text-gray-400">Loading…</td></tr>
            ) : logs.length === 0 ? (
              <tr><td colSpan={8} className="text-center py-8 text-gray-400">No search logs found.</td></tr>
            ) : (
              logs.map((log) => (
                <tr key={log.id} className="border-b border-gray-50 hover:bg-gray-50">
                  <td className="px-3 sm:px-4 py-2 text-gray-500 whitespace-nowrap">{formatDateTime(log.createdAt)}</td>
                  <td className="px-3 sm:px-4 py-2 text-gray-800 font-medium">{log.query || <span className="text-gray-400 font-normal">— (filter only)</span>}</td>
                  <td className="px-3 sm:px-4 py-2 text-gray-600">{formatContext(log.context)}</td>
                  <td className="px-3 sm:px-4 py-2 text-gray-500 tabular-nums">{log.resultCount ?? '—'}</td>
                  <td className="px-3 sm:px-4 py-2 text-gray-700">{log.userEmail ?? <span className="text-gray-400">Guest</span>}</td>
                  <td className="px-3 sm:px-4 py-2 text-gray-700 whitespace-nowrap">{log.userPhone ?? '—'}</td>
                  <td className="px-3 sm:px-4 py-2 text-gray-500 whitespace-nowrap">{formatLocation(log)}</td>
                  <td className="px-3 sm:px-4 py-2 font-mono text-gray-500 whitespace-nowrap">{log.ip ?? '—'}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {totalPages > 1 && (
        <div className="flex items-center justify-between mt-4 text-sm">
          <span className="text-gray-500">
            Page {page} of {totalPages} ({total.toLocaleString()} rows)
          </span>
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page <= 1}
              className="px-3 py-1.5 rounded-lg border border-gray-200 text-gray-600 disabled:opacity-40 hover:bg-gray-50"
            >
              Previous
            </button>
            <button
              type="button"
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              disabled={page >= totalPages}
              className="px-3 py-1.5 rounded-lg border border-gray-200 text-gray-600 disabled:opacity-40 hover:bg-gray-50"
            >
              Next
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
