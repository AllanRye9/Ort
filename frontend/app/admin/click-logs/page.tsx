'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import Image from 'next/image';
import { useAuth } from '@/context/AuthContext';
import { api } from '@/lib/api';
import { useRouter } from 'next/navigation';
import { resolveImageUrl, getApiErrorMessage } from '@/lib/utils';

interface ClickLog {
  id: string;
  listingId: string | null;
  listingTitle: string;
  listingImage: string | null;
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

interface MostClickedItem {
  listingId: string | null;
  title: string;
  image: string | null;
  status: string | null;
  clicks: number;
}

function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString('en-US', {
    year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit', second: '2-digit',
  });
}

function formatLocation(log: ClickLog): string {
  if (log.latitude !== null && log.longitude !== null) {
    const precision = log.locationAccuracy !== null ? ` (±${Math.round(log.locationAccuracy)}m)` : '';
    return `${log.latitude.toFixed(4)}, ${log.longitude.toFixed(4)}${precision}`;
  }
  return log.ipCountry ?? '—';
}

function MostClickedCard({ item, rank }: { item: MostClickedItem; rank: number }) {
  const src = resolveImageUrl(item.image || '');
  return (
    <div className="flex items-center gap-3 bg-white rounded-xl shadow-sm p-3">
      <span className="text-sm font-bold text-gray-400 w-5 text-center shrink-0">{rank}</span>
      <div className="relative w-14 h-14 rounded-lg overflow-hidden bg-gray-100 shrink-0">
        {src ? (
          <Image src={src} alt={item.title} fill className="object-cover" sizes="56px" />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-gray-300 text-xs">No image</div>
        )}
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-sm font-medium text-gray-900 truncate" title={item.title}>{item.title}</p>
        {item.status === 'DELETED' && <p className="text-xs text-red-500">Listing deleted</p>}
      </div>
      <div className="text-right shrink-0">
        <div className="text-sm font-bold text-gray-900 tabular-nums">{item.clicks.toLocaleString()}</div>
        <div className="text-[11px] text-gray-400 uppercase tracking-wide">Clicks</div>
      </div>
    </div>
  );
}

