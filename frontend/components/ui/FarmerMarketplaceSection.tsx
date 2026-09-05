'use client';

/**
 * FarmerMarketplaceSection — Uganda Wholesale & Bulk Commodity Marketplace
 *
 * Merged into the single /market-prices page (see app/market-prices/page.tsx)
 * alongside the admin-curated reference price board. This is the
 * transactional layer described in the product brief:
 *   Seller posts a bulk commodity lot (with mandatory photos + location) →
 *   buyers in different regions quote a price → the system calculates
 *   commodity price + transport + storage + platform fee = delivered price.
 *
 * This section is deliberately scoped to wholesalers, manufacturers, and
 * brokers dealing in bulk quantities — it is NOT surfaced anywhere else on
 * the site (no homepage teaser), since every other section targets everyday
 * consumers/retailers. See app/page.tsx for that removal.
 *
 * Posting requires being signed in: every listing needs at least one photo
 * and goes through admin moderation (see the SCOPE NOTE and moderation
 * notes in backend/src/routes/farmerMarketplace.ts), so anonymous/guest
 * posting is no longer supported now that media + accountable ownership are
 * required. A seller's phone number is never shown as copyable text to a
 * regular buyer — only click-to-contact WhatsApp/Call buttons, built from a
 * `contact` object the backend computes (see that file for the masking
 * caveat: a tel:/wa.me link still has to carry the number to function).
 *
 * Also surfaces the pieces that start closing the information-asymmetry
 * gap: verified-seller / verified-buyer badges, a quality grade, warehouse
 * availability, regional price comparison, and price history. See the
 * SCOPE NOTE at the top of backend/src/routes/farmerMarketplace.ts for what
 * is intentionally NOT built yet (escrow/payment, real logistics matching,
 * digital-weighbridge integration, AI demand forecasting) and why.
 */

import { useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { api } from '@/lib/api';
import { useAuth } from '@/context/AuthContext';
import { useToast } from '@/components/ui/Toast';

/* ─── Types ──────────────────────────────────────────────────────────────── */

type QualityGrade = 'A' | 'B' | 'C' | 'UNGRADED';
type Availability = 'IMMEDIATE' | 'DATE';
type PostStatus = 'OPEN' | 'MATCHED' | 'CLOSED';
type ModerationStatus = 'PENDING' | 'APPROVED' | 'REJECTED';

interface ContactLinks {
  whatsappUrl: string | null;
  callUrl: string | null;
}

interface FarmerPost {
  id: string;
  farmerId?: string | null;
  farmerName: string;
  /** Only present when the caller is the post's owner or an admin — see
   *  toPublicPost() in the backend route. Regular buyers get `contact`
   *  instead and never see this field at all. */
  farmerPhone?: string;
  isWhatsapp: boolean;
  contact?: ContactLinks | null;
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
  moderationStatus: ModerationStatus;
  rejectionReason: string | null;
  images: string[];
  videoUrl: string | null;
  warehouseAvailable: boolean;
  storageLocation: string | null;
  verifiedWeightKg: number | null;
  notes: string | null;
  offerCount?: number;
  bestDeliveredPricePerUnit?: number | null;
}

interface BuyerOffer {
  id: string;
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

/* ─── Helpers ────────────────────────────────────────────────────────────── */

function money(value: number, currency = 'UGX'): string {
  return `${currency} ${value.toLocaleString('en-UG', { maximumFractionDigits: value % 1 === 0 ? 0 : 2 })}`;
}

const GRADE_LABEL: Record<QualityGrade, string> = { A: 'Grade A', B: 'Grade B', C: 'Grade C', UNGRADED: 'Ungraded' };

// Icons here intentionally mirror the emoji-icon convention used at
// /portal/settings (👤 profile, 📦 listings, 💳 billing, etc.) rather than
// introducing a separate icon library, so the posting form's field icons
// read as "the same app" as the rest of the account/settings surface.
const FIELD_ICON = {
  name: '👤', phone: '📞', commodity: '📦', location: '📍', quantity: '⚖️',
  price: '💵', images: '📸', video: '🎥', notes: '📝', warehouse: '🏬',
};

const MAX_VIDEO_SECONDS = 60;
const MAX_IMAGES = 8;

const emptyPostForm = {
  farmerName: '', farmerPhone: '', commodity: '', quantity: '', unit: 'kg', location: '',
  qualityGrade: 'UNGRADED' as QualityGrade, availability: 'IMMEDIATE' as Availability, availableFrom: '',
  minPricePerUnit: '', warehouseAvailable: false, storageLocation: '', notes: '', isWhatsapp: false,
};

const emptyOfferForm = {
  buyerName: '', buyerLocation: '', commodityPricePerUnit: '', transportPerUnit: '', storagePerUnit: '', notes: '',
};

/** Reads a local video file's duration via a throwaway <video> element,
 *  without uploading anything. Used to enforce the < 60s showcase-clip
 *  limit client-side before the file ever reaches the network — there is
 *  no server-side media tooling (ffprobe, etc.) in this stack to re-check
 *  duration once uploaded. */
function readVideoDuration(file: File): Promise<number> {
  return new Promise((resolve, reject) => {
    const video = document.createElement('video');
    video.preload = 'metadata';
    const url = URL.createObjectURL(file);
    video.src = url;
    video.onloadedmetadata = () => {
      URL.revokeObjectURL(url);
      resolve(video.duration);
    };
    video.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('Could not read video metadata'));
    };
  });
}

