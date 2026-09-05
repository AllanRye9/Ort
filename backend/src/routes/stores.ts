import { Router, Response, NextFunction, Request } from 'express';
import { prisma } from '../utils/prisma';
import { authenticate, AuthRequest } from '../middleware/auth';
import { createError } from '../middleware/errorHandler';
import { logger } from '../utils/logger';

const router = Router();

// ─────────────────────────────────────────────────────────────────────────────
// ROUTE ORDER IS CRITICAL.
// All static paths (/partners, /me, etc.) MUST be registered before the
// wildcard /:slug route, otherwise Express matches them as slugs and
// the real handlers are never reached.
// ─────────────────────────────────────────────────────────────────────────────

// ── 1. Public: list all active stores ────────────────────────────────────────
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const page    = Math.max(1, parseInt(req.query.page  as string || '1'));
    const limit   = Math.min(500, Math.max(1, parseInt(req.query.limit as string || '500')));
    const skip    = (page - 1) * limit;
    const country = req.query.country as string | undefined;

    const countryFilter = country && ['UAE', 'UGANDA', 'KENYA', 'CHINA'].includes(country.toUpperCase())
      ? country.toUpperCase()
      : undefined;

    const whereClause = {
      isActive: true,
      ...(countryFilter ? {
        user: { country: countryFilter as 'UAE' | 'UGANDA' | 'KENYA' | 'CHINA' },
      } : {}),
    };

    const [stores, total] = await Promise.all([
      prisma.store.findMany({
        where: whereClause,
        select: {
          id:               true,
          name:             true,
          slug:             true,
          logo:             true,
          banner:           true,
          description:      true,
          rating:           true,
          ratingCount:      true,
          isActive:         true,
          createdAt:        true,
          // Partner fields — added in migration 20260720000001
          partnerApproved:   true,
          partnerLogoUrl:    true,
          partnerName:       true,
          partnerWebsite:    true,
          partnerApprovedAt: true,
          user: {
            select: {
              id:                  true,
              name:                true,
              avatar:              true,
              country:             true,
              role:                true,
              companyName:         true,
              businessDescription: true,
              website:             true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      prisma.store.count({ where: whereClause }),
    ]);

    res.json({ stores, total, page, limit, pages: Math.ceil(total / limit) });
  } catch (err) {
    logger.error(`GET /api/stores failed: ${String(err)}`);
    next(err);
  }
});

// ── 2. Public: approved partners wall ────────────────────────────────────────
// MUST be before /:slug so GET /partners is not matched as a store slug.
router.get('/partners', async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const partners = await prisma.store.findMany({
      where: { partnerApproved: true, isActive: true },
      select: {
        id:                true,
        slug:              true,
        name:              true,
        partnerLogoUrl:    true,
        partnerName:       true,
        partnerWebsite:    true,
        partnerApprovedAt: true,
        logo:              true,
        user: {
          select: {
            id:          true,
            name:        true,
            companyName: true,
            country:     true,
            website:     true,
            socialLinks: true,
          },
        },
      },
      orderBy: { partnerApprovedAt: 'asc' },
    });
    res.json({ partners });
  } catch (err) {
    next(err);
  }
});

// ── 3. Authenticated routes (all /me/* paths) ─────────────────────────────────
// Apply auth middleware only to routes below this point.
// These must also come BEFORE /:slug.
router.use('/me', authenticate);

// GET /api/stores/me
router.get('/me', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const store = await prisma.store.findUnique({ where: { userId: req.user!.userId } });
    res.json({ store });
  } catch (err) {
    next(err);
  }
});

// PUT /api/stores/me
router.put('/me', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const existing = await prisma.store.findUnique({ where: { userId: req.user!.userId } });
    if (!existing) return next(createError('Store not found — your store has not been provisioned yet', 404));

    const { name, description, logo, banner, isActive } = req.body;
    if (name !== undefined && !String(name).trim()) {
      return next(createError('Store name cannot be empty', 400));
    }

    const store = await prisma.store.update({
      where: { id: existing.id },
      data: {
        ...(name        !== undefined && { name:        String(name).trim() }),
        ...(description !== undefined && { description: description || null }),
        ...(logo        !== undefined && { logo:        logo || null }),
        ...(banner      !== undefined && { banner:      banner || null }),
        ...(isActive    !== undefined && { isActive:    Boolean(isActive) }),
      },
    });

    res.json({ store });
  } catch (err) {
    next(err);
  }
});