export default function AdminClickLogsPage() {
  const { user, loading } = useAuth();
  const router = useRouter();

  const [mostClicked, setMostClicked] = useState<MostClickedItem[]>([]);
  const [mostClickedLoading, setMostClickedLoading] = useState(true);
  const [mostClickedError, setMostClickedError] = useState('');

  const [logs, setLogs] = useState<ClickLog[]>([]);
  const [total, setTotal] = useState(0);
  const [fetching, setFetching] = useState(true);
  const [error, setError] = useState('');

  const [search, setSearch] = useState('');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [sortBy, setSortBy] = useState<'createdAt' | 'listingTitle'>('createdAt');
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('desc');
  const [page, setPage] = useState(1);
  const limit = 25;
  const debounceRef = useRef<NodeJS.Timeout | null>(null);

  const fetchLogs = useCallback(async (query: string, pageNum: number, from: string, to: string, sBy: string, sDir: string) => {
    try {
      setFetching(true);
      setError('');
      const params: Record<string, string | number> = { page: pageNum, limit, sortBy: sBy, sortDir: sDir };
      if (query) params.search = query;
      if (from) params.dateFrom = from;
      if (to) params.dateTo = to;
      const { data } = await api.get('/admin/click-logs', { params });
      setLogs(data.logs);
      setTotal(data.pagination.total);
    } catch (err) {
      setError(getApiErrorMessage(err, 'Failed to load click logs.'));
    } finally {
      setFetching(false);
    }
  }, []);

  useEffect(() => {
    if (!loading && (!user || user.role !== 'ADMIN')) router.push('/admin/auth/login');
  }, [user, loading, router]);

  useEffect(() => {
    if (user?.role !== 'ADMIN') return;
    api.get('/admin/click-logs/most-clicked', { params: { limit: 10 } })
      .then(({ data }) => setMostClicked(data.items))
      .catch((err) => setMostClickedError(getApiErrorMessage(err, 'Failed to load most-clicked items.')))
      .finally(() => setMostClickedLoading(false));
  }, [user]);

  useEffect(() => {
    if (user?.role !== 'ADMIN') return;
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => fetchLogs(search, page, dateFrom, dateTo, sortBy, sortDir), 300);
    return () => { if (debounceRef.current) clearTimeout(debounceRef.current); };
  }, [search, page, dateFrom, dateTo, sortBy, sortDir, user, fetchLogs]);

  useEffect(() => { setPage(1); }, [search, dateFrom, dateTo, sortBy, sortDir]);

  const totalPages = Math.max(1, Math.ceil(total / limit));

  if (loading) return <div className="p-8 text-center">Loading...</div>;

  return (
    <div className="p-4 sm:p-6">
      <div className="mb-4">
        <h1 className="text-xl font-bold text-gray-900">Item Clicks</h1>
        <p className="text-sm text-gray-500 mt-0.5">
          Every listing detail view on the site — item title and image preview are always recorded;
          signed-in user details and precise location are shown when available.
        </p>
      </div>

      <div className="mb-6">
        <h2 className="text-sm font-semibold text-gray-700 mb-2">Most Clicked Items</h2>
        {mostClickedLoading ? (
          <p className="text-sm text-gray-400">Loading…</p>
        ) : mostClickedError ? (
          <p className="text-sm text-red-600">{mostClickedError}</p>
        ) : mostClicked.length === 0 ? (
          <p className="text-sm text-gray-400">No item clicks recorded yet.</p>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {mostClicked.map((item, i) => (
              <MostClickedCard key={item.listingId ?? `${item.title}-${i}`} item={item} rank={i + 1} />
            ))}
          </div>
        )}
      </div>

      <div className="flex items-center justify-between gap-3 mb-4">
        <h2 className="text-sm font-semibold text-gray-700">All Click Events</h2>
        <div className="text-center text-sm">
          <div className="text-lg font-bold text-gray-900 tabular-nums">{total.toLocaleString()}</div>
          <div className="text-[11px] text-gray-400 uppercase tracking-wide">Clicks logged</div>
        </div>
      </div>

      <div className="mb-4 flex flex-col sm:flex-row flex-wrap gap-2 items-start sm:items-center">
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by item title, email, phone, IP, or country…"
          className="w-full sm:max-w-md border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-red-400"
        />
        <div className="flex items-center gap-1.5 text-xs text-gray-500">
          <label>From</label>
          <input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)}
            className="border border-gray-300 rounded-lg px-2 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-red-400" />
          <label>To</label>
          <input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)}
            className="border border-gray-300 rounded-lg px-2 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-red-400" />
        </div>
        <select value={sortBy} onChange={(e) => setSortBy(e.target.value as typeof sortBy)}
          className="border border-gray-300 rounded-lg px-2 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-red-400">
          <option value="createdAt">Sort: Time</option>
          <option value="listingTitle">Sort: Item title</option>
        </select>
        <button type="button" onClick={() => setSortDir((d) => d === 'asc' ? 'desc' : 'asc')}
          className="px-2.5 py-1.5 border border-gray-300 rounded-lg text-sm text-gray-600 hover:bg-gray-50"
          title="Toggle sort direction">
          {sortDir === 'asc' ? '↑ Asc' : '↓ Desc'}
        </button>
        {(dateFrom || dateTo) && (
          <button type="button" onClick={() => { setDateFrom(''); setDateTo(''); }}
            className="text-xs text-red-600 hover:underline">Clear dates</button>
        )}
      </div>

      {error && <p className="text-sm text-red-600 mb-3">{error}</p>}

      <div className="bg-white rounded-xl shadow-sm overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100">
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Time</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Item</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">User</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Phone</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Location</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">IP</th>
            </tr>
          </thead>
          <tbody>
            {fetching ? (
              <tr><td colSpan={6} className="text-center py-8 text-gray-400">Loading…</td></tr>
            ) : logs.length === 0 ? (
              <tr><td colSpan={6} className="text-center py-8 text-gray-400">No click logs found.</td></tr>
            ) : (
              logs.map((log) => {
                const src = resolveImageUrl(log.listingImage || '');
                return (
                  <tr key={log.id} className="border-b border-gray-50 hover:bg-gray-50">
                    <td className="px-3 sm:px-4 py-2 text-gray-500 whitespace-nowrap">{formatDateTime(log.createdAt)}</td>
                    <td className="px-3 sm:px-4 py-2 text-gray-800">
                      <div className="flex items-center gap-2 min-w-[180px]">
                        <div className="relative w-8 h-8 rounded overflow-hidden bg-gray-100 shrink-0">
                          {src && <Image src={src} alt={log.listingTitle} fill className="object-cover" sizes="32px" />}
                        </div>
                        <span className="truncate max-w-[220px]" title={log.listingTitle}>{log.listingTitle}</span>
                      </div>
                    </td>
                    <td className="px-3 sm:px-4 py-2 text-gray-700">{log.userEmail ?? <span className="text-gray-400">Guest</span>}</td>
                    <td className="px-3 sm:px-4 py-2 text-gray-700 whitespace-nowrap">{log.userPhone ?? '—'}</td>
                    <td className="px-3 sm:px-4 py-2 text-gray-500 whitespace-nowrap">{formatLocation(log)}</td>
                    <td className="px-3 sm:px-4 py-2 font-mono text-gray-500 whitespace-nowrap">{log.ip ?? '—'}</td>
                  </tr>
                );
              })
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
