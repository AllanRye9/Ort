'use client';

/**
 * /admin/farmer-marketplace
 *
 * Manages the Farmer Marketplace shown in the homepage's
 * <HomeFarmerMarketplace /> section and the "Farmer Marketplace" tab on
 * /market-prices (see components/ui/FarmerMarketplaceSection.tsx and
 * backend routes/farmerMarketplace.ts). The public UI lets any admin verify
 * a seller/buyer inline from the post-detail panel; this page is the
 * dedicated dashboard for doing that at a glance across every post,
 * including closed ones (which the public pages hide), plus closing,
 * reopening, and deleting posts.
 */

import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { api } from '@/lib/api';

type QualityGrade = 'A' | 'B' | 'C' | 'UNGRADED';
type PostStatus = 'OPEN' | 'MATCHED' | 'CLOSED';

interface FarmerPost {
  id: string;
  farmerName: string;
  farmerPhone: string | null;
  verifiedSeller: boolean;
  commodity: string;
  quantity: number;
  unit: string;
  location: string;
  qualityGrade: QualityGrade;
  minPricePerUnit: number;
  currency: string;
  status: PostStatus;
  offerCount: number;
  bestDeliveredPricePerUnit: number | null;
}

interface BuyerOffer {
  id: string;
  buyerName: string;
  buyerLocation: string;
  verifiedBuyer: boolean;
  deliveredPricePerUnit: number;
}

function money(value: number, currency = 'UGX'): string {
  return `${currency} ${value.toLocaleString('en-UG', { maximumFractionDigits: value % 1 === 0 ? 0 : 2 })}`;
}

const STATUS_STYLE: Record<PostStatus, string> = {
  OPEN: 'bg-emerald-100 text-emerald-700',
  MATCHED: 'bg-blue-100 text-blue-700',
  CLOSED: 'bg-gray-100 text-gray-500',
};

