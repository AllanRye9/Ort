'use client';

import { useEffect, useState, useCallback } from 'react';
import { useAuth } from '@/context/AuthContext';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { PackageScope, SellerSubscription, SubscriptionStatus } from '@/lib/types';
import { formatDate } from '@/lib/utils';

const STATUS_LABELS: Record<SubscriptionStatus, string> = {
  ACTIVE: 'Active',
  EXPIRED: 'Expired',
  CANCELLED: 'Cancelled',
  PENDING_PAYMENT: 'Pending Payment',
};

const STATUS_CLASSES: Record<SubscriptionStatus, string> = {
  ACTIVE: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  EXPIRED: 'bg-gray-100 text-gray-600 border-gray-200',
  CANCELLED: 'bg-red-50 text-red-700 border-red-200',
  PENDING_PAYMENT: 'bg-amber-50 text-amber-700 border-amber-200',
};

export default function AdminSubscriptionsPage() {
  const { user, loading } = useAuth();
  const router = useRouter();
  const [subscriptions, setSubscriptions] = useState<SellerSubscription[]>([]);
  const [fetching, setFetching] = useState(true);
  const [filter, setFilter] = useState('');
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(1);
  const [actionId, setActionId] = useState<string | null>(null);
  const [scope, setScope] = useState<PackageScope>('LISTING');

  const fetchSubs = useCallback(async (pg = 1, status = '') => {
    setFetching(true);
    try {
      const { data } = await api.get('/admin/subscriptions', {
        params: { page: pg, limit: 20, scope, ...(status && { status }) },
      });
      setSubscriptions(data.subscriptions ?? []);
      setTotal(data.total ?? 0);
      setPage(data.page ?? 1);
      setPages(data.pages ?? 1);
    } catch {
      // ignore
    } finally {
      setFetching(false);
    }
  }, [scope]);

  useEffect(() => {
    if (!loading && (!user || user.role !== 'ADMIN')) router.push('/admin/auth/login');
  }, [user, loading, router]);

  useEffect(() => {
    if (user?.role === 'ADMIN') fetchSubs(1, filter);
  }, [user, fetchSubs, filter]);

  const handleStatusChange = async (id: string, status: SubscriptionStatus) => {
    setActionId(id);
    try {
      await api.put(`/admin/subscriptions/${id}`, { status });
      await fetchSubs(page, filter);
    } catch {
      // ignore
    } finally {
      setActionId(null);
    }
  };

  if (loading) return null;

  return (
    <div className="max-w-6xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Seller Subscriptions</h1>
        <p className="mt-1 text-sm text-gray-500">
          Overview of listing and CV subscriptions. Manage their status or extend them as needed.
        </p>
      </div>

      <div className="mb-4 flex flex-wrap gap-2">
        {(['LISTING', 'CV'] as const).map((value) => (
          <button
            key={value}
            type="button"
            onClick={() => {
              setScope(value);
              setPage(1);
            }}
            className={`px-4 py-2 rounded-xl border text-sm font-semibold transition-colors ${
              scope === value
                ? 'bg-sky-600 text-white border-sky-600'
                : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50'
            }`}
          >
            {value === 'LISTING' ? 'Listing Subscriptions' : 'CV Subscriptions'}
          </button>
        ))}
      </div>

      {/* Filter bar */}
      <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-4 mb-6 flex flex-wrap gap-3 items-center">
        <span className="text-sm font-medium text-gray-700">Filter by status:</span>
        {(['', 'ACTIVE', 'EXPIRED', 'CANCELLED', 'PENDING_PAYMENT'] as const).map((s) => (
          <button
            key={s}
            onClick={() => { setFilter(s); setPage(1); }}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold border transition-colors ${
              filter === s
                ? 'bg-sky-600 text-white border-sky-600'
                : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50'
            }`}
          >
            {s === '' ? 'All' : STATUS_LABELS[s as SubscriptionStatus]}
          </button>
        ))}
        <span className="ml-auto text-xs text-gray-400">{total} total</span>
      </div>

      {/* Table */}
      <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        {fetching ? (
          <div className="py-16 text-center text-sm text-gray-400">Loading…</div>
        ) : subscriptions.length === 0 ? (
          <div className="py-16 text-center text-sm text-gray-400">No subscriptions found.</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-100">
                <tr>
                  {['Seller', 'Package', 'Status', 'Start', 'End', 'Actions'].map((h) => (
                    <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {subscriptions.map((sub) => (
                  <tr key={sub.id} className="hover:bg-gray-50/60 transition-colors">
                    <td className="px-4 py-3">
                      <p className="font-medium text-gray-900">{sub.user?.name ?? '—'}</p>
                      <p className="text-xs text-gray-400">{sub.user?.email}</p>
                    </td>
                    <td className="px-4 py-3">
                      <p className="font-medium text-gray-800">{sub.package.name}</p>
                      <p className="text-xs text-gray-400">
                        {sub.package.scope} {' · '}
                        {sub.package.isFree ? 'Free' : `${sub.package.price} ${sub.package.currency}`}
                        {' · '}{sub.package.durationDays}d
                      </p>
                    </td>
                    <td className="px-4 py-3">
                      <span className={`inline-block text-xs font-semibold border px-2 py-0.5 rounded-full ${STATUS_CLASSES[sub.status]}`}>
                        {STATUS_LABELS[sub.status]}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-gray-500 text-xs">{formatDate(sub.startDate)}</td>
                    <td className="px-4 py-3 text-gray-500 text-xs">
                      <span className={new Date(sub.endDate) < new Date() && sub.status === 'ACTIVE' ? 'text-red-500 font-semibold' : ''}>
                        {formatDate(sub.endDate)}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex gap-1.5">
                        {sub.status !== 'ACTIVE' && (
                          <button
                            disabled={actionId === sub.id}
                            onClick={() => handleStatusChange(sub.id, 'ACTIVE')}
                            className="px-2.5 py-1 rounded-lg bg-emerald-50 border border-emerald-200 text-xs font-medium text-emerald-700 hover:bg-emerald-100 transition-colors disabled:opacity-50"
                          >
                            Activate
                          </button>
                        )}
                        {sub.status === 'ACTIVE' && (
                          <button
                            disabled={actionId === sub.id}
                            onClick={() => handleStatusChange(sub.id, 'CANCELLED')}
                            className="px-2.5 py-1 rounded-lg bg-red-50 border border-red-200 text-xs font-medium text-red-700 hover:bg-red-100 transition-colors disabled:opacity-50"
                          >
                            Cancel
                          </button>
                        )}
                      </div>
                    </td>
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
              onClick={() => fetchSubs(page - 1, filter)}
              disabled={page <= 1}
              className="px-3 py-1.5 rounded-lg border border-gray-200 text-xs font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-40 transition-colors"
            >
              ← Previous
            </button>
            <span className="text-xs text-gray-500">Page {page} of {pages}</span>
            <button
              onClick={() => fetchSubs(page + 1, filter)}
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
