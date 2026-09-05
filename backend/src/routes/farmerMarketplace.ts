import { Router, Response, NextFunction } from 'express';
import { Request } from 'express';
import { randomUUID } from 'crypto';
import { readJsonFile, writeJsonFile } from '../utils/jsonStore';
import { authenticate, optionalAuthenticate, authorize, AuthRequest } from '../middleware/auth';
import { createError } from '../middleware/errorHandler';

const router = Router();
const FARMER_MARKETPLACE_PATH = 'data/farmer-marketplace.json';

/**
 * "Farmer Marketplace" — a commodity marketplace layer that sits alongside
 * the admin-curated /api/commodity-prices price board. Where commodity-prices
 * is a reference index (what things generally cost), this is transactional:
 * farmers post real produce for sale, buyers in different towns quote a
 * price, and the platform computes an all-in delivered price for each quote
 * (commodity price + transport + storage + platform fee). That's the core
 * mechanic that starts to close the information-asymmetry gap between a
 * farmer in, say, Iganga and buyers spread across Kampala, Jinja, Mbale, and
 * export channels.
 *
 * Storage mirrors commodityPrices.ts's JSON-file-store pattern for the same
 * reason documented there: consistency with the sibling feature, fast to
 * ship. Same ephemeral-filesystem caveat applies — mount a persistent volume
 * at data/ in production, or migrate to Prisma once this needs relational
 * querying (e.g. a farmer's full order history, disputes, payouts).
 *
 * WHOLESALE / BULK COMMODITY MARKETPLACE (merged with the "Uganda Market
 * Prices" reference board on the frontend at /market-prices) — this route
 * now also carries the fields needed for that merged feature:
 *   - `images` (required, at least one CDN URL) and an optional `videoUrl`
 *     (a short clip, enforced client-side to stay under 60 seconds before
 *     upload — see frontend/components/ui/FarmerMarketplaceSection.tsx).
 *   - `moderationStatus` — every post a non-admin creates or edits starts/
 *     returns to PENDING and is invisible on every public read endpoint
 *     until an admin approves it via PATCH /posts/:id/moderate. Admin-
 *     created posts are auto-approved, mirroring the existing
 *     ProductImage/upload.ts admin-bypass pattern.
 *   - `farmerPhone` is never sent back on any public read (list, detail, or
 *     summary) to a caller who is neither the post's owner nor an admin.
 *     Instead, approved+open posts carry a `contact` object with ready-to-
 *     click `whatsappUrl`/`callUrl` links so a buyer can reach the seller
 *     without the raw digits ever being rendered as copyable text. Because
 *     a `tel:`/`wa.me` link has to carry the number to function, a
 *     technically determined visitor could still recover it from page
 *     source or network traffic — real number-masking (a swapped proxy
 *     number, as ride-hailing apps use) needs a telephony provider
 *     integration and is not implemented here.
 *   - Currency is hard-locked to UGX (this section is Uganda-only, matching
 *     the sibling commodity-prices board), regardless of any `currency`
 *     value a caller sends.
 *
 * SCOPE NOTE — what this file deliberately does NOT implement yet:
 *   - Escrow / in-app payment: moving money needs a licensed payment
 *     processor (mobile money aggregator, PCI-compliant card processor) and
 *     legal/regulatory groundwork specific to each country served. This
 *     route only carries an `escrowStatus` placeholder field so the UI has
 *     somewhere to show "payment held" once that integration exists — no
 *     money actually moves here.
 *   - Digital weighing records: real weighbridge/IoT integration is a
 *     hardware project. `verifiedWeightKg` is a plain field an operator can
 *     fill in by hand (e.g. after a warehouse scale reading) until a device
 *     integration writes to it directly.
 *   - Logistics matching: real matching against a transporter network is
 *     its own service. `transportPartner` is a free-text field for now.
 *   - Demand forecasting / AI price predictions: those need a real
 *     historical dataset at volume and a proper modelling pipeline, not a
 *     few dozen posts. `regional-prices` below gives today's honest
 *     average-by-region signal from live data — a solid first step, but it
 *     is not a forecast.
 */