export default function FarmerMarketplaceAdminPage() {
  const { user, loading: authLoading } = useAuth();
  const router = useRouter();

  const [posts, setPosts] = useState<FarmerPost[]>([]);
  const [fetching, setFetching] = useState(true);
  const [toast, setToast] = useState<{ msg: string; ok: boolean } | null>(null);
  const [statusFilter, setStatusFilter] = useState<'ALL' | PostStatus>('ALL');
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [offersById, setOffersById] = useState<Record<string, BuyerOffer[]>>({});
  const [offersLoading, setOffersLoading] = useState<string | null>(null);

  useEffect(() => {
    if (!authLoading && (!user || user.role !== 'ADMIN')) {
      router.replace('/admin/auth/login');
    }
  }, [user, authLoading, router]);

  const showToast = (msg: string, ok: boolean) => {
    setToast({ msg, ok });
    setTimeout(() => setToast(null), 4000);
  };

  const fetchPosts = useCallback(async () => {
    setFetching(true);
    try {
      const { data } = await api.get('/farmer-marketplace/posts', { params: { status: 'ALL' } });
      setPosts(data?.posts || []);
    } catch {
      showToast('Could not load farmer marketplace posts.', false);
    } finally {
      setFetching(false);
    }
  }, []);

  useEffect(() => { fetchPosts(); }, [fetchPosts]);

  const toggleExpand = async (id: string) => {
    if (expandedId === id) { setExpandedId(null); return; }
    setExpandedId(id);
    if (offersById[id]) return;
    setOffersLoading(id);
    try {
      const { data } = await api.get(`/farmer-marketplace/posts/${id}`);
      setOffersById((prev) => ({ ...prev, [id]: data?.offers || [] }));
    } catch {
      showToast('Could not load offers for that post.', false);
    } finally {
      setOffersLoading(null);
    }
  };

  const verifySeller = async (post: FarmerPost) => {
    try {
      await api.patch(`/farmer-marketplace/posts/${post.id}/verify`, { verified: !post.verifiedSeller });
      showToast(post.verifiedSeller ? 'Seller verification removed.' : 'Seller marked as verified.', true);
      fetchPosts();
    } catch {
      showToast('Could not update seller verification.', false);
    }
  };

  const verifyBuyer = async (postId: string, offer: BuyerOffer) => {
    try {
      await api.patch(`/farmer-marketplace/offers/${offer.id}/verify`, { verified: !offer.verifiedBuyer });
      showToast(offer.verifiedBuyer ? 'Buyer verification removed.' : 'Buyer marked as verified.', true);
      const { data } = await api.get(`/farmer-marketplace/posts/${postId}`);
      setOffersById((prev) => ({ ...prev, [postId]: data?.offers || [] }));
    } catch {
      showToast('Could not update buyer verification.', false);
    }
  };

  const setStatus = async (post: FarmerPost, status: PostStatus) => {
    try {
      await api.patch(`/farmer-marketplace/posts/${post.id}`, { status });
      showToast(`Post marked as ${status.toLowerCase()}.`, true);
      fetchPosts();
    } catch {
      showToast('Could not update that post.', false);
    }
  };

  const deletePost = async (post: FarmerPost) => {
    if (!confirm(`Delete this ${post.commodity} post from ${post.farmerName}? This also removes all its buyer offers.`)) return;
    try {
      await api.delete(`/farmer-marketplace/posts/${post.id}`);
      showToast('Post deleted.', true);
      fetchPosts();
    } catch {
      showToast('Could not delete that post.', false);
    }
  };

  const visiblePosts = statusFilter === 'ALL' ? posts : posts.filter((p) => p.status === statusFilter);

  if (authLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="w-8 h-8 border-4 border-emerald-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto px-4 py-8">
      {toast && (
        <div className={`fixed top-4 right-4 z-50 px-5 py-3 rounded-xl shadow-xl text-sm font-semibold text-white transition-all ${toast.ok ? 'bg-emerald-600' : 'bg-red-600'}`}>
          {toast.msg}
        </div>
      )}

      <div className="flex items-center justify-between flex-wrap gap-3 mb-6">
        <div>
          <h1 className="text-xl font-black text-gray-900 flex items-center gap-2">🚜 Farmer Marketplace</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            Verify sellers and buyers, and manage post status. Live commodity data — no separate save step, each
            action applies immediately.
          </p>
        </div>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value as 'ALL' | PostStatus)}
          className="border border-gray-200 rounded-lg px-3 py-2 text-sm bg-white"
        >
          <option value="ALL">All statuses</option>
          <option value="OPEN">Open</option>
          <option value="MATCHED">Matched</option>
          <option value="CLOSED">Closed</option>
        </select>
      </div>

      {fetching ? (
        <div className="space-y-2">
          {Array.from({ length: 5 }).map((_, i) => <div key={i} className="h-16 rounded-xl bg-gray-100 animate-pulse" />)}
        </div>
      ) : visiblePosts.length === 0 ? (
        <p className="text-sm text-gray-400 text-center py-12">No posts match that filter.</p>
      ) : (
        <div className="space-y-2.5">
          {visiblePosts.map((post) => (
            <div key={post.id} className="border border-gray-200 rounded-xl bg-white shadow-sm overflow-hidden">
              <div className="flex flex-wrap items-center gap-3 p-3.5">
                <button onClick={() => toggleExpand(post.id)} className="text-left flex-1 min-w-[220px]">
                  <p className="font-bold text-gray-900 text-sm flex items-center gap-2">
                    {post.commodity}
                    <span className={`text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full ${STATUS_STYLE[post.status]}`}>{post.status}</span>
                    {post.verifiedSeller && <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-premium-navy/10 text-premium-navy">Verified seller</span>}
                  </p>
                  <p className="text-xs text-gray-500 mt-0.5">
                    {post.farmerName} · {post.quantity.toLocaleString()} {post.unit} · {post.location} · min {money(post.minPricePerUnit, post.currency)}/{post.unit}
                    {post.offerCount > 0 && <> · {post.offerCount} offer{post.offerCount === 1 ? '' : 's'}</>}
                  </p>
                </button>

                <div className="flex items-center gap-1.5 flex-wrap">
                  <button
                    onClick={() => verifySeller(post)}
                    className={`text-xs font-semibold px-2.5 py-1.5 rounded-lg border transition-colors ${post.verifiedSeller ? 'border-gray-200 text-gray-500 hover:bg-gray-50' : 'border-premium-navy/30 text-premium-navy hover:bg-premium-navy/5'}`}
                  >
                    {post.verifiedSeller ? 'Unverify seller' : 'Verify seller'}
                  </button>
                  {post.status !== 'CLOSED' ? (
                    <button onClick={() => setStatus(post, 'CLOSED')} className="text-xs font-semibold px-2.5 py-1.5 rounded-lg border border-gray-200 text-gray-500 hover:bg-gray-50">
                      Close
                    </button>
                  ) : (
                    <button onClick={() => setStatus(post, 'OPEN')} className="text-xs font-semibold px-2.5 py-1.5 rounded-lg border border-emerald-200 text-emerald-700 hover:bg-emerald-50">
                      Reopen
                    </button>
                  )}
                  <button onClick={() => deletePost(post)} className="text-xs font-semibold px-2.5 py-1.5 rounded-lg border border-red-200 text-red-600 hover:bg-red-50">
                    Delete
                  </button>
                </div>
              </div>

              {expandedId === post.id && (
                <div className="border-t border-gray-100 bg-gray-50/60 p-3.5">
                  <p className="text-[11px] font-black uppercase tracking-wider text-gray-400 mb-2">Buyer offers</p>
                  {offersLoading === post.id ? (
                    <p className="text-xs text-gray-400">Loading…</p>
                  ) : (offersById[post.id]?.length ?? 0) === 0 ? (
                    <p className="text-xs text-gray-400">No offers on this post yet.</p>
                  ) : (
                    <div className="space-y-1.5">
                      {offersById[post.id].map((offer) => (
                        <div key={offer.id} className="flex items-center justify-between gap-2 bg-white rounded-lg border border-gray-100 px-3 py-2">
                          <p className="text-xs font-semibold text-gray-700">
                            {offer.buyerName} <span className="text-gray-400 font-normal">· {offer.buyerLocation}</span>
                            {offer.verifiedBuyer && <span className="ml-1.5 text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-emerald-100 text-emerald-700">Verified</span>}
                          </p>
                          <div className="flex items-center gap-2 shrink-0">
                            <span className="text-xs font-bold text-green-700">{money(offer.deliveredPricePerUnit, post.currency)}</span>
                            <button
                              onClick={() => verifyBuyer(post.id, offer)}
                              className={`text-[11px] font-semibold px-2 py-1 rounded-md border transition-colors ${offer.verifiedBuyer ? 'border-gray-200 text-gray-500 hover:bg-gray-50' : 'border-premium-navy/30 text-premium-navy hover:bg-premium-navy/5'}`}
                            >
                              {offer.verifiedBuyer ? 'Unverify' : 'Verify'}
                            </button>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
