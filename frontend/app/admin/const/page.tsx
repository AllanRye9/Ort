'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { useAuth } from '@/context/AuthContext';
import { api } from '@/lib/api';
import { Role, User } from '@/lib/types';
import { useRouter } from 'next/navigation';
import { formatDate } from '@/lib/utils';

const ALL_ROLES: Role[] = ['BUYER', 'SELLER', 'AGENT', 'COMPANY', 'ORGANIZATION', 'ADMIN'];

const ROLE_LABELS: Record<Role, string> = {
  BUYER: 'Buyer',
  SELLER: 'Seller',
  ADMIN: 'Admin',
  AGENT: 'Agent',
  ORGANIZATION: 'Organization',
  COMPANY: 'Company',
};

const ROLE_COLORS: Record<Role, string> = {
  BUYER: 'bg-gray-100 text-gray-700',
  SELLER: 'bg-blue-100 text-blue-700',
  ADMIN: 'bg-purple-100 text-purple-700',
  AGENT: 'bg-sky-100 text-sky-700',
  ORGANIZATION: 'bg-amber-100 text-amber-700',
  COMPANY: 'bg-green-100 text-green-700',
};

export default function AdminConstPage() {
  const { user, loading } = useAuth();
  const router = useRouter();
  const [users, setUsers] = useState<User[]>([]);
  const [total, setTotal] = useState(0);
  const [fetching, setFetching] = useState(true);
  const [search, setSearch] = useState('');
  const [savingId, setSavingId] = useState<string | null>(null);
  const [savedId, setSavedId] = useState<string | null>(null);
  const debounceRef = useRef<NodeJS.Timeout | null>(null);

  const fetchUsers = useCallback(async (query: string) => {
    setFetching(true);
    try {
      const params = query ? { search: query } : {};
      const { data } = await api.get('/admin/users', { params });
      setUsers(data.users);
      setTotal(data.pagination.total);
    } catch {
      // ignore
    } finally {
      setFetching(false);
    }
  }, []);

  useEffect(() => {
    if (!loading && (!user || user.role !== 'ADMIN')) router.push('/admin/auth/login');
    if (user?.role === 'ADMIN') fetchUsers('');
  }, [user, loading, router, fetchUsers]);

  useEffect(() => {
    if (!user || user.role !== 'ADMIN') return;
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => fetchUsers(search), 300);
    return () => {
      if (debounceRef.current) {
        clearTimeout(debounceRef.current);
        debounceRef.current = null;
      }
    };
  }, [search, user, fetchUsers]);

  const changeRole = async (userId: string, newRole: Role) => {
    setSavingId(userId);
    try {
      await api.put(`/admin/users/${userId}`, { role: newRole });
      setUsers((prev) => prev.map((u) => u.id === userId ? { ...u, role: newRole } : u));
      setSavedId(userId);
      setTimeout(() => setSavedId(null), 2000);
    } catch {
      // ignore
    } finally {
      setSavingId(null);
    }
  };

  if (loading || fetching) return <div className="p-8 text-center">Loading...</div>;

  return (
    <>
      <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 mb-1">Account Type Management</h1>
      <p className="text-gray-500 mb-2 text-sm">
        Change the account type (role) for users, companies, and organizations. {total} total users.
      </p>

      <div className="mb-4 flex flex-wrap gap-3 text-xs">
        {ALL_ROLES.map((r) => (
          <span key={r} className={`px-2 py-1 rounded-full font-semibold ${ROLE_COLORS[r]}`}>
            {ROLE_LABELS[r]}
          </span>
        ))}
      </div>

      <div className="mb-6">
        <input
          type="text"
          placeholder="Search by name or email..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full max-w-md px-4 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-sky-500 focus:border-transparent"
        />
      </div>

      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Name</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Email</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Country</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Joined</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Current Role</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Change Role</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {users.map((u) => (
                <tr key={u.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-medium">{u.name}</td>
                  <td className="px-4 py-3 text-gray-500 truncate max-w-[160px]">{u.email}</td>
                  <td className="px-4 py-3">{u.country}</td>
                  <td className="px-4 py-3 text-gray-500">{formatDate(u.createdAt)}</td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-0.5 rounded-full text-xs font-semibold ${ROLE_COLORS[u.role]}`}>
                      {ROLE_LABELS[u.role]}
                    </span>
                    {savedId === u.id && (
                      <span className="ml-2 text-xs text-green-600 font-semibold">✓ Saved</span>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    {u.role !== 'ADMIN' ? (
                      <div className="flex items-center gap-2">
                        <select
                          value={u.role}
                          onChange={(e) => changeRole(u.id, e.target.value as Role)}
                          disabled={savingId === u.id}
                          className="rounded-lg border border-gray-300 px-2 py-1.5 text-xs focus:outline-none focus:ring-2 focus:ring-sky-400 disabled:opacity-60"
                        >
                          {ALL_ROLES.filter((r) => r !== 'ADMIN').map((r) => (
                            <option key={r} value={r}>{ROLE_LABELS[r]}</option>
                          ))}
                        </select>
                        {savingId === u.id && (
                          <span className="text-xs text-gray-400">Saving…</span>
                        )}
                      </div>
                    ) : (
                      <span className="text-xs text-gray-400 italic">Admin — protected</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}