/* ─── Component ──────────────────────────────────────────────────────────── */

export default function FarmerMarketplaceSection() {
  const { user } = useAuth();
  const { success, error: toastError } = useToast();
  const isAdmin = user?.role === 'ADMIN';

  const [posts, setPosts] = useState<FarmerPost[]>([]);
  const [myPosts, setMyPosts] = useState<FarmerPost[]>([]);
  const [mineLoading, setMineLoading] = useState(false);
  const [viewMine, setViewMine] = useState(false);
  const [loading, setLoading] = useState(true);
  const [commodityFilter, setCommodityFilter] = useState('');
  const [locationFilter, setLocationFilter] = useState('');
  const [locations, setLocations] = useState<string[]>([]);

  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [selectedPost, setSelectedPost] = useState<FarmerPost | null>(null);
  const [offers, setOffers] = useState<BuyerOffer[]>([]);
  const [detailLoading, setDetailLoading] = useState(false);

  const [showPostForm, setShowPostForm] = useState(false);
  const [editingPostId, setEditingPostId] = useState<string | null>(null);
  const [postForm, setPostForm] = useState(emptyPostForm);
  const [postSubmitting, setPostSubmitting] = useState(false);

  const [images, setImages] = useState<string[]>([]);
  const [uploadingImages, setUploadingImages] = useState(false);
  const [videoUrl, setVideoUrl] = useState<string | null>(null);
  const [uploadingVideo, setUploadingVideo] = useState(false);
  const imageInputRef = useRef<HTMLInputElement>(null);
  const videoInputRef = useRef<HTMLInputElement>(null);

  const [showOfferForm, setShowOfferForm] = useState(false);
  const [offerForm, setOfferForm] = useState(emptyOfferForm);
  const [offerSubmitting, setOfferSubmitting] = useState(false);

  const [regionalCommodity, setRegionalCommodity] = useState('');
  const [regionalPrices, setRegionalPrices] = useState<RegionalPrice[]>([]);
  const [historyPoints, setHistoryPoints] = useState<PriceHistoryPoint[]>([]);

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

  const loadMyPosts = () => {
    if (!user) return;
    setMineLoading(true);
    api.get('/farmer-marketplace/posts/mine')
      .then(({ data }) => setMyPosts(data?.posts || []))
      .catch(() => toastError('Could not load your listings.'))
      .finally(() => setMineLoading(false));
  };

  useEffect(() => { loadPosts(); }, [commodityFilter, locationFilter]); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { if (user) loadMyPosts(); }, [user]); // eslint-disable-line react-hooks/exhaustive-deps

  const visiblePosts = viewMine ? myPosts : posts;
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
    if (!regionalCommodity) { setRegionalPrices([]); setHistoryPoints([]); return; }
    api.get('/farmer-marketplace/regional-prices', { params: { commodity: regionalCommodity } })
      .then(({ data }) => setRegionalPrices(data?.regions || []))
      .catch(() => setRegionalPrices([]));
    api.get('/farmer-marketplace/price-history', { params: { commodity: regionalCommodity } })
      .then(({ data }) => setHistoryPoints(data?.points || []))
      .catch(() => setHistoryPoints([]));
  }, [regionalCommodity]);

  const resetForm = () => {
    setPostForm(emptyPostForm);
    setImages([]);
    setVideoUrl(null);
    setEditingPostId(null);
  };

  const startEdit = (post: FarmerPost) => {
    setEditingPostId(post.id);
    setPostForm({
      farmerName: post.farmerName,
      farmerPhone: post.farmerPhone || '',
      commodity: post.commodity,
      quantity: String(post.quantity),
      unit: post.unit,
      location: post.location,
      qualityGrade: post.qualityGrade,
      availability: post.availability,
      availableFrom: post.availableFrom || '',
      minPricePerUnit: String(post.minPricePerUnit),
      warehouseAvailable: post.warehouseAvailable,
      storageLocation: post.storageLocation || '',
      notes: post.notes || '',
      isWhatsapp: post.isWhatsapp,
    });
    setImages(post.images || []);
    setVideoUrl(post.videoUrl || null);
    setShowPostForm(true);
  };

  const handleImageFiles = async (files: FileList | null) => {
    if (!files || files.length === 0) return;
    if (images.length >= MAX_IMAGES) {
      toastError(`You can attach up to ${MAX_IMAGES} images.`);
      return;
    }
    setUploadingImages(true);
    try {
      const formData = new FormData();
      for (const file of Array.from(files).slice(0, MAX_IMAGES - images.length)) {
        formData.append('images', file);
      }
      const { data } = await api.post('/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
        params: { country: 'UGANDA', categorySlug: 'wholesale-marketplace' },
      });
      const urls: string[] = data?.urls || [];
      setImages((prev) => [...prev, ...urls]);
    } catch {
      toastError('Image upload failed. Please try again.');
    } finally {
      setUploadingImages(false);
      if (imageInputRef.current) imageInputRef.current.value = '';
    }
  };

  const removeImage = (url: string) => setImages((prev) => prev.filter((u) => u !== url));

  const handleVideoFile = async (file: File | null) => {
    if (!file) return;
    try {
      const duration = await readVideoDuration(file);
      if (duration > MAX_VIDEO_SECONDS) {
        toastError(`That video is ${Math.round(duration)}s long — please choose a clip under ${MAX_VIDEO_SECONDS} seconds.`);
        if (videoInputRef.current) videoInputRef.current.value = '';
        return;
      }
    } catch {
      toastError('Could not read that video file — please try a different clip.');
      if (videoInputRef.current) videoInputRef.current.value = '';
      return;
    }

    setUploadingVideo(true);
    try {
      const formData = new FormData();
      formData.append('video', file);
      const { data } = await api.post('/upload/video', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      setVideoUrl(data?.url || null);
    } catch {
      toastError('Video upload failed. Please try again.');
    } finally {
      setUploadingVideo(false);
      if (videoInputRef.current) videoInputRef.current.value = '';
    }
  };

  const submitPost = async (e: React.FormEvent) => {
    e.preventDefault();
    const quantity = Number(postForm.quantity);
    const minPricePerUnit = Number(postForm.minPricePerUnit);
    if (!postForm.farmerName || !postForm.commodity || !postForm.location || !postForm.farmerPhone
      || !Number.isFinite(quantity) || quantity <= 0 || !Number.isFinite(minPricePerUnit) || minPricePerUnit < 0) {
      toastError('Please fill in your name, phone number, commodity, location, quantity and minimum price.');
      return;
    }
    if (images.length === 0) {
      toastError('At least one photo is required before you can post this listing.');
      return;
    }
    setPostSubmitting(true);
    try {
      const payload = {
        ...postForm,
        quantity,
        minPricePerUnit,
        images,
        videoUrl,
        availableFrom: postForm.availability === 'DATE' ? postForm.availableFrom : undefined,
      };
      if (editingPostId) {
        await api.patch(`/farmer-marketplace/posts/${editingPostId}`, payload);
        success('Listing updated — it will be re-reviewed before it goes back live.');
      } else {
        await api.post('/farmer-marketplace/posts', payload);
        success('Listing submitted — it will appear once an admin approves it.');
      }
      setShowPostForm(false);
      resetForm();
      loadPosts();
      loadMyPosts();
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { message?: string } } })?.response?.data?.message;
      toastError(msg || 'Could not save your listing — please check the details and try again.');
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

  const MODERATION_STYLE: Record<ModerationStatus, string> = {
    PENDING: 'bg-amber-100 text-amber-700',
    APPROVED: 'bg-emerald-100 text-emerald-700',
    REJECTED: 'bg-red-100 text-red-700',
  };
  const MODERATION_LABEL: Record<ModerationStatus, string> = {
    PENDING: 'Pending review', APPROVED: 'Live', REJECTED: 'Rejected',
  };

  return (
    <div>
      {/* Intro strip */}
      <div className="rounded-2xl border border-green-100 bg-green-50/60 p-4 sm:p-5 mb-5">
        <h2 className="text-base sm:text-lg font-black text-gray-900 flex items-center gap-2">🇺🇬 Uganda Wholesale &amp; Bulk Commodity Marketplace</h2>
        <p className="text-xs sm:text-sm text-gray-500 mt-1 max-w-3xl">
          Built for wholesalers, manufacturers, and brokers dealing in bulk quantities — not the everyday retail
          listings found elsewhere on the site. Sellers post real produce/commodity lots with photos; buyers from
          different regions quote a price, and the platform works out each quote&apos;s <strong>delivered price</strong> —
          commodity price + transport + storage + platform fee — so a seller can compare offers on equal footing.
          All prices on this page are in Ugandan Shillings (UGX).
        </p>
        <div className="flex flex-wrap items-center gap-2 mt-3">
          {user ? (
            <button
              onClick={() => { if (showPostForm) { setShowPostForm(false); resetForm(); } else { resetForm(); setShowPostForm(true); } }}
              className="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-green-700 hover:bg-green-800 text-white text-xs font-bold transition-colors"
            >
              {showPostForm ? 'Close form' : `${FIELD_ICON.commodity} Post a bulk listing`}
            </button>
          ) : (
            <Link
              href="/auth/login"
              className="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-green-700 hover:bg-green-800 text-white text-xs font-bold transition-colors"
            >
              Log in to post a listing
            </Link>
          )}
          {user && (
            <button
              onClick={() => setViewMine((v) => !v)}
              className={`inline-flex items-center gap-1.5 px-4 py-2 rounded-lg border text-xs font-bold transition-colors ${viewMine ? 'border-green-700 text-green-700 bg-white' : 'border-gray-200 text-gray-600 bg-white hover:border-green-300'}`}
            >
              {viewMine ? 'Showing: My listings' : 'My listings'}
            </button>
          )}
        </div>
      </div>

      {/* Post / edit form */}
      {showPostForm && (
        <form onSubmit={submitPost} className="bg-white rounded-xl border border-gray-200 shadow-sm p-4 mb-5 grid grid-cols-1 sm:grid-cols-2 gap-3">
          <p className="sm:col-span-2 text-xs font-bold text-gray-400 uppercase tracking-wide">{editingPostId ? 'Edit listing' : 'New listing'} — 🇺🇬 Uganda · UGX</p>

          <div className="relative">
            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm" aria-hidden="true">{FIELD_ICON.name}</span>
            <input required placeholder="Your name / business name" value={postForm.farmerName} onChange={(e) => setPostForm({ ...postForm, farmerName: e.target.value })} className="w-full border border-gray-200 rounded-lg pl-9 pr-3 py-2 text-sm" />
          </div>
          <div className="relative">
            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm" aria-hidden="true">{FIELD_ICON.phone}</span>
            <input required placeholder="Contact phone number" value={postForm.farmerPhone} onChange={(e) => setPostForm({ ...postForm, farmerPhone: e.target.value })} className="w-full border border-gray-200 rounded-lg pl-9 pr-3 py-2 text-sm" />
          </div>
          <label className="flex items-center gap-2 text-sm text-gray-600 sm:col-span-2 -mt-1">
            <input type="checkbox" checked={postForm.isWhatsapp} onChange={(e) => setPostForm({ ...postForm, isWhatsapp: e.target.checked })} />
            💬 This number is on WhatsApp
          </label>
          <p className="sm:col-span-2 text-[11px] text-gray-400 -mt-2">
            Buyers will only ever see click-to-contact WhatsApp/Call buttons — your number is never shown or made copyable to regular users.
          </p>

          <div className="relative">
            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm" aria-hidden="true">{FIELD_ICON.commodity}</span>
            <input required placeholder="Commodity (e.g. Maize)" value={postForm.commodity} onChange={(e) => setPostForm({ ...postForm, commodity: e.target.value })} className="w-full border border-gray-200 rounded-lg pl-9 pr-3 py-2 text-sm" />
          </div>
          <div className="relative">
            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm" aria-hidden="true">{FIELD_ICON.location}</span>
            <input required placeholder="Location in Uganda (e.g. Iganga)" value={postForm.location} onChange={(e) => setPostForm({ ...postForm, location: e.target.value })} className="w-full border border-gray-200 rounded-lg pl-9 pr-3 py-2 text-sm" />
          </div>
          <div className="relative">
            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm" aria-hidden="true">{FIELD_ICON.quantity}</span>
            <input required type="number" min="0" placeholder="Bulk quantity" value={postForm.quantity} onChange={(e) => setPostForm({ ...postForm, quantity: e.target.value })} className="w-full border border-gray-200 rounded-lg pl-9 pr-3 py-2 text-sm" />
          </div>
          <input placeholder="Unit (default kg)" value={postForm.unit} onChange={(e) => setPostForm({ ...postForm, unit: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          <div className="relative sm:col-span-2">
            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm" aria-hidden="true">{FIELD_ICON.price}</span>
            <input required type="number" min="0" placeholder="Minimum price per unit (UGX)" value={postForm.minPricePerUnit} onChange={(e) => setPostForm({ ...postForm, minPricePerUnit: e.target.value })} className="w-full border border-gray-200 rounded-lg pl-9 pr-3 py-2 text-sm" />
          </div>
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
            {FIELD_ICON.warehouse} Warehouse storage available for this lot
          </label>
          {postForm.warehouseAvailable && (
            <input placeholder="Storage location" value={postForm.storageLocation} onChange={(e) => setPostForm({ ...postForm, storageLocation: e.target.value })} className="border border-gray-200 rounded-lg px-3 py-2 text-sm sm:col-span-2" />
          )}
          <div className="relative sm:col-span-2">
            <span className="absolute left-3 top-3 text-sm" aria-hidden="true">{FIELD_ICON.notes}</span>
            <textarea placeholder="Notes (drying, sorting, certificates, etc.)" value={postForm.notes} onChange={(e) => setPostForm({ ...postForm, notes: e.target.value })} className="w-full border border-gray-200 rounded-lg pl-9 pr-3 py-2 text-sm" rows={2} />
          </div>

          {/* Images — mandatory */}
          <div className="sm:col-span-2">
            <p className="text-xs font-bold text-gray-600 mb-1.5 flex items-center gap-1.5">{FIELD_ICON.images} Photos <span className="text-red-500">*</span> <span className="text-gray-400 font-normal">(at least 1, up to {MAX_IMAGES}) — subject to admin approval</span></p>
            <div className="flex flex-wrap gap-2">
              {images.map((url) => (
                <div key={url} className="relative w-16 h-16 rounded-lg overflow-hidden border border-gray-200 group">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={url} alt="Listing photo" className="w-full h-full object-cover" />
                  <button type="button" onClick={() => removeImage(url)} className="absolute inset-0 bg-black/50 text-white text-xs font-bold opacity-0 group-hover:opacity-100 transition-opacity">✕</button>
                </div>
              ))}
              {images.length < MAX_IMAGES && (
                <button
                  type="button"
                  onClick={() => imageInputRef.current?.click()}
                  disabled={uploadingImages}
                  className="w-16 h-16 rounded-lg border-2 border-dashed border-gray-200 text-gray-400 hover:border-green-400 hover:text-green-600 flex items-center justify-center text-lg transition-colors disabled:opacity-50"
                >
                  {uploadingImages ? '…' : '+'}
                </button>
              )}
              <input ref={imageInputRef} type="file" accept="image/*" multiple className="hidden" onChange={(e) => handleImageFiles(e.target.files)} />
            </div>
          </div>

          {/* Video — optional, < 60s */}
          <div className="sm:col-span-2">
            <p className="text-xs font-bold text-gray-600 mb-1.5 flex items-center gap-1.5">{FIELD_ICON.video} Short video <span className="text-gray-400 font-normal">(optional, under {MAX_VIDEO_SECONDS} seconds)</span></p>
            {videoUrl ? (
              <div className="flex items-center gap-3">
                <video src={videoUrl} controls className="w-40 rounded-lg border border-gray-200" />
                <button type="button" onClick={() => setVideoUrl(null)} className="text-xs font-semibold text-red-600 hover:underline">Remove video</button>
              </div>
            ) : (
              <button
                type="button"
                onClick={() => videoInputRef.current?.click()}
                disabled={uploadingVideo}
                className="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg border-2 border-dashed border-gray-200 text-gray-400 hover:border-green-400 hover:text-green-600 text-xs font-semibold transition-colors disabled:opacity-50"
              >
                {uploadingVideo ? 'Uploading…' : `${FIELD_ICON.video} Add a showcase clip`}
              </button>
            )}
            <input ref={videoInputRef} type="file" accept="video/mp4,video/webm,video/quicktime" className="hidden" onChange={(e) => handleVideoFile(e.target.files?.[0] || null)} />
          </div>

          <button disabled={postSubmitting || uploadingImages || uploadingVideo} type="submit" className="sm:col-span-2 inline-flex justify-center items-center gap-1.5 px-4 py-2.5 rounded-lg bg-green-700 hover:bg-green-800 disabled:opacity-50 text-white text-sm font-bold transition-colors">
            {postSubmitting ? 'Saving…' : editingPostId ? 'Save changes' : 'Submit for approval'}
          </button>
        </form>
      )}

      {/* Filters */}
      {!viewMine && (
        <div className="flex flex-wrap gap-2 mb-4">
          <input value={commodityFilter} onChange={(e) => setCommodityFilter(e.target.value)} placeholder="Search commodity…" className="border border-gray-200 rounded-lg px-3 py-2 text-sm flex-1 min-w-[160px]" />
          <select value={locationFilter} onChange={(e) => setLocationFilter(e.target.value)} className="border border-gray-200 rounded-lg px-3 py-2 text-sm bg-white">
            <option value="">All locations</option>
            {locations.map((loc) => <option key={loc} value={loc}>{loc}</option>)}
          </select>
        </div>
      )}

      {/* Post grid */}
      {(viewMine ? mineLoading : loading) ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {Array.from({ length: 6 }).map((_, i) => <div key={i} className="h-40 rounded-xl bg-gray-100 animate-pulse" />)}
        </div>
      ) : visiblePosts.length === 0 ? (
        <div className="text-center py-14 text-gray-400">
          <p className="text-4xl mb-2">🌾</p>
          <p className="text-sm">{viewMine ? "You haven't posted any listings yet." : 'No bulk listings match your search yet.'}</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 mb-8">
          {visiblePosts.map((post) => (
            <div key={post.id} className="relative group flex flex-col overflow-hidden rounded-xl bg-white border border-gray-100 shadow-sm transition-all duration-300 hover:shadow-xl hover:-translate-y-1 hover:border-green-100">
              <button onClick={() => openDetail(post.id)} className="text-left flex flex-col flex-1">
                {post.images?.[0] && (
                  <div className="relative w-full aspect-[4/3] bg-gray-50">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={post.images[0]} alt={post.commodity} className="w-full h-full object-cover" />
                    {post.videoUrl && (
                      <span className="absolute top-1.5 right-1.5 bg-black/60 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full flex items-center gap-1">🎥 Video</span>
                    )}
                    {post.images.length > 1 && (
                      <span className="absolute bottom-1.5 right-1.5 bg-black/60 text-white text-[9px] font-bold px-1.5 py-0.5 rounded-full">+{post.images.length - 1}</span>
                    )}
                  </div>
                )}
                <div className="p-4">
                  <div className="flex items-start justify-between gap-2 mb-1.5">
                    <h3 className="font-bold text-gray-900 text-sm">{post.commodity}</h3>
                    <div className="flex flex-col items-end gap-1 shrink-0">
                      {viewMine && (
                        <span className={`text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full ${MODERATION_STYLE[post.moderationStatus]}`}>{MODERATION_LABEL[post.moderationStatus]}</span>
                      )}
                      {post.verifiedSeller && (
                        <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-emerald-100 text-emerald-700">Verified</span>
                      )}
                    </div>
                  </div>
                  <p className="text-xs text-gray-500">{post.quantity.toLocaleString()} {post.unit} · {post.location}</p>
                  {viewMine && post.moderationStatus === 'REJECTED' && post.rejectionReason && (
                    <p className="text-[11px] text-red-600 mt-1">Reason: {post.rejectionReason}</p>
                  )}
                  <div className="flex items-center gap-1.5 mt-1.5 flex-wrap">
                    <span className={`text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full ${post.availability === 'IMMEDIATE' ? 'bg-orange-100 text-orange-700' : 'bg-slate-100 text-slate-600'}`}>
                      {post.availability === 'IMMEDIATE' ? 'Available now' : 'Available soon'}
                    </span>
                    <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-premium-navy/10 text-premium-navy">{GRADE_LABEL[post.qualityGrade]}</span>
                    {post.warehouseAvailable && <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-blue-50 text-blue-700">Warehouse</span>}
                  </div>
                  <div className="mt-3 pt-2 border-t border-gray-50">
                    <p className="text-[10px] text-gray-400">Seller&apos;s minimum</p>
                    <p className="text-lg font-black text-green-700 tabular-nums leading-none">{money(post.minPricePerUnit, post.currency)}<span className="text-xs font-semibold text-gray-400">/{post.unit}</span></p>
                    {(post.offerCount ?? 0) > 0 ? (
                      <p className="text-[11px] text-gray-500 mt-1">{post.offerCount} offer{post.offerCount === 1 ? '' : 's'} · best delivered <span className="font-bold text-gray-700">{money(post.bestDeliveredPricePerUnit || 0, post.currency)}</span></p>
                    ) : (
                      <p className="text-[11px] text-gray-400 mt-1">No buyer offers yet</p>
                    )}
                  </div>
                </div>
              </button>
              {viewMine && (
                <button onClick={() => startEdit(post)} className="absolute top-2 left-2 bg-white/90 hover:bg-white text-gray-700 text-[10px] font-bold px-2 py-1 rounded-full shadow-sm border border-gray-200">
                  ✏️ Edit
                </button>
              )}
            </div>
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
                {selectedPost.images?.length > 0 && (
                  <div className="flex gap-2 overflow-x-auto mb-3 -mx-5 px-5">
                    {selectedPost.images.map((url) => (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img key={url} src={url} alt={selectedPost.commodity} className="w-28 h-28 object-cover rounded-lg border border-gray-100 shrink-0" />
                    ))}
                  </div>
                )}
                {selectedPost.videoUrl && (
                  <video src={selectedPost.videoUrl} controls className="w-full max-w-xs rounded-lg border border-gray-100 mb-3" />
                )}

                <div className="flex items-start justify-between gap-3 mb-1">
                  <div>
                    <h3 className="text-lg font-black text-gray-900 flex items-center gap-2">
                      {selectedPost.commodity}
                      {selectedPost.verifiedSeller && <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-emerald-100 text-emerald-700">Verified seller</span>}
                    </h3>
                    <p className="text-xs text-gray-500">{selectedPost.farmerName} · {selectedPost.quantity.toLocaleString()} {selectedPost.unit} · {selectedPost.location}</p>
                  </div>
                  <button onClick={closeDetail} className="text-gray-400 hover:text-gray-600 text-xl leading-none">×</button>
                </div>

                {selectedPost.notes && <p className="text-xs text-gray-500 mt-2 bg-gray-50 rounded-lg p-2.5">{selectedPost.notes}</p>}

                <div className="flex flex-wrap gap-1.5 mt-2.5">
                  <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-premium-navy/10 text-premium-navy">{GRADE_LABEL[selectedPost.qualityGrade]}</span>
                  {selectedPost.warehouseAvailable && <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-blue-50 text-blue-700">Warehouse: {selectedPost.storageLocation || 'available'}</span>}
                  {selectedPost.verifiedWeightKg != null && <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-gray-100 text-gray-600">Verified weight: {selectedPost.verifiedWeightKg.toLocaleString()} kg</span>}
                </div>

                {/* Contact — click-to-contact only, never a visible/copyable number */}
                {(selectedPost.contact?.whatsappUrl || selectedPost.contact?.callUrl) && (
                  <div className="flex flex-wrap gap-2 mt-3">
                    {selectedPost.contact.whatsappUrl && (
                      <a href={selectedPost.contact.whatsappUrl} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-lg bg-[#25D366] hover:brightness-95 text-white text-xs font-bold transition-all">
                        💬 WhatsApp seller
                      </a>
                    )}
                    {selectedPost.contact.callUrl && (
                      <a href={selectedPost.contact.callUrl} className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-lg bg-gray-800 hover:bg-gray-900 text-white text-xs font-bold transition-colors">
                        📞 Call seller
                      </a>
                    )}
                  </div>
                )}

                {isAdmin && (
                  <button onClick={() => verifyPost(selectedPost.id, !selectedPost.verifiedSeller)} className="mt-2 text-[11px] font-semibold text-premium-navy hover:underline block">
                    {selectedPost.verifiedSeller ? 'Remove seller verification' : 'Mark seller as verified'}
                  </button>
                )}

                <p className="text-[11px] font-black uppercase tracking-wider text-gray-400 mt-4 mb-2">Buyer offers · delivered price</p>
                {offers.length === 0 ? (
                  <p className="text-xs text-gray-400">No offers yet — be the first buyer to quote.</p>
                ) : (
                  <div className="space-y-2">
                    {offers.map((offer) => (
                      <div key={offer.id} className="rounded-lg border border-gray-100 p-3">
                        <div className="flex items-center justify-between gap-2">
                          <p className="text-sm font-bold text-gray-800 flex items-center gap-1.5">
                            {offer.buyerName}
                            <span className="text-xs font-normal text-gray-400">· {offer.buyerLocation}</span>
                            {offer.verifiedBuyer && <span className="text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-emerald-100 text-emerald-700">Verified</span>}
                          </p>
                          <p className="text-base font-black text-green-700 tabular-nums">{money(offer.deliveredPricePerUnit, selectedPost.currency)}</p>
                        </div>
                        <p className="text-[11px] text-gray-400 mt-1">
                          {money(offer.commodityPricePerUnit, selectedPost.currency)} commodity + {money(offer.transportPerUnit, selectedPost.currency)} transport + {money(offer.storagePerUnit, selectedPost.currency)} storage + {offer.platformFeePercent}% platform fee = delivered price
                        </p>
                        {offer.notes && <p className="text-[11px] text-gray-500 mt-1">{offer.notes}</p>}
                        {isAdmin && (
                          <button onClick={() => verifyOffer(offer.id, !offer.verifiedBuyer)} className="mt-1.5 text-[11px] font-semibold text-premium-navy hover:underline">
                            {offer.verifiedBuyer ? 'Remove buyer verification' : 'Mark buyer as verified'}
                          </button>
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
              <p className="text-[11px] font-black uppercase tracking-wider text-gray-400 mb-2">Seller minimum-price history</p>
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
        Payments and delivery are still arranged directly between seller and buyer — the platform calculates and
        displays the delivered price and offer history, but does not yet hold funds in escrow or dispatch logistics.
        Those need dedicated payment-gateway and logistics-partner integrations and are on the roadmap.
      </p>
    </div>
  );
}