type QualityGrade = 'A' | 'B' | 'C' | 'UNGRADED';
type Availability = 'IMMEDIATE' | 'DATE';
type PostStatus = 'OPEN' | 'MATCHED' | 'CLOSED';
type EscrowStatus = 'NONE' | 'HELD' | 'RELEASED';
type ModerationStatus = 'PENDING' | 'APPROVED' | 'REJECTED';

const WHOLESALE_CURRENCY = 'UGX';

interface PriceHistoryPoint {
  price: number;
  at: string;
}

interface FarmerPost {
  id: string;
  farmerId: string | null;
  farmerName: string;
  farmerPhone: string | null;
  /** Whether farmerPhone is reachable on WhatsApp. When false, only a
   *  call link is offered to buyers — no WhatsApp button is shown at all. */
  isWhatsapp: boolean;
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
  /** Admin-moderation gate. PENDING posts never appear on any public read
   *  endpoint — see the WHOLESALE / BULK COMMODITY MARKETPLACE note above. */
  moderationStatus: ModerationStatus;
  rejectionReason: string | null;
  /** At least one required at creation time — mandatory per product policy
   *  for this bulk/wholesale section. CDN URLs, same shape as ProductImage. */
  images: string[];
  /** Optional short showcase clip (client-enforced < 60s before upload). */
  videoUrl: string | null;
  warehouseAvailable: boolean;
  storageLocation: string | null;
  verifiedWeightKg: number | null;
  notes: string | null;
  priceHistory: PriceHistoryPoint[];
  createdAt: string;
  updatedAt: string;
}

/** Public-safe projection of a post for any caller who is not the owner or
 *  an admin: strips the raw phone number and replaces it with ready-to-use
 *  contact links (see the file-level WHOLESALE note for the masking caveat). */
type PublicFarmerPost = Omit<FarmerPost, 'farmerPhone'> & {
  contact: { whatsappUrl: string | null; callUrl: string | null } | null;
};

function contactLinksFor(post: FarmerPost): { whatsappUrl: string | null; callUrl: string | null } | null {
  if (post.moderationStatus !== 'APPROVED' || post.status === 'CLOSED') return null;
  const digits = (post.farmerPhone || '').replace(/[^0-9]/g, '');
  if (!digits) return null;
  const message = encodeURIComponent(`Hi, I'm interested in your ${post.commodity} listing on the wholesale marketplace.`);
  return {
    whatsappUrl: post.isWhatsapp ? `https://wa.me/${digits}?text=${message}` : null,
    callUrl: `tel:${digits}`,
  };
}

function canSeeRawPhone(post: FarmerPost, viewerId: string | undefined, isAdmin: boolean): boolean {
  return isAdmin || (!!viewerId && !!post.farmerId && viewerId === post.farmerId);
}

/** Redacts farmerPhone → contact for anyone other than the post's owner or
 *  an admin. Always call this before sending a post (or a list of posts)
 *  back on a route that isn't already admin-only. */
function toPublicPost(post: FarmerPost, viewerId: string | undefined, isAdmin: boolean): FarmerPost | PublicFarmerPost {
  if (canSeeRawPhone(post, viewerId, isAdmin)) return post;
  const { farmerPhone: _farmerPhone, ...rest } = post;
  return { ...rest, contact: contactLinksFor(post) };
}

interface BuyerOffer {
  id: string;
  postId: string;
  buyerId: string | null;
  buyerName: string;
  buyerLocation: string;
  verifiedBuyer: boolean;
  commodityPricePerUnit: number;
  transportPerUnit: number;
  storagePerUnit: number;
  platformFeePercent: number;
  transportPartner: string | null;
  escrowStatus: EscrowStatus;
  notes: string | null;
  createdAt: string;
}

interface FarmerMarketplaceStore {
  posts: FarmerPost[];
  offers: BuyerOffer[];
  updatedAt: string;
}

const DEFAULT_PLATFORM_FEE_PERCENT = 2;
const now = () => new Date().toISOString();

