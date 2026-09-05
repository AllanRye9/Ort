'use client';

/**
 * FarmerMarketplaceSection
 *
 * The "Farmer Marketplace" tab on /market-prices. This is the transactional
 * layer described in the product brief:
 *   Farmer posts commodity → buyers in different regions quote a price →
 *   the system calculates commodity price + transport + storage + platform
 *   fee = delivered price.
 *
 * Also surfaces the pieces that start closing the information-asymmetry
 * gap: verified-seller / verified-buyer badges, a quality grade, warehouse
 * availability, regional price comparison, and price history. See the
 * SCOPE NOTE at the top of backend/src/routes/farmerMarketplace.ts for what
 * is intentionally NOT built yet (escrow/payment, real logistics matching,
 * digital-weighbridge integration, AI demand forecasting) and why.
 */

import { useEffect, useMemo, useState } from 'react';
import { api } from '@/lib/api';
import { useAuth } from '@/context/AuthContext';
import { useToast } from '@/components/ui/Toast';

/* ─── Types ──────────────────────────────────────────────────────────────── */

type QualityGrade = 'A' | 'B' | 'C' | 'UNGRADED';
type Availability = 'IMMEDIATE' | 'DATE';
type PostStatus = 'OPEN' | 'MATCHED' | 'CLOSED';

interface FarmerPost {
  id: string;
  farmerId: string | null;
  farmerName: string;
  farmerPhone: string | null;
  verifiedSeller: boolean;
  commodity: string;
  quantity: number;
  unit: string;
  location: string;
  qualityGrade: QualityGrade;
  availability: Availability;
  availableFrom: string | null;
  minPricePerUnit: number;
  currency: string;
  status: PostStatus;
  warehouseAvailable: boolean;
  storageLocation: string | null;
  verifiedWeightKg: number | null;
  notes: string | null;
  offerCount?: number;
  bestDeliveredPricePerUnit?: number | null;
}

interface BuyerOffer {
  id: string;
  buyerId: string | null;
  buyerName: string;
  buyerLocation: string;
  verifiedBuyer: boolean;
  commodityPricePerUnit: number;
  transportPerUnit: number;
  storagePerUnit: number;
  platformFeePercent: number;
  subtotal: number;
  feeAmount: number;
  deliveredPricePerUnit: number;
  notes: string | null;
}

interface RegionalPrice {
  region: string;
  averageDeliveredPricePerUnit: number;
  offerCount: number;
}

interface PriceHistoryPoint {
  price: number;
  at: string;
  location: string;
}

type Trend = 'RISING' | 'FALLING' | 'STABLE' | 'UNKNOWN';

/* ─── Helpers ────────────────────────────────────────────────────────────── */

function money(value: number, currency = 'UGX'): string {
  return `${currency} ${value.toLocaleString('en-UG', { maximumFractionDigits: value % 1 === 0 ? 0 : 2 })}`;
}

const GRADE_LABEL: Record<QualityGrade, string> = { A: 'Grade A', B: 'Grade B', C: 'Grade C', UNGRADED: 'Ungraded' };

// A directional read of price-history data that's already happened — never
// framed as a prediction. See the SCOPE NOTE in
// backend/src/routes/farmerMarketplace.ts for why this stops short of
// "AI price predictions."
function TrendBadge({ trend, changePercent }: { trend: Trend; changePercent: number | null }) {
  if (trend === 'UNKNOWN') return null;
  const style = trend === 'RISING' ? 'bg-emerald-100 text-emerald-700' : trend === 'FALLING' ? 'bg-red-100 text-red-700' : 'bg-gray-100 text-gray-600';
  const arrow = trend === 'RISING' ? '↑' : trend === 'FALLING' ? '↓' : '→';
  const label = trend === 'RISING' ? 'Rising' : trend === 'FALLING' ? 'Falling' : 'Stable';
  return (
    <span className={`text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full ${style}`}>
      {arrow} {label}{changePercent != null && Math.abs(changePercent) >= 1 ? ` ${Math.abs(changePercent)}%` : ''}
    </span>
  );
}

