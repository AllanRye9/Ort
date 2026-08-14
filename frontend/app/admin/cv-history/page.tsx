'use client';

import { useEffect, useState, useCallback } from 'react';
import { useAuth } from '@/context/AuthContext';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { formatDate } from '@/lib/utils';

interface CvHistoryEntry {
  id: string;
  holderName: string | null;
  holderTitle: string | null;
  holderEmail: string | null;
  holderPhone: string | null;
  amount: string | number;
  currency: string;
  country: string;
  paid: boolean;
  usedAt: string | null;
  createdAt: string;
  user: { id: string; name: string; email: string } | null;
  package: { id: string; name: string; isFree: boolean } | null;
}

interface CvHistoryStats {
  total: number;
  paid: number;
  free: number;
  downloaded: number;
}

const STATUS_FILTERS = [
  { value: '',       label: 'All' },
  { value: 'paid',   label: 'Paid' },
  { value: 'free',   label: 'Free' },
  { value: 'unpaid', label: 'Unpaid / Abandoned' },
] as const;

export default function AdminCvHistoryPage() {
  const { user, loading } = useAuth();
  const router = useRouter();

  const [entries, setEntries] = useState<CvHistoryEntry[]>([]);
  const [stats, setStats]     = useState<CvHistoryStats | null>(null);
  const [fetching, setFetching] = useState(true);
  const [status, setStatus]   = useState<typeof STATUS_FILTERS[number]['value']>('');
  const [search, setSearch]   = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [page, setPage]       = useState(1);
  const [pages, setPages]     = useState(1);
  const [total, setTotal]     = useState(0);

  const fetchHistory = useCallback(async (pg = 1, statusFilter = '', searchFilter = '') => {
    setFetching(true);
    try {
      const { data } = await api.get('/admin/cv-history', {
        params: { page: pg, limit: 20, ...(statusFilter && { status: statusFilter }), ...(searchFilter && { search: searchFilter }) },
      });
      setEntries(data.entries ?? []);
      setTotal(data.total ?? 0);
      setPage(data.page ?? 1);
      setPages(data.pages ?? 1);
      setStats(data.stats ?? null);
    } catch {
      // ignore
    } finally {
      setFetching(false);
    }
  }, []);

  useEffect(() => {
    if (!loading && (!user || user.role !== 'ADMIN')) router.push('/admin/auth/login');
  }, [user, loading, router]);

  useEffect(() => {
    if (user?.role === 'ADMIN') fetchHistory(1, status, search);
  }, [user, fetchHistory, status, search]);

  const submitSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setSearch(searchInput.trim());
  };

  if (loading) return null;

  return (
    <div className="max-w-6xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">CV History</h1>
        <p className="mt-1 text-sm text-gray-500">
          Every CV generated through the CV builder — whether downloaded for free under a package or paid for individually.
        </p>
      </div>

      {/* Stats */}
      {stats && (
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-6">
          {[
            { label: 'Total Created', value: stats.total, color: 'text-gray-900' },
            { label: 'Downloaded',    value: stats.downloaded, color: 'text-sky-600' },
            { label: 'Paid',          value: stats.paid, color: 'text-emerald-600' },
            { label: 'Free',          value: stats.free, color: 'text-indigo-600' },
          ].map((s) => (
            <div key={s.label} className="bg-white rounded-2xl border border-gray-200 shadow-sm p-4">
              <p className="text-xs font-medium text-gray-400">{s.label}</p>
              <p className={`text-2xl font-bold mt-1 ${s.color}`}>{s.value}</p>
            </div>
          ))}
        </div>
      )}

      {/* Filter bar */}
      <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-4 mb-6 flex flex-wrap gap-3 items-center">
        <span className="text-sm font-medium text-gray-700">Filter:</span>
        {STATUS_FILTERS.map((s) => (
          <button
            key={s.value}
            onClick={() => { setStatus(s.value); setPage(1); }}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold border transition-colors ${
              status === s.value
                ? 'bg-sky-600 text-white border-sky-600'
                : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50'
            }`}
          >
            {s.label}
          </button>
        ))}
        <form onSubmit={submitSearch} className="ml-auto flex gap-2">
          <input
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            placeholder="Search name, email, title…"
            className="text-sm border border-gray-200 rounded-lg px-3 py-1.5 w-56 focus:outline-none focus:ring-2 focus:ring-sky-200"
          />
          <button type="submit" className="text-xs font-semibold px-3 py-1.5 rounded-lg bg-gray-100 hover:bg-gray-200 text-gray-700">
            Search
          </button>
        </form>
        <span className="text-xs text-gray-400 w-full sm:w-auto">{total} total</span>
      </div>

      {/* Table */}
      <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        {fetching ? (
          <div className="py-16 text-center text-sm text-gray-400">Loading…</div>
        ) : entries.length === 0 ? (
          <div className="py-16 text-center text-sm text-gray-400">No CVs found.</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-100">
                <tr>
                  {['CV Holder', 'Account', 'Package', 'Price', 'Status', 'Created'].map((h) => (
                    <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {entries.map((e) => (
                  <tr key={e.id} className="hover:bg-gray-50/60 transition-colors">
                    <td className="px-4 py-3">
                      <p className="font-medium text-gray-900">{e.holderName || '—'}</p>
                      <p className="text-xs text-gray-400">{e.holderTitle || ''}</p>
                      <p className="text-xs text-gray-400">{e.holderEmail || ''}{e.holderPhone ? ` · ${e.holderPhone}` : ''}</p>
                    </td>
                    <td className="px-4 py-3">
                      {e.user ? (
                        <>
                          <p className="font-medium text-gray-800">{e.user.name}</p>
                          <p className="text-xs text-gray-400">{e.user.email}</p>
                        </>
                      ) : (
                        <span className="text-xs text-gray-400 italic">Guest ({e.country})</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      {e.package ? (
                        <span className="text-xs font-medium text-gray-700">{e.package.name}{e.package.isFree ? ' (Free)' : ''}</span>
                      ) : (
                        <span className="text-xs text-gray-400 italic">Default pricing</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-gray-700 text-xs">
                      {Number(e.amount) === 0 ? 'Free' : `${e.amount} ${e.currency}`}
                    </td>
                    <td className="px-4 py-3">
                      {e.usedAt ? (
                        <span className="inline-block text-xs font-semibold border px-2 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border-emerald-200">Downloaded</span>
                      ) : e.paid ? (
                        <span className="inline-block text-xs font-semibold border px-2 py-0.5 rounded-full bg-sky-50 text-sky-700 border-sky-200">Paid, not downloaded</span>
                      ) : (
                        <span className="inline-block text-xs font-semibold border px-2 py-0.5 rounded-full bg-amber-50 text-amber-700 border-amber-200">Unpaid</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-gray-500 text-xs">{formatDate(e.createdAt)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Pagination */}
        {pages > 1 && (
          <div className="px-6 py-4 border-t border-gray-100 flex items-center justify-between">
            <button
              onClick={() => fetchHistory(page - 1, status, search)}
              disabled={page <= 1}
              className="px-3 py-1.5 rounded-lg border border-gray-200 text-xs font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-40 transition-colors"
            >
              ← Previous
            </button>
            <span className="text-xs text-gray-500">Page {page} of {pages}</span>
            <button
              onClick={() => fetchHistory(page + 1, status, search)}
              disabled={page >= pages}
              className="px-3 py-1.5 rounded-lg border border-gray-200 text-xs font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-40 transition-colors"
            >
              Next →
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