function seedStore(): FarmerMarketplaceStore {
  const postId = randomUUID();
  const createdAt = now();
  return {
    posts: [
      {
        id: postId,
        farmerId: null,
        farmerName: 'Nakato Farmers Group',
        farmerPhone: null,
        isWhatsapp: false,
        verifiedSeller: true,
        commodity: 'Maize',
        quantity: 5000,
        unit: 'kg',
        location: 'Iganga',
        qualityGrade: 'A',
        availability: 'IMMEDIATE',
        availableFrom: null,
        minPricePerUnit: 1200,
        currency: 'UGX',
        status: 'OPEN',
        moderationStatus: 'APPROVED',
        rejectionReason: null,
        images: [],
        videoUrl: null,
        warehouseAvailable: true,
        storageLocation: 'Iganga Central Store',
        verifiedWeightKg: 5000,
        notes: 'Dried, sorted, ready for immediate pickup.',
        priceHistory: [{ price: 1200, at: createdAt }],
        createdAt,
        updatedAt: createdAt,
      },
    ],
    offers: [
      { id: randomUUID(), postId, buyerId: null, buyerName: 'Kampala Grain Traders Ltd', buyerLocation: 'Kampala', verifiedBuyer: true, commodityPricePerUnit: 1250, transportPerUnit: 120, storagePerUnit: 30, platformFeePercent: DEFAULT_PLATFORM_FEE_PERCENT, transportPartner: null, escrowStatus: 'NONE', notes: null, createdAt },
      { id: randomUUID(), postId, buyerId: null, buyerName: 'Jinja Millers Co-op', buyerLocation: 'Jinja', verifiedBuyer: true, commodityPricePerUnit: 1230, transportPerUnit: 60, storagePerUnit: 25, platformFeePercent: DEFAULT_PLATFORM_FEE_PERCENT, transportPartner: null, escrowStatus: 'NONE', notes: null, createdAt },
      { id: randomUUID(), postId, buyerId: null, buyerName: 'Mbale Agro Buyers', buyerLocation: 'Mbale', verifiedBuyer: false, commodityPricePerUnit: 1210, transportPerUnit: 90, storagePerUnit: 25, platformFeePercent: DEFAULT_PLATFORM_FEE_PERCENT, transportPartner: null, escrowStatus: 'NONE', notes: null, createdAt },
      { id: randomUUID(), postId, buyerId: null, buyerName: 'Export Buyer (Kenya)', buyerLocation: 'Export', verifiedBuyer: true, commodityPricePerUnit: 1320, transportPerUnit: 180, storagePerUnit: 40, platformFeePercent: 3, transportPartner: null, escrowStatus: 'NONE', notes: 'Requires phytosanitary certificate.', createdAt },
    ],
    updatedAt: createdAt,
  };
}

function loadStore(): FarmerMarketplaceStore {
  const store = readJsonFile<FarmerMarketplaceStore>(FARMER_MARKETPLACE_PATH, seedStore());
  // Backward-compat backfill: posts written before this feature added
  // images/video/moderation/WhatsApp support won't have those fields on
  // disk. Default them so pre-existing listings stay visible (moderationStatus
  // 'APPROVED', since they were already public before moderation existed)
  // instead of silently disappearing the first time this route runs after
  // deploying the change. New posts always set these fields explicitly.
  for (const post of store.posts) {
    if (post.images === undefined) post.images = [];
    if (post.videoUrl === undefined) post.videoUrl = null;
    if (post.isWhatsapp === undefined) post.isWhatsapp = false;
    if (post.moderationStatus === undefined) post.moderationStatus = 'APPROVED';
    if (post.rejectionReason === undefined) post.rejectionReason = null;
    if (post.currency !== WHOLESALE_CURRENCY) post.currency = WHOLESALE_CURRENCY;
  }
  return store;
}

function saveStore(store: FarmerMarketplaceStore): void {
  writeJsonFile(FARMER_MARKETPLACE_PATH, store);
}

