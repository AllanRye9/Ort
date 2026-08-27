'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { useAuth } from '@/context/AuthContext';
import { api } from '@/lib/api';
import { useRouter } from 'next/navigation';

interface VisitorLog {
  id: string;
  deviceId: string;
  dayKey: string;
  ip: string;
  country: string | null;
  userAgent: string | null;
  device: string | null;
  firstSeenAt: string;
  lastSeenAt: string;
  durationSeconds: number;
  visitCount: number;
}

/** Formats a duration in seconds as e.g. "2m 14s" or "45s". */
function formatDuration(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  if (mins < 60) return `${mins}m ${secs}s`;
  const hrs = Math.floor(mins / 60);
  return `${hrs}h ${mins % 60}m`;
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

export default function AdminVisitorLogsPage() {
  const { user, loading } = useAuth();
  const router = useRouter();

  const [logs, setLogs] = useState<VisitorLog[]>([]);
  const [total, setTotal] = useState(0);
  const [uniqueDeviceCount, setUniqueDeviceCount] = useState(0);
  const [fetching, setFetching] = useState(true);
  const [error, setError] = useState('');

  const [search, setSearch] = useState('');
  const [dateFilter, setDateFilter] = useState('');
  const [page, setPage] = useState(1);
  const limit = 25;
  const debounceRef = useRef<NodeJS.Timeout | null>(null);

  const fetchLogs = useCallback(async (query: string, date: string, pageNum: number) => {
    try {
      setFetching(true);
      setError('');
      const params: Record<string, string | number> = { page: pageNum, limit };
      if (query) params.search = query;
      if (date) params.date = date;
      const { data } = await api.get('/admin/visitor-logs', { params });
      setLogs(data.logs);
      setTotal(data.pagination.total);
      setUniqueDeviceCount(data.uniqueDeviceCount);
    } catch {
      setError('Failed to load visitor logs.');
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
    debounceRef.current = setTimeout(() => fetchLogs(search, dateFilter, page), 300);
    return () => { if (debounceRef.current) clearTimeout(debounceRef.current); };
  }, [search, dateFilter, page, user, fetchLogs]);

  // Reset to page 1 whenever the filters change.
  useEffect(() => { setPage(1); }, [search, dateFilter]);

  const totalPages = Math.max(1, Math.ceil(total / limit));

  if (loading) return <div className="p-8 text-center">Loading...</div>;

  return (
    <div className="p-4 sm:p-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
        <div>
          <h1 className="text-xl font-bold text-gray-900">Visitor Logs</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            Raw proof-of-visit records — IP address, date, time, device, and time on site —
            one row per device per day, backing the &ldquo;Total Visitors&rdquo; / &ldquo;Daily Visitors&rdquo; counters
            shown across the site.
          </p>
        </div>
        <div className="flex gap-4 text-sm">
          <div className="text-center">
            <div className="text-lg font-bold text-gray-900 tabular-nums">{total.toLocaleString()}</div>
            <div className="text-[11px] text-gray-400 uppercase tracking-wide">Log rows</div>
          </div>
          <div className="text-center">
            <div className="text-lg font-bold text-gray-900 tabular-nums">{uniqueDeviceCount.toLocaleString()}</div>
            <div className="text-[11px] text-gray-400 uppercase tracking-wide">Unique devices</div>
          </div>
        </div>
      </div>

      <div className="flex flex-col sm:flex-row gap-2 mb-4">
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by IP, device ID, country, or device type…"
          className="flex-1 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-red-400"
        />
        <input
          type="date"
          value={dateFilter}
          onChange={(e) => setDateFilter(e.target.value)}
          className="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-red-400"
        />
        {dateFilter && (
          <button
            type="button"
            onClick={() => setDateFilter('')}
            className="text-xs px-3 py-2 rounded-lg border border-gray-200 text-gray-500 hover:bg-gray-50"
          >
            Clear date
          </button>
        )}
      </div>

      {error && <p className="text-sm text-red-600 mb-3">{error}</p>}

      <div className="bg-white rounded-xl shadow-sm overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100">
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Date</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">First Seen</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Last Seen</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">IP Address</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Country</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Device</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Time on Site</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Visits</th>
              <th className="text-left px-3 sm:px-4 py-2 text-xs font-medium text-gray-600">Device ID</th>
            </tr>
          </thead>
          <tbody>
            {fetching ? (
              <tr><td colSpan={9} className="text-center py-8 text-gray-400">Loading…</td></tr>
            ) : logs.length === 0 ? (
              <tr><td colSpan={9} className="text-center py-8 text-gray-400">No visitor logs found.</td></tr>
            ) : (
              logs.map((log) => (
                <tr key={log.id} className="border-b border-gray-50 hover:bg-gray-50">
                  <td className="px-3 sm:px-4 py-2 text-gray-700 whitespace-nowrap">{log.dayKey}</td>
                  <td className="px-3 sm:px-4 py-2 text-gray-500 whitespace-nowrap">{formatTime(log.firstSeenAt)}</td>
                  <td className="px-3 sm:px-4 py-2 text-gray-500 whitespace-nowrap">{formatTime(log.lastSeenAt)}</td>
                  <td className="px-3 sm:px-4 py-2 font-mono text-gray-800 whitespace-nowrap">{log.ip}</td>
                  <td className="px-3 sm:px-4 py-2 text-gray-500">{log.country ?? '—'}</td>
                  <td className="px-3 sm:px-4 py-2 text-gray-700 whitespace-nowrap" title={log.userAgent ?? undefined}>
                    {log.device ?? 'Unknown device'}
                  </td>
                  <td className="px-3 sm:px-4 py-2 text-gray-700 whitespace-nowrap">{formatDuration(log.durationSeconds)}</td>
                  <td className="px-3 sm:px-4 py-2 text-gray-500">{log.visitCount}</td>
                  <td className="px-3 sm:px-4 py-2 text-gray-400 font-mono text-xs truncate max-w-[140px]" title={log.deviceId}>
                    {log.deviceId}
                  </td>
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