// PUT /api/stores/me/partner-logo
// Only stores with partnerApproved=true may call this.
router.put('/me/partner-logo', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const store = await prisma.store.findUnique({ where: { userId: req.user!.userId } });
    if (!store) return next(createError('Store not found', 404));
    if (!store.partnerApproved) {
      return next(createError('Your store has not been approved as a partner. Contact admin.', 403));
    }

    const { partnerLogoUrl, partnerName, partnerWebsite } = req.body as {
      partnerLogoUrl?: string;
      partnerName?:    string;
      partnerWebsite?: string;
    };

    if (!partnerLogoUrl) return next(createError('partnerLogoUrl is required', 400));

    const updated = await prisma.store.update({
      where: { id: store.id },
      data: {
        partnerLogoUrl: partnerLogoUrl.trim(),
        ...(partnerName    !== undefined && { partnerName:    partnerName?.trim()    || null }),
        ...(partnerWebsite !== undefined && { partnerWebsite: partnerWebsite?.trim() || null }),
      },
    });

    res.json({ store: updated });
  } catch (err) {
    next(err);
  }
});

// GET /api/stores/me/analytics — aggregate dashboard numbers for the Web
// Store "Analytics dashboard" advanced tool: listing views, active listing
// count, order/revenue totals, and a top-listings-by-views leaderboard.
router.get('/me/analytics', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const userId = req.user!.userId;

    const [listingAgg, listingCount, topListings, orders, deliveredOrders] = await Promise.all([
      prisma.listing.aggregate({ where: { userId }, _sum: { views: true } }),
      prisma.listing.count({ where: { userId, status: 'ACTIVE' } }),
      prisma.listing.findMany({
        where: { userId },
        select: { id: true, title: true, views: true, price: true, currency: true, stock: true, images: true },
        orderBy: { views: 'desc' },
        take: 5,
      }),
      prisma.order.findMany({
        where: { sellerId: userId },
        select: { id: true, status: true, total: true, currency: true, createdAt: true },
      }),
      prisma.order.aggregate({
        where: { sellerId: userId, status: 'DELIVERED' },
        _sum: { total: true },
      }),
    ]);

    const ordersByStatus: Record<string, number> = {};
    for (const o of orders) ordersByStatus[o.status] = (ordersByStatus[o.status] ?? 0) + 1;

    // Last-30-day daily order counts for a lightweight sparkline
    const since = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const recentOrders = orders.filter((o) => o.createdAt >= since);
    const dailyOrders: Record<string, number> = {};
    for (const o of recentOrders) {
      const key = o.createdAt.toISOString().slice(0, 10);
      dailyOrders[key] = (dailyOrders[key] ?? 0) + 1;
    }

    res.json({
      totalViews:       listingAgg._sum.views ?? 0,
      activeListings:   listingCount,
      totalOrders:      orders.length,
      ordersByStatus,
      revenue:          deliveredOrders._sum.total ?? 0,
      currency:         orders[0]?.currency ?? 'UGX',
      topListings,
      dailyOrders,
    });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/stores/me/partner-logo
router.delete('/me/partner-logo', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const store = await prisma.store.findUnique({ where: { userId: req.user!.userId } });
    if (!store) return next(createError('Store not found', 404));
    if (!store.partnerApproved) return next(createError('Not an approved partner', 403));

    const updated = await prisma.store.update({
      where: { id: store.id },
      data: { partnerLogoUrl: null },
    });
    res.json({ store: updated });
  } catch (err) {
    next(err);
  }
});

// ── 4. Public: view a store by slug ──────────────────────────────────────────
// MUST be last — wildcard /:slug catches anything not matched above.
router.get('/:slug', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const store = await prisma.store.findUnique({
      where: { slug: req.params.slug },
      include: {
        user: {
          select: {
            id: true, name: true, avatar: true, country: true,
            createdAt: true, companyName: true, businessDescription: true, website: true,
            socialLinks: true,
            listings: {
              where: { status: 'ACTIVE' },
              select: {
                id: true, title: true, price: true, currency: true,
                images: true, country: true, location: true, createdAt: true, status: true,
                category:      { select: { id: true, name: true, slug: true } },
                productImages: { select: { cdnUrl: true }, take: 1 },
              },
              orderBy: { createdAt: 'desc' },
              take: 100,
            },
          },
        },
      },
    });

    if (!store || !store.isActive) return next(createError('Store not found', 404));
    res.json({ store });
  } catch (err) {
    next(err);
  }
});

// ── 5. POST /api/stores — create a store (authenticated) ─────────────────────
router.use(authenticate);

router.post('/', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { name, description, slug } = req.body;
    if (!name || !slug) return next(createError('name and slug are required', 400));

    const existing = await prisma.store.findUnique({ where: { userId: req.user!.userId } });
    if (existing) return next(createError('You already have a store', 400));

    const slugExists = await prisma.store.findUnique({ where: { slug: slug.toLowerCase() } });
    if (slugExists) return next(createError('Slug is already taken', 400));

    const store = await prisma.store.create({
      data: {
        userId:      req.user!.userId,
        name,
        description,
        slug:        slug.toLowerCase(),
      },
    });

    if (req.user!.role === 'BUYER') {
      await prisma.user.update({ where: { id: req.user!.userId }, data: { role: 'SELLER' } });
    }

    res.status(201).json({ store });
  } catch (err) {
    next(err);
  }
});

export default router;