function round2(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

function normalizeGrade(value: unknown): QualityGrade {
  const v = String(value || '').trim().toUpperCase();
  return v === 'A' || v === 'B' || v === 'C' ? v : 'UNGRADED';
}

function normalizeAvailability(value: unknown): Availability {
  return String(value || '').trim().toUpperCase() === 'DATE' ? 'DATE' : 'IMMEDIATE';
}

// Delivered price = (commodity price + transport + storage) marked up by the
// platform fee percentage. This is the single calculation the whole feature
// hinges on — every offer surfaced to a farmer is shown with this breakdown
// rather than a bare number, so the farmer can see exactly what each buyer's
// quote is actually worth once it reaches them.
function deliveredPrice(offer: BuyerOffer): { subtotal: number; feeAmount: number; deliveredPricePerUnit: number } {
  const subtotal = round2(offer.commodityPricePerUnit + offer.transportPerUnit + offer.storagePerUnit);
  const feeAmount = round2(subtotal * (offer.platformFeePercent / 100));
  return { subtotal, feeAmount, deliveredPricePerUnit: round2(subtotal + feeAmount) };
}

function offerWithDelivered(offer: BuyerOffer) {
  return { ...offer, ...deliveredPrice(offer) };
}

function postSummary(post: FarmerPost, offers: BuyerOffer[], viewerId?: string, isAdmin = false) {
  const postOffers = offers.filter((o) => o.postId === post.id).map(offerWithDelivered);
  const bestOffer = postOffers.length
    ? postOffers.reduce((best, o) => (o.deliveredPricePerUnit > best.deliveredPricePerUnit ? o : best))
    : null;
  const publicPost = toPublicPost(post, viewerId, isAdmin);
  return { ...publicPost, offerCount: postOffers.length, bestDeliveredPricePerUnit: bestOffer?.deliveredPricePerUnit ?? null };
}

// ─── Public read: list posts ────────────────────────────────────────────────
// GET /api/farmer-marketplace/posts?commodity=&location=&status=OPEN&moderation=PENDING
// optionalAuthenticate so an admin can pass moderation=ALL/PENDING/REJECTED
// to see everything (their own dashboard), while every other caller is
// force-limited to APPROVED posts regardless of what they pass.
router.get('/posts', optionalAuthenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const store = loadStore();
    const { commodity, location, status, moderation } = req.query as {
      commodity?: string; location?: string; status?: string; moderation?: string;
    };
    const isAdmin = req.user?.role === 'ADMIN';

    let posts = store.posts;
    if (commodity) {
      const c = commodity.toLowerCase();
      posts = posts.filter((p) => p.commodity.toLowerCase().includes(c));
    }
    if (location) {
      const l = location.toLowerCase();
      posts = posts.filter((p) => p.location.toLowerCase() === l);
    }
    if (status && status.toUpperCase() !== 'ALL') {
      posts = posts.filter((p) => p.status === status.toUpperCase());
    } else if (!status) {
      posts = posts.filter((p) => p.status !== 'CLOSED');
    }
    // status=ALL: no status filtering — used by the admin dashboard so
    // closed posts remain visible there even though the public list and
    // homepage hide them.

    if (isAdmin && moderation && moderation.toUpperCase() !== 'ALL') {
      posts = posts.filter((p) => p.moderationStatus === moderation.toUpperCase());
    } else if (!isAdmin) {
      // Never negotiable for non-admins: a pending/rejected post is
      // invisible outside the owner's own "My Listings" view (see the
      // owner-scoped /posts/mine endpoint below) and the admin dashboard.
      posts = posts.filter((p) => p.moderationStatus === 'APPROVED');
    }

    res.set('Cache-Control', 'private, max-age=0');
    res.json({
      posts: posts.map((p) => postSummary(p, store.offers, req.user?.userId, isAdmin)),
      updatedAt: store.updatedAt,
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/farmer-marketplace/posts/mine — the caller's own posts, at every
// moderation status, so a farmer/broker can see "pending review" and
// "rejected" listings that the public list endpoint above hides from them.
router.get('/posts/mine', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const store = loadStore();
    const posts = store.posts.filter((p) => p.farmerId === req.user!.userId);
    res.json({ posts: posts.map((p) => postSummary(p, store.offers, req.user!.userId, false)) });
  } catch (err) {
    next(err);
  }
});

// GET /api/farmer-marketplace/posts/:id — full detail incl. every buyer offer
router.get('/posts/:id', optionalAuthenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const store = loadStore();
    const post = store.posts.find((p) => p.id === req.params.id);
    if (!post) return next(createError('Farmer post not found', 404));

    const isAdmin = req.user?.role === 'ADMIN';
    const isOwner = !!req.user && !!post.farmerId && post.farmerId === req.user.userId;
    if (post.moderationStatus !== 'APPROVED' && !isAdmin && !isOwner) {
      return next(createError('Farmer post not found', 404));
    }

    const offers = store.offers
      .filter((o) => o.postId === post.id)
      .map(offerWithDelivered)
      .sort((a, b) => b.deliveredPricePerUnit - a.deliveredPricePerUnit);

    res.json({ post: toPublicPost(post, req.user?.userId, isAdmin), offers });
  } catch (err) {
    next(err);
  }
});

