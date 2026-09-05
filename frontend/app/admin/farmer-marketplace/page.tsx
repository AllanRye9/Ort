'use client';

/**
 * /admin/farmer-marketplace
 *
 * Manages the Uganda Wholesale & Bulk Commodity Marketplace shown at
 * /market-prices, merged there with the reference price board (see
 * components/ui/FarmerMarketplaceSection.tsx and backend
 * routes/farmerMarketplace.ts). It is no longer surfaced on the homepage —
 * see app/page.tsx. The public UI lets any admin verify a seller/buyer
 * inline from the post-detail panel; this page is the dedicated dashboard
 * for doing that at a glance across every post, including closed ones
 * (which the public pages hide) and pending/rejected ones (which every
 * public page hides from everyone except the post's own owner), plus
 * approving/rejecting new submissions, closing, reopening, and deleting
 * posts. Icons here follow the same emoji-icon convention used at
 * /portal/settings.
 */

import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { api } from '@/lib/api';

type QualityGrade = 'A' | 'B' | 'C' | 'UNGRADED';
type PostStatus = 'OPEN' | 'MATCHED' | 'CLOSED';
type ModerationStatus = 'PENDING' | 'APPROVED' | 'REJECTED';

interface FarmerPost {
  id: string;
  farmerName: string;
  /** Visible here because this page is admin-only — regular buyers never
   *  receive this field (see toPublicPost() in the backend route). */
  farmerPhone: string | null;
  isWhatsapp: boolean;
  verifiedSeller: boolean;
  commodity: string;
  quantity: number;
  unit: string;
  location: string;
  qualityGrade: QualityGrade;
  minPricePerUnit: number;
  currency: string;
  status: PostStatus;
  moderationStatus: ModerationStatus;
  rejectionReason: string | null;
  images: string[];
  videoUrl: string | null;
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

const MODERATION_STYLE: Record<ModerationStatus, string> = {
  PENDING: 'bg-amber-100 text-amber-700',
  APPROVED: 'bg-emerald-100 text-emerald-700',
  REJECTED: 'bg-red-100 text-red-700',
};

export default function FarmerMarketplaceAdminPage() {
  const { user, loading: authLoading } = useAuth();
  const router = useRouter();

  const [posts, setPosts] = useState<FarmerPost[]>([]);
  const [fetching, setFetching] = useState(true);
  const [toast, setToast] = useState<{ msg: string; ok: boolean } | null>(null);
  const [statusFilter, setStatusFilter] = useState<'ALL' | PostStatus>('ALL');
  const [moderationFilter, setModerationFilter] = useState<'ALL' | ModerationStatus>('PENDING');
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

  const moderate = async (post: FarmerPost, approved: boolean) => {
    let reason: string | undefined;
    if (!approved) {
      reason = prompt(`Reason for rejecting this ${post.commodity} listing (shown to the seller):`) || undefined;
      if (reason === undefined) return; // cancelled
    }
    try {
      await api.patch(`/farmer-marketplace/posts/${post.id}/moderate`, { approved, reason });
      showToast(approved ? 'Listing approved — now live.' : 'Listing rejected.', true);
      fetchPosts();
    } catch {
      showToast('Could not update moderation status.', false);
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

  const visiblePosts = posts
    .filter((p) => statusFilter === 'ALL' || p.status === statusFilter)
    .filter((p) => moderationFilter === 'ALL' || p.moderationStatus === moderationFilter);

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
          <h1 className="text-xl font-black text-gray-900 flex items-center gap-2">🌾 Wholesale &amp; Bulk Commodity Marketplace</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            Approve or reject new listings, verify sellers and buyers, and manage post status. Live commodity data —
            no separate save step, each action applies immediately.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <select
            value={moderationFilter}
            onChange={(e) => setModerationFilter(e.target.value as 'ALL' | ModerationStatus)}
            className="border border-gray-200 rounded-lg px-3 py-2 text-sm bg-white"
          >
            <option value="PENDING">📥 Pending review</option>
            <option value="APPROVED">✅ Approved (live)</option>
            <option value="REJECTED">🚫 Rejected</option>
            <option value="ALL">All moderation statuses</option>
          </select>
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
                {post.images?.[0] && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={post.images[0]} alt={post.commodity} className="w-14 h-14 rounded-lg object-cover border border-gray-100 shrink-0" />
                )}
                <button onClick={() => toggleExpand(post.id)} className="text-left flex-1 min-w-[220px]">
                  <p className="font-bold text-gray-900 text-sm flex items-center gap-2 flex-wrap">
                    {post.commodity}
                    <span className={`text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full ${MODERATION_STYLE[post.moderationStatus]}`}>
                      {post.moderationStatus === 'PENDING' ? '📥 Pending review' : post.moderationStatus === 'APPROVED' ? '✅ Live' : '🚫 Rejected'}
                    </span>
                    <span className={`text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full ${STATUS_STYLE[post.status]}`}>{post.status}</span>
                    {post.verifiedSeller && <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-premium-navy/10 text-premium-navy">Verified seller</span>}
                    {post.videoUrl && <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-slate-100 text-slate-600">🎥 Video</span>}
                  </p>
                  <p className="text-xs text-gray-500 mt-0.5">
                    {post.farmerName} · {post.quantity.toLocaleString()} {post.unit} · {post.location} · min {money(post.minPricePerUnit, post.currency)}/{post.unit}
                    {post.offerCount > 0 && <> · {post.offerCount} offer{post.offerCount === 1 ? '' : 's'}</>}
                  </p>
                  {post.farmerPhone && (
                    <p className="text-[11px] text-gray-400 mt-0.5">📞 {post.farmerPhone}{post.isWhatsapp ? ' (WhatsApp)' : ''}</p>
                  )}
                  {post.moderationStatus === 'REJECTED' && post.rejectionReason && (
                    <p className="text-[11px] text-red-600 mt-0.5">Reason given: {post.rejectionReason}</p>
                  )}
                </button>

                <div className="flex items-center gap-1.5 flex-wrap">
                  {post.moderationStatus !== 'APPROVED' && (
                    <button onClick={() => moderate(post, true)} className="text-xs font-semibold px-2.5 py-1.5 rounded-lg border border-emerald-200 text-emerald-700 hover:bg-emerald-50">
                      ✅ Approve
                    </button>
                  )}
                  {post.moderationStatus !== 'REJECTED' && (
                    <button onClick={() => moderate(post, false)} className="text-xs font-semibold px-2.5 py-1.5 rounded-lg border border-red-200 text-red-600 hover:bg-red-50">
                      🚫 Reject
                    </button>
                  )}
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