const emptyPostForm = {
  farmerName: '', farmerPhone: '', commodity: '', quantity: '', unit: 'kg', location: '',
  qualityGrade: 'UNGRADED' as QualityGrade, availability: 'IMMEDIATE' as Availability, availableFrom: '',
  minPricePerUnit: '', warehouseAvailable: false, storageLocation: '', notes: '',
};

const emptyOfferForm = {
  buyerName: '', buyerLocation: '', commodityPricePerUnit: '', transportPerUnit: '', storagePerUnit: '', notes: '',
};

/* ─── Component ──────────────────────────────────────────────────────────── */

export default function FarmerMarketplaceSection() {
  const { user } = useAuth();
  const { success, error: toastError } = useToast();
  const isAdmin = user?.role === 'ADMIN';

  const [posts, setPosts] = useState<FarmerPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [commodityFilter, setCommodityFilter] = useState('');
  const [locationFilter, setLocationFilter] = useState('');
  const [locations, setLocations] = useState<string[]>([]);

  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [selectedPost, setSelectedPost] = useState<FarmerPost | null>(null);
  const [offers, setOffers] = useState<BuyerOffer[]>([]);
  const [detailLoading, setDetailLoading] = useState(false);

  const [showPostForm, setShowPostForm] = useState(false);
  const [postForm, setPostForm] = useState(emptyPostForm);
  const [postSubmitting, setPostSubmitting] = useState(false);

  const [showOfferForm, setShowOfferForm] = useState(false);
  const [offerForm, setOfferForm] = useState(emptyOfferForm);
  const [offerSubmitting, setOfferSubmitting] = useState(false);

  const [regionalCommodity, setRegionalCommodity] = useState('');
  const [regionalPrices, setRegionalPrices] = useState<RegionalPrice[]>([]);
  const [historyPoints, setHistoryPoints] = useState<PriceHistoryPoint[]>([]);
  const [historyTrend, setHistoryTrend] = useState<{ trend: Trend; changePercent: number | null }>({ trend: 'UNKNOWN', changePercent: null });

  const loadPosts = () => {
    setLoading(true);
    return Promise.allSettled([
      api.get('/farmer-marketplace/posts', { params: { commodity: commodityFilter || undefined, location: locationFilter || undefined } }),
      api.get('/farmer-marketplace/locations'),
    ]).then(([postsResult, locationsResult]) => {
      if (postsResult.status === 'fulfilled') setPosts(postsResult.value.data?.posts || []);
      if (locationsResult.status === 'fulfilled') setLocations(locationsResult.value.data?.locations || []);
    }).finally(() => setLoading(false));
  };

  useEffect(() => { loadPosts(); }, [commodityFilter, locationFilter]); // eslint-disable-line react-hooks/exhaustive-deps

  const commodities = useMemo(() => [...new Set(posts.map((p) => p.commodity))].sort(), [posts]);

  const openDetail = (id: string) => {
    setSelectedId(id);
    setShowOfferForm(false);
    setOfferForm(emptyOfferForm);
    setDetailLoading(true);
    api.get(`/farmer-marketplace/posts/${id}`)
      .then(({ data }) => {
        setSelectedPost(data.post);
        setOffers(data.offers || []);
        setRegionalCommodity(data.post.commodity);
      })
      .catch(() => toastError('Could not load that post.'))
      .finally(() => setDetailLoading(false));
  };

  const closeDetail = () => { setSelectedId(null); setSelectedPost(null); setOffers([]); };

  useEffect(() => {
    if (!regionalCommodity) { setRegionalPrices([]); setHistoryPoints([]); setHistoryTrend({ trend: 'UNKNOWN', changePercent: null }); return; }
    api.get('/farmer-marketplace/regional-prices', { params: { commodity: regionalCommodity } })
      .then(({ data }) => setRegionalPrices(data?.regions || []))
      .catch(() => setRegionalPrices([]));
    api.get('/farmer-marketplace/price-history', { params: { commodity: regionalCommodity } })
      .then(({ data }) => {
        setHistoryPoints(data?.points || []);
        setHistoryTrend({ trend: data?.trend || 'UNKNOWN', changePercent: data?.changePercent ?? null });
      })
      .catch(() => { setHistoryPoints([]); setHistoryTrend({ trend: 'UNKNOWN', changePercent: null }); });
  }, [regionalCommodity]);

  const submitPost = async (e: React.FormEvent) => {
    e.preventDefault();
    const quantity = Number(postForm.quantity);
    const minPricePerUnit = Number(postForm.minPricePerUnit);
    if (!postForm.farmerName || !postForm.commodity || !postForm.location || !Number.isFinite(quantity) || quantity <= 0 || !Number.isFinite(minPricePerUnit) || minPricePerUnit < 0) {
      toastError('Please fill in farmer name, commodity, location, quantity and minimum price.');
      return;
    }
    setPostSubmitting(true);
    try {
      await api.post('/farmer-marketplace/posts', {
        ...postForm,
        quantity,
        minPricePerUnit,
        availableFrom: postForm.availability === 'DATE' ? postForm.availableFrom : undefined,
      });
      success('Your commodity has been posted to the marketplace.');
      setShowPostForm(false);
      setPostForm(emptyPostForm);
      loadPosts();
    } catch {
      toastError('Could not post your commodity — please check the details and try again.');
    } finally {
      setPostSubmitting(false);
    }
  };

  const submitOffer = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedId) return;
    const commodityPricePerUnit = Number(offerForm.commodityPricePerUnit);
    if (!offerForm.buyerName || !offerForm.buyerLocation || !Number.isFinite(commodityPricePerUnit) || commodityPricePerUnit < 0) {
      toastError('Please fill in buyer name, region, and a valid commodity price.');
      return;
    }
    setOfferSubmitting(true);
    try {
      await api.post(`/farmer-marketplace/posts/${selectedId}/offers`, {
        ...offerForm,
        commodityPricePerUnit,
        transportPerUnit: Number(offerForm.transportPerUnit) || 0,
        storagePerUnit: Number(offerForm.storagePerUnit) || 0,
      });
      success('Offer submitted.');
      setShowOfferForm(false);
      setOfferForm(emptyOfferForm);
      openDetail(selectedId);
      loadPosts();
    } catch {
      toastError('Could not submit that offer — please try again.');
    } finally {
      setOfferSubmitting(false);
    }
  };

  const verifyPost = async (id: string, verified: boolean) => {
    try {
      await api.patch(`/farmer-marketplace/posts/${id}/verify`, { verified });
      success(verified ? 'Seller marked as verified.' : 'Seller verification removed.');
      if (selectedId === id) openDetail(id);
      loadPosts();
    } catch {
      toastError('Could not update verification.');
    }
  };

  const verifyOffer = async (id: string, verified: boolean) => {
    try {
      await api.patch(`/farmer-marketplace/offers/${id}/verify`, { verified });
      success(verified ? 'Buyer marked as verified.' : 'Buyer verification removed.');
      if (selectedId) openDetail(selectedId);
    } catch {
      toastError('Could not update verification.');
    }
  };

  return (
    <div>
      {/* Intro strip */}
      <div className="rounded-2xl border border-green-100 bg-green-50/60 p-4 sm:p-5 mb-5">
        <h2 className="text-base sm:text-lg font-black text-gray-900 flex items-center gap-2">🚜 Farmer Marketplace</h2>
        <p className="text-xs sm:text-sm text-gray-500 mt-1 max-w-3xl">
          Farmers post real produce for sale. Buyers from different regions quote a price. The platform works out
          each quote&apos;s <strong>delivered price</strong> — commodity price + transport + storage + platform fee —
          so a farmer can compare offers on equal footing instead of guessing what a buyer&apos;s number actually means
          once it lands on their doorstep.
        </p>
        <button
          onClick={() => setShowPostForm((v) => !v)}
          className="mt-3 inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-green-700 hover:bg-green-800 text-white text-xs font-bold transition-colors"
        >
          {showPostForm ? 'Close form' : '+ Post a commodity for sale'}
        </button>
      </div>

      {/* Post-a-commodity form */}
      {showPostForm && (
        <form onSubmit={submitPost} className="bg-white rounded-xl border border-gray-200 shadow-sm p-4 mb-5 grid grid-cols-1 sm:grid-cols-2 gap-3">
          <input required placeholder="Farmer / group name" value={postForm.farmerName} onChange={(e) => setPostForm({ ...postForm, farmerName: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          <input placeholder="Phone (optional)" value={postForm.farmerPhone} onChange={(e) => setPostForm({ ...postForm, farmerPhone: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          <input required placeholder="Commodity (e.g. Maize)" value={postForm.commodity} onChange={(e) => setPostForm({ ...postForm, commodity: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          <input required placeholder="Location (e.g. Iganga)" value={postForm.location} onChange={(e) => setPostForm({ ...postForm, location: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          <input required type="number" min="0" placeholder="Quantity" value={postForm.quantity} onChange={(e) => setPostForm({ ...postForm, quantity: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          <input placeholder="Unit (default kg)" value={postForm.unit} onChange={(e) => setPostForm({ ...postForm, unit: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          <input required type="number" min="0" placeholder="Minimum price per unit (UGX)" value={postForm.minPricePerUnit} onChange={(e) => setPostForm({ ...postForm, minPricePerUnit: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          <select value={postForm.qualityGrade} onChange={(e) => setPostForm({ ...postForm, qualityGrade: e.target.value as QualityGrade })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm bg-white">
            <option value="UNGRADED">Quality grade: Ungraded</option>
            <option value="A">Quality grade: A</option>
            <option value="B">Quality grade: B</option>
            <option value="C">Quality grade: C</option>
          </select>
          <select value={postForm.availability} onChange={(e) => setPostForm({ ...postForm, availability: e.target.value as Availability })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm bg-white">
            <option value="IMMEDIATE">Available immediately</option>
            <option value="DATE">Available from a date</option>
          </select>
          {postForm.availability === 'DATE' && (
            <input type="date" value={postForm.availableFrom} onChange={(e) => setPostForm({ ...postForm, availableFrom: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          )}
          <label className="flex items-center gap-2 text-sm text-gray-600 sm:col-span-2">
            <input type="checkbox" checked={postForm.warehouseAvailable} onChange={(e) => setPostForm({ ...postForm, warehouseAvailable: e.target.checked })} />
            Warehouse storage available for this lot
          </label>
          {postForm.warehouseAvailable && (
            <input placeholder="Storage location" value={postForm.storageLocation} onChange={(e) => setPostForm({ ...postForm, storageLocation: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm sm:col-span-2" />
          )}
          <textarea placeholder="Notes (drying, sorting, certificates, etc.)" value={postForm.notes} onChange={(e) => setPostForm({ ...postForm, notes: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm sm:col-span-2" rows={2} />
          <button disabled={postSubmitting} type="submit" className="sm:col-span-2 inline-flex justify-center items-center gap-1.5 px-4 py-2.5 rounded-lg bg-green-700 hover:bg-green-800 disabled:opacity-50 text-white text-sm font-bold transition-colors">
            {postSubmitting ? 'Posting…' : 'Post commodity'}
          </button>
        </form>
      )}

      {/* Filters */}
      <div className="flex flex-wrap gap-2 mb-4">
        <input value={commodityFilter} onChange={(e) => setCommodityFilter(e.target.value)} placeholder="Search commodity…" className="border border-gray-200 rounded-lg px-3 py-2 text-sm flex-1 min-w-[160px]" />
        <select value={locationFilter} onChange={(e) => setLocationFilter(e.target.value)} className="border border-gray-200 rounded-lg px-3 py-2 text-sm bg-white">
          <option value="">All locations</option>
          {locations.map((loc) => <option key={loc} value={loc}>{loc}</option>)}
        </select>
      </div>

      {/* Post grid */}
      {loading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {Array.from({ length: 6 }).map((_, i) => <div key={i} className="h-40 rounded-xl bg-gray-100 animate-pulse" />)}
        </div>
      ) : posts.length === 0 ? (
        <div className="text-center py-14 text-gray-400">
          <p className="text-4xl mb-2">🌾</p>
          <p className="text-sm">No farmer posts match your search yet.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 mb-8">
          {posts.map((post) => (
            <button
              key={post.id}
              onClick={() => openDetail(post.id)}
              className="text-left group relative flex flex-col overflow-hidden rounded-xl bg-white border border-gray-100 shadow-sm p-4 transition-all duration-300 hover:shadow-xl hover:-translate-y-1 hover:border-green-100"
            >
              <div className="flex items-start justify-between gap-2 mb-1.5">
                <h3 className="font-bold text-gray-900 text-sm min-w-0 truncate" title={post.commodity}>{post.commodity}</h3>
                {post.verifiedSeller && (
                  <span className="shrink-0 text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-emerald-100 text-emerald-700">Verified</span>
                )}
              </div>
              <p className="text-xs text-gray-500">{post.quantity.toLocaleString()} {post.unit} · {post.location}</p>
              <div className="flex items-center gap-1.5 mt-1.5">
                <span className={`text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full ${post.availability === 'IMMEDIATE' ? 'bg-orange-100 text-orange-700' : 'bg-slate-100 text-slate-600'}`}>
                  {post.availability === 'IMMEDIATE' ? 'Available now' : 'Available soon'}
                </span>
                <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-premium-navy/10 text-premium-navy">{GRADE_LABEL[post.qualityGrade]}</span>
                {post.warehouseAvailable && <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-blue-50 text-blue-700">Warehouse</span>}
              </div>
              <div className="mt-3 pt-2 border-t border-gray-50">
                <p className="text-[10px] text-gray-400">Farmer&apos;s minimum</p>
                <p className="text-lg font-black text-green-700 tabular-nums leading-none">{money(post.minPricePerUnit, post.currency)}<span className="text-xs font-semibold text-gray-400">/{post.unit}</span></p>
                {(post.offerCount ?? 0) > 0 ? (
                  <p className="text-[11px] text-gray-500 mt-1">{post.offerCount} offer{post.offerCount === 1 ? '' : 's'} · best delivered <span className="font-bold text-gray-700">{money(post.bestDeliveredPricePerUnit || 0, post.currency)}</span></p>
                ) : (
                  <p className="text-[11px] text-gray-400 mt-1">No buyer offers yet</p>
                )}
              </div>
            </button>
          ))}
        </div>
      )}

      {/* Post detail panel */}
      {selectedId && (
        <div className="fixed inset-0 z-40 flex items-end sm:items-center justify-center bg-black/40 p-0 sm:p-4" onClick={closeDetail}>
          <div className="bg-white w-full sm:max-w-2xl sm:rounded-2xl rounded-t-2xl max-h-[90vh] overflow-y-auto shadow-2xl" onClick={(e) => e.stopPropagation()}>
            {detailLoading || !selectedPost ? (
              <div className="p-8 text-center text-gray-400 text-sm">Loading…</div>
            ) : (
              <div className="p-5">
                <div className="flex items-start justify-between gap-3 mb-1">
                  <div className="min-w-0">
                    <h3 className="text-lg font-black text-gray-900 flex flex-wrap items-center gap-2">
                      <span className="truncate">{selectedPost.commodity}</span>
                      {selectedPost.verifiedSeller && <span className="shrink-0 text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-emerald-100 text-emerald-700">Verified seller</span>}
                    </h3>
                    <p className="text-xs text-gray-500">{selectedPost.farmerName} · {selectedPost.quantity.toLocaleString()} {selectedPost.unit} · {selectedPost.location}</p>
                  </div>
                  <button onClick={closeDetail} className="shrink-0 text-gray-400 hover:text-gray-600 text-xl leading-none">×</button>
                </div>

                {selectedPost.notes && <p className="text-xs text-gray-500 mt-2 bg-gray-50 rounded-lg p-2.5">{selectedPost.notes}</p>}

                <div className="flex flex-wrap gap-1.5 mt-2.5">
                  <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-premium-navy/10 text-premium-navy">{GRADE_LABEL[selectedPost.qualityGrade]}</span>
                  {selectedPost.warehouseAvailable && <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-blue-50 text-blue-700">Warehouse: {selectedPost.storageLocation || 'available'}</span>}
                  {selectedPost.verifiedWeightKg != null && <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-gray-100 text-gray-600">Verified weight: {selectedPost.verifiedWeightKg.toLocaleString()} kg</span>}
                </div>

                {isAdmin && (
                  selectedPost.farmerId ? (
                    <a href="/admin/kyc" className="mt-2 inline-block text-[11px] font-semibold text-premium-navy hover:underline">
                      This seller has an account — review identity verification in KYC →
                    </a>
                  ) : (
                    <button onClick={() => verifyPost(selectedPost.id, !selectedPost.verifiedSeller)} className="mt-2 text-[11px] font-semibold text-premium-navy hover:underline">
                      {selectedPost.verifiedSeller ? 'Remove seller verification' : 'Mark seller as verified'}
                    </button>
                  )
                )}

                <p className="text-[11px] font-black uppercase tracking-wider text-gray-400 mt-4 mb-2">Buyer offers · delivered price</p>
                {offers.length === 0 ? (
                  <p className="text-xs text-gray-400">No offers yet — be the first buyer to quote.</p>
                ) : (
                  <div className="space-y-2">
                    {offers.map((offer) => (
                      <div key={offer.id} className="rounded-lg border border-gray-100 p-3">
                        <div className="flex flex-wrap items-center justify-between gap-2">
                          <p className="text-sm font-bold text-gray-800 flex flex-wrap items-center gap-1.5 min-w-0">
                            <span className="truncate">{offer.buyerName}</span>
                            <span className="text-xs font-normal text-gray-400 whitespace-nowrap">· {offer.buyerLocation}</span>
                            {offer.verifiedBuyer && <span className="shrink-0 text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-emerald-100 text-emerald-700">Verified</span>}
                          </p>
                          <p className="shrink-0 text-base font-black text-green-700 tabular-nums">{money(offer.deliveredPricePerUnit, selectedPost.currency)}</p>
                        </div>
                        <p className="text-[11px] text-gray-400 mt-1">
                          {money(offer.commodityPricePerUnit, selectedPost.currency)} commodity + {money(offer.transportPerUnit, selectedPost.currency)} transport + {money(offer.storagePerUnit, selectedPost.currency)} storage + {offer.platformFeePercent}% platform fee = delivered price
                        </p>
                        {offer.notes && <p className="text-[11px] text-gray-500 mt-1">{offer.notes}</p>}
                        {isAdmin && (
                          offer.buyerId ? (
                            <a href="/admin/kyc" className="mt-1.5 inline-block text-[11px] font-semibold text-premium-navy hover:underline">
                              Registered buyer — review in KYC →
                            </a>
                          ) : (
                            <button onClick={() => verifyOffer(offer.id, !offer.verifiedBuyer)} className="mt-1.5 text-[11px] font-semibold text-premium-navy hover:underline">
                              {offer.verifiedBuyer ? 'Remove buyer verification' : 'Mark buyer as verified'}
                            </button>
                          )
                        )}
                      </div>
                    ))}
                  </div>
                )}

                {selectedPost.status !== 'CLOSED' && (
                  <div className="mt-4">
                    <button onClick={() => setShowOfferForm((v) => !v)} className="text-xs font-bold text-green-700 hover:text-green-800">
                      {showOfferForm ? 'Cancel' : '+ Quote a price as a buyer'}
                    </button>
                    {showOfferForm && (
                      <form onSubmit={submitOffer} className="mt-2 grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                        <input required placeholder="Buyer / company name" value={offerForm.buyerName} onChange={(e) => setOfferForm({ ...offerForm, buyerName: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm" />
                        <input required placeholder="Buyer region (e.g. Kampala, Export)" value={offerForm.buyerLocation} onChange={(e) => setOfferForm({ ...offerForm, buyerLocation: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm" />
                        <input required type="number" min="0" placeholder="Commodity price / unit" value={offerForm.commodityPricePerUnit} onChange={(e) => setOfferForm({ ...offerForm, commodityPricePerUnit: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm" />
                        <input type="number" min="0" placeholder="Transport / unit" value={offerForm.transportPerUnit} onChange={(e) => setOfferForm({ ...offerForm, transportPerUnit: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm" />
                        <input type="number" min="0" placeholder="Storage / unit" value={offerForm.storagePerUnit} onChange={(e) => setOfferForm({ ...offerForm, storagePerUnit: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm" />
                        <input placeholder="Notes (optional)" value={offerForm.notes} onChange={(e) => setOfferForm({ ...offerForm, notes: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm" />
                        <button disabled={offerSubmitting} type="submit" className="sm:col-span-2 inline-flex justify-center items-center gap-1.5 px-4 py-2.5 rounded-lg bg-green-700 hover:bg-green-800 disabled:opacity-50 text-white text-sm font-bold transition-colors">
                          {offerSubmitting ? 'Submitting…' : 'Submit offer'}
                        </button>
                      </form>
                    )}
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Regional price comparison + price history */}
      {commodities.length > 0 && (
        <div className="rounded-xl border border-gray-200 bg-white shadow-sm p-4">
          <div className="flex items-center justify-between flex-wrap gap-2 mb-3">
            <p className="text-sm font-black text-gray-800">Regional price comparison &amp; price history</p>
            <select value={regionalCommodity} onChange={(e) => setRegionalCommodity(e.target.value)} className="border border-gray-200 rounded-lg px-3 py-1.5 text-xs bg-white">
              {commodities.map((c) => <option key={c} value={c}>{c}</option>)}
            </select>
          </div>

          <div className="grid sm:grid-cols-2 gap-4">
            <div>
              <p className="text-[11px] font-black uppercase tracking-wider text-gray-400 mb-2">Avg. delivered price by region</p>
              {regionalPrices.length === 0 ? (
                <p className="text-xs text-gray-400">No buyer offers yet for this commodity.</p>
              ) : (
                <div className="space-y-1.5">
                  {regionalPrices.map((r) => (
                    <div key={r.region} className="flex items-center justify-between text-xs">
                      <span className="font-semibold text-gray-700">{r.region} <span className="text-gray-400 font-normal">({r.offerCount})</span></span>
                      <span className="font-bold text-green-700">{money(r.averageDeliveredPricePerUnit)}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
            <div>
              <p className="text-[11px] font-black uppercase tracking-wider text-gray-400 mb-2 flex items-center gap-1.5">
                Farmer minimum-price history <TrendBadge trend={historyTrend.trend} changePercent={historyTrend.changePercent} />
              </p>
              {historyPoints.length === 0 ? (
                <p className="text-xs text-gray-400">No price changes recorded yet.</p>
              ) : (
                <div className="space-y-1.5 max-h-40 overflow-y-auto">
                  {historyPoints.slice(-8).reverse().map((p, i) => (
                    <div key={i} className="flex items-center justify-between text-xs">
                      <span className="text-gray-500">{p.location} · {new Date(p.at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}</span>
                      <span className="font-bold text-gray-700">{money(p.price)}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      <p className="text-xs text-gray-400 mt-6 text-center max-w-2xl mx-auto">
        Payments and delivery are still arranged directly between farmer and buyer — the platform calculates and
        displays the delivered price and offer history, but does not yet hold funds in escrow or dispatch logistics.
        Those need dedicated payment-gateway and logistics-partner integrations and are on the roadmap.
      </p>
    </div>
  );
}