// GET /api/farmer-marketplace/locations — distinct farmer post locations
router.get('/locations', async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const store = loadStore();
    const locations = [...new Set(store.posts.map((p) => p.location).filter(Boolean))].sort();
    res.json({ locations });
  } catch (err) {
    next(err);
  }
});

// GET /api/farmer-marketplace/regional-prices?commodity=Maize
// Averages delivered price per buyer region across all open posts for a
// commodity — the "regional price comparison" piece: a farmer (or anyone)
// can see at a glance that, say, Export buyers are currently paying more
// than Mbale buyers for maize, before a single offer is placed on their own
// post.
router.get('/regional-prices', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const store = loadStore();
    const { commodity } = req.query as { commodity?: string };
    if (!commodity) return next(createError('Query param "commodity" is required', 400));

    const c = commodity.toLowerCase();
    const relevantPostIds = new Set(store.posts.filter((p) => p.commodity.toLowerCase() === c).map((p) => p.id));
    const relevantOffers = store.offers.filter((o) => relevantPostIds.has(o.postId)).map(offerWithDelivered);

    const byRegion = new Map<string, { total: number; count: number }>();
    for (const o of relevantOffers) {
      const entry = byRegion.get(o.buyerLocation) || { total: 0, count: 0 };
      entry.total += o.deliveredPricePerUnit;
      entry.count += 1;
      byRegion.set(o.buyerLocation, entry);
    }

    const regions = [...byRegion.entries()]
      .map(([region, { total, count }]) => ({ region, averageDeliveredPricePerUnit: round2(total / count), offerCount: count }))
      .sort((a, b) => b.averageDeliveredPricePerUnit - a.averageDeliveredPricePerUnit);

    res.json({ commodity, regions });
  } catch (err) {
    next(err);
  }
});

// GET /api/farmer-marketplace/price-history?commodity=Maize&location=Iganga
// Flattens every post's minPricePerUnit history for a commodity (optionally
// scoped to a location) into one time-ordered series.
router.get('/price-history', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const store = loadStore();
    const { commodity, location } = req.query as { commodity?: string; location?: string };
    if (!commodity) return next(createError('Query param "commodity" is required', 400));

    const c = commodity.toLowerCase();
    const l = location?.toLowerCase();
    const posts = store.posts.filter(
      (p) => p.commodity.toLowerCase() === c && (!l || p.location.toLowerCase() === l),
    );

    const points = posts
      .flatMap((p) => p.priceHistory.map((h) => ({ ...h, location: p.location, postId: p.id })))
      .sort((a, b) => new Date(a.at).getTime() - new Date(b.at).getTime());

    res.json({ commodity, location: location || null, points });
  } catch (err) {
    next(err);
  }
});

// ─── Create a wholesale/bulk commodity post ────────────────────────────────
// POST /api/farmer-marketplace/posts
// authenticate (required): posting media and going through admin moderation
// means every post needs an accountable owner, so this no longer accepts
// anonymous/guest submissions the way the earlier reference-price-only
// version did. verifiedSeller always starts false; moderationStatus starts
// PENDING for everyone except admins, who are auto-approved (same bypass
// pattern as ProductImage uploads in upload.ts).
router.post('/posts', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const body = req.body || {};
    const commodity = String(body.commodity || '').trim();
    const quantity = Number(body.quantity);
    const location = String(body.location || '').trim();
    const minPricePerUnit = Number(body.minPricePerUnit);
    const farmerName = String(body.farmerName || '').trim();
    const farmerPhone = String(body.farmerPhone || '').trim();
    const images = Array.isArray(body.images) ? body.images.map((u: unknown) => String(u).trim()).filter(Boolean) : [];
    const videoUrl = body.videoUrl ? String(body.videoUrl).trim() : null;

    if (!commodity || !location || !farmerName) {
      return next(createError('"commodity", "location", and "farmerName" are required.', 400));
    }
    if (!farmerPhone) {
      return next(createError('"farmerPhone" is required so buyers have a way to contact you.', 400));
    }
    if (images.length === 0) {
      return next(createError('At least one image is required. Upload photos of the produce/commodity before posting.', 400));
    }
    if (!Number.isFinite(quantity) || quantity <= 0) {
      return next(createError('"quantity" must be a positive number.', 400));
    }
    if (!Number.isFinite(minPricePerUnit) || minPricePerUnit < 0) {
      return next(createError('"minPricePerUnit" must be a non-negative number.', 400));
    }

    const isAdmin = req.user!.role === 'ADMIN';
    const store = loadStore();
    const createdAt = now();
    const post: FarmerPost = {
      id: randomUUID(),
      farmerId: req.user!.userId,
      farmerName,
      farmerPhone,
      isWhatsapp: Boolean(body.isWhatsapp),
      verifiedSeller: false,
      commodity,
      quantity,
      unit: String(body.unit || 'kg').trim() || 'kg',
      location,
      qualityGrade: normalizeGrade(body.qualityGrade),
      availability: normalizeAvailability(body.availability),
      availableFrom: body.availability === 'DATE' && body.availableFrom ? String(body.availableFrom) : null,
      minPricePerUnit: round2(minPricePerUnit),
      // Uganda-only section — currency is always UGX, never taken from the
      // request body (see the file-level WHOLESALE note).
      currency: WHOLESALE_CURRENCY,
      status: 'OPEN',
      moderationStatus: isAdmin ? 'APPROVED' : 'PENDING',
      rejectionReason: null,
      images,
      videoUrl,
      warehouseAvailable: Boolean(body.warehouseAvailable),
      storageLocation: body.storageLocation ? String(body.storageLocation).trim() : null,
      verifiedWeightKg: body.verifiedWeightKg != null ? Number(body.verifiedWeightKg) : null,
      notes: body.notes ? String(body.notes).trim() : null,
      priceHistory: [{ price: round2(minPricePerUnit), at: createdAt }],
      createdAt,
      updatedAt: createdAt,
    };

    store.posts.push(post);
    store.updatedAt = createdAt;
    saveStore(store);
    res.status(201).json({ post });
  } catch (err) {
    next(err);
  }
});

// ─── Update a wholesale/bulk commodity post (owner or admin) ───────────────
// PATCH /api/farmer-marketplace/posts/:id
// Supports updating status (OPEN/MATCHED/CLOSED), minPricePerUnit (which
// appends to priceHistory rather than overwriting it, so the price-history
// endpoint above stays meaningful), and now the full listing content
// (images, video, commodity, location, contact number/WhatsApp flag).
// A non-admin owner's edit to any content field sends the post back to
// PENDING for re-review — otherwise moderation could be bypassed entirely
// by approving once and editing freely afterwards. Admin edits never force
// a re-review; use PATCH /posts/:id/moderate to change moderation status.
const CONTENT_FIELDS = [
  'commodity', 'location', 'unit', 'qualityGrade', 'availability', 'availableFrom',
  'images', 'videoUrl', 'farmerPhone', 'isWhatsapp', 'farmerName',
] as const;

router.patch('/posts/:id', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const store = loadStore();
    const post = store.posts.find((p) => p.id === req.params.id);
    if (!post) return next(createError('Farmer post not found', 404));

    const isOwner = post.farmerId && post.farmerId === req.user!.userId;
    const isAdmin = req.user!.role === 'ADMIN';
    if (!isOwner && !isAdmin) return next(createError('You do not have permission to edit this post', 403));

    const body = req.body || {};
    let contentChanged = false;

    if (body.status && ['OPEN', 'MATCHED', 'CLOSED'].includes(String(body.status).toUpperCase())) {
      post.status = String(body.status).toUpperCase() as PostStatus;
    }
    if (body.minPricePerUnit != null) {
      const newPrice = round2(Number(body.minPricePerUnit));
      if (Number.isFinite(newPrice) && newPrice >= 0 && newPrice !== post.minPricePerUnit) {
        post.minPricePerUnit = newPrice;
        post.priceHistory.push({ price: newPrice, at: now() });
        contentChanged = true;
      }
    }
    if (body.quantity != null && Number.isFinite(Number(body.quantity))) post.quantity = Number(body.quantity);
    if (body.warehouseAvailable != null) post.warehouseAvailable = Boolean(body.warehouseAvailable);
    if (body.storageLocation != null) post.storageLocation = String(body.storageLocation).trim() || null;
    if (body.verifiedWeightKg != null) post.verifiedWeightKg = Number(body.verifiedWeightKg);
    if (body.notes != null) post.notes = String(body.notes).trim() || null;

    if (body.images != null) {
      const images = Array.isArray(body.images) ? body.images.map((u: unknown) => String(u).trim()).filter(Boolean) : [];
      if (images.length === 0) return next(createError('At least one image is required.', 400));
      post.images = images;
      contentChanged = true;
    }
    if (body.videoUrl !== undefined) {
      post.videoUrl = body.videoUrl ? String(body.videoUrl).trim() : null;
      contentChanged = true;
    }
    if (body.commodity != null && String(body.commodity).trim()) { post.commodity = String(body.commodity).trim(); contentChanged = true; }
    if (body.location != null && String(body.location).trim()) { post.location = String(body.location).trim(); contentChanged = true; }
    if (body.unit != null && String(body.unit).trim()) { post.unit = String(body.unit).trim(); contentChanged = true; }
    if (body.qualityGrade != null) { post.qualityGrade = normalizeGrade(body.qualityGrade); contentChanged = true; }
    if (body.availability != null) {
      post.availability = normalizeAvailability(body.availability);
      post.availableFrom = post.availability === 'DATE' && body.availableFrom ? String(body.availableFrom) : null;
      contentChanged = true;
    }
    if (body.farmerPhone != null && String(body.farmerPhone).trim()) { post.farmerPhone = String(body.farmerPhone).trim(); contentChanged = true; }
    if (body.isWhatsapp != null) { post.isWhatsapp = Boolean(body.isWhatsapp); contentChanged = true; }
    if (body.farmerName != null && String(body.farmerName).trim()) { post.farmerName = String(body.farmerName).trim(); contentChanged = true; }

    if (contentChanged && !isAdmin) {
      post.moderationStatus = 'PENDING';
      post.rejectionReason = null;
    }

    post.updatedAt = now();
    store.updatedAt = post.updatedAt;
    saveStore(store);
    res.json({ post: toPublicPost(post, req.user!.userId, isAdmin) });
  } catch (err) {
    next(err);
  }
});

// ─── Admin: approve or reject a pending/rejected post ──────────────────────
// PATCH /api/farmer-marketplace/posts/:id/moderate  { approved: boolean, reason?: string }
router.patch('/posts/:id/moderate', authenticate, authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const store = loadStore();
    const post = store.posts.find((p) => p.id === req.params.id);
    if (!post) return next(createError('Farmer post not found', 404));

    const approved = Boolean(req.body?.approved);
    post.moderationStatus = approved ? 'APPROVED' : 'REJECTED';
    post.rejectionReason = approved ? null : (req.body?.reason ? String(req.body.reason).trim() : null);
    post.updatedAt = now();
    store.updatedAt = post.updatedAt;
    saveStore(store);
    res.json({ post });
  } catch (err) {
    next(err);
  }
});

// ─── Admin: verify/unverify a farmer (seller) ──────────────────────────────
// PATCH /api/farmer-marketplace/posts/:id/verify  { verified: boolean }
router.patch('/posts/:id/verify', authenticate, authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const store = loadStore();
    const post = store.posts.find((p) => p.id === req.params.id);
    if (!post) return next(createError('Farmer post not found', 404));

    post.verifiedSeller = Boolean(req.body?.verified);
    post.updatedAt = now();
    store.updatedAt = post.updatedAt;
    saveStore(store);
    res.json({ post });
  } catch (err) {
    next(err);
  }
});

// ─── Submit a buyer offer on a post ─────────────────────────────────────────
// POST /api/farmer-marketplace/posts/:id/offers
router.post('/posts/:id/offers', optionalAuthenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const store = loadStore();
    const post = store.posts.find((p) => p.id === req.params.id);
    if (!post) return next(createError('Farmer post not found', 404));
    if (post.status === 'CLOSED') return next(createError('This post is closed and no longer accepting offers.', 400));

    const body = req.body || {};
    const buyerName = String(body.buyerName || '').trim();
    const buyerLocation = String(body.buyerLocation || '').trim();
    const commodityPricePerUnit = Number(body.commodityPricePerUnit);
    const transportPerUnit = Number(body.transportPerUnit ?? 0);
    const storagePerUnit = Number(body.storagePerUnit ?? 0);

    if (!buyerName || !buyerLocation) {
      return next(createError('"buyerName" and "buyerLocation" are required.', 400));
    }
    if (!Number.isFinite(commodityPricePerUnit) || commodityPricePerUnit < 0) {
      return next(createError('"commodityPricePerUnit" must be a non-negative number.', 400));
    }
    if (!Number.isFinite(transportPerUnit) || transportPerUnit < 0 || !Number.isFinite(storagePerUnit) || storagePerUnit < 0) {
      return next(createError('"transportPerUnit" and "storagePerUnit" must be non-negative numbers.', 400));
    }

    const offer: BuyerOffer = {
      id: randomUUID(),
      postId: post.id,
      buyerId: req.user?.userId || null,
      buyerName,
      buyerLocation,
      verifiedBuyer: false,
      commodityPricePerUnit: round2(commodityPricePerUnit),
      transportPerUnit: round2(transportPerUnit),
      storagePerUnit: round2(storagePerUnit),
      platformFeePercent: Number.isFinite(Number(body.platformFeePercent)) ? Number(body.platformFeePercent) : DEFAULT_PLATFORM_FEE_PERCENT,
      transportPartner: body.transportPartner ? String(body.transportPartner).trim() : null,
      escrowStatus: 'NONE',
      notes: body.notes ? String(body.notes).trim() : null,
      createdAt: now(),
    };

    store.offers.push(offer);
    store.updatedAt = offer.createdAt;
    saveStore(store);
    res.status(201).json({ offer: offerWithDelivered(offer) });
  } catch (err) {
    next(err);
  }
});

// ─── Admin: verify/unverify a buyer ─────────────────────────────────────────
// PATCH /api/farmer-marketplace/offers/:id/verify  { verified: boolean }
router.patch('/offers/:id/verify', authenticate, authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const store = loadStore();
    const offer = store.offers.find((o) => o.id === req.params.id);
    if (!offer) return next(createError('Buyer offer not found', 404));

    offer.verifiedBuyer = Boolean(req.body?.verified);
    store.updatedAt = now();
    saveStore(store);
    res.json({ offer: offerWithDelivered(offer) });
  } catch (err) {
    next(err);
  }
});

// ─── Admin: remove a post (and its offers) ─────────────────────────────────
router.delete('/posts/:id', authenticate, authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const store = loadStore();
    const posts = store.posts.filter((p) => p.id !== req.params.id);
    if (posts.length === store.posts.length) return next(createError('Farmer post not found', 404));

    const offers = store.offers.filter((o) => o.postId !== req.params.id);
    const payload: FarmerMarketplaceStore = { posts, offers, updatedAt: now() };
    saveStore(payload);
    res.json(payload);
  } catch (err) {
    next(err);
  }
});

export default router;
