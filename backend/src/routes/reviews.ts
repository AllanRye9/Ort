import { Router, Response, NextFunction } from 'express';
import { prisma } from '../utils/prisma';
import { authenticate, AuthRequest } from '../middleware/auth';
import { createError } from '../middleware/errorHandler';

const router = Router();

// ─── Legacy: User-to-user review (reviewer rates a seller/buyer on a listing) ──

router.post('/', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { revieweeId, listingId, rating, comment } = req.body;
    if (!revieweeId || !listingId || !rating) return next(createError('Missing required fields', 400));
    const ratingNum = Number(rating);
    if (!Number.isInteger(ratingNum) || ratingNum < 1 || ratingNum > 5) {
      return next(createError('Rating must be an integer between 1 and 5', 400));
    }

    const reviewerId = req.user!.userId;
    if (reviewerId === revieweeId) return next(createError('You cannot review yourself', 400));

    // Only allow a review if the reviewer and reviewee were counterparties
    // (buyer/seller) on a completed (DELIVERED) order for this listing.
    const completedOrder = await prisma.order.findFirst({
      where: {
        status: 'DELIVERED',
        items: { some: { listingId } },
        OR: [
          { buyerId: reviewerId, sellerId: revieweeId },
          { sellerId: reviewerId, buyerId: revieweeId },
        ],
      },
    });
    if (!completedOrder) {
      return next(createError('You can only review users you have completed a transaction with', 403));
    }

    const review = await prisma.review.create({
      data: { reviewerId, revieweeId, listingId, rating: ratingNum, comment },
      include: { reviewer: { select: { id: true, name: true, avatar: true } } },
    });
    res.status(201).json(review);
  } catch (err) {
    next(err);
  }
});

// ─── Product Reviews ──────────────────────────────────────────────────────────

/**
 * GET /api/reviews/recent
 * Public – returns recent approved reviews across all listings.
 */
router.get('/recent', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const page = Math.max(1, parseInt(req.query.page as string || '1'));
    const limit = Math.min(50, parseInt(req.query.limit as string || '10'));
    const rawRating = req.query.rating ? parseInt(req.query.rating as string) : undefined;
    const ratingFilter = rawRating !== undefined && Number.isInteger(rawRating) && rawRating >= 1 && rawRating <= 5 ? rawRating : undefined;
    const sort = (req.query.sort as string) || 'recent';

    const orderBy =
      sort === 'highest' ? { rating: 'desc' as const } :
      sort === 'lowest'  ? { rating: 'asc' as const } :
      sort === 'helpful' ? { helpfulCount: 'desc' as const } :
      { createdAt: 'desc' as const };

    const where = {
      status: 'APPROVED' as const,
      ...(ratingFilter ? { rating: ratingFilter } : {}),
    };

    const [reviews, total] = await Promise.all([
      prisma.productReview.findMany({
        where,
        include: {
          user: { select: { id: true, name: true, avatar: true } },
          listing: { select: { id: true, title: true } },
        },
        orderBy,
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.productReview.count({ where }),
    ]);

    res.json({
      reviews,
      pagination: { total, page, limit, pages: Math.ceil(total / limit) },
    });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/reviews/listing/:listingId
 * Public – returns approved reviews for a listing, with aggregated stats.
 */
router.get('/listing/:listingId', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { listingId } = req.params;
    const sort = (req.query.sort as string) || 'recent';
    const page = Math.max(1, parseInt(req.query.page as string || '1'));
    const limit = Math.min(50, parseInt(req.query.limit as string || '10'));

    const orderBy =
      sort === 'helpful' ? { helpfulCount: 'desc' as const } :
      sort === 'highest' ? { rating: 'desc' as const } :
      sort === 'lowest'  ? { rating: 'asc' as const } :
      { createdAt: 'desc' as const };

    const where = { listingId, status: 'APPROVED' as const };

    const [reviews, total, ratingAgg] = await Promise.all([
      prisma.productReview.findMany({
        where,
        include: {
          user: { select: { id: true, name: true, avatar: true } },
        },
        orderBy,
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.productReview.count({ where }),
      prisma.productReview.groupBy({
        by: ['rating'],
        where,
        _count: { rating: true },
      }),
    ]);

    // Build rating breakdown (1–5 star counts and percentages)
    const breakdown: Record<number, { count: number; pct: number }> = {};
    for (let s = 1; s <= 5; s++) {
      const row = ratingAgg.find((r) => r.rating === s);
      const count = row?._count.rating ?? 0;
      breakdown[s] = { count, pct: total > 0 ? Math.round((count / total) * 100) : 0 };
    }

    const totalRatingSum = ratingAgg.reduce((sum, r) => sum + r.rating * r._count.rating, 0);
    const averageRating = total > 0 ? Math.round((totalRatingSum / total) * 10) / 10 : 0;

    res.json({
      reviews,
      aggregate: { averageRating, total, breakdown },
      pagination: { total, page, limit, pages: Math.ceil(total / limit) },
    });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/reviews/listing/:listingId
 * Authenticated – submit a product review. One review per user per listing.
 */
router.post('/listing/:listingId', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { listingId } = req.params;
    const userId = req.user!.userId;
    const { rating, title, content } = req.body;

    if (!rating || !content) return next(createError('Rating and content are required', 400));
    const ratingNum = Number(rating);
    if (!Number.isInteger(ratingNum) || ratingNum < 1 || ratingNum > 5) {
      return next(createError('Rating must be an integer between 1 and 5', 400));
    }
    if (content.length < 10) return next(createError('Review content must be at least 10 characters', 400));
    if (content.length > 2000) return next(createError('Review content must not exceed 2000 characters', 400));
    if (title && title.length > 150) return next(createError('Review title must not exceed 150 characters', 400));

    // Check listing exists
    const listing = await prisma.listing.findUnique({ where: { id: listingId } });
    if (!listing) return next(createError('Listing not found', 404));

    // Prevent duplicate review
    const existing = await prisma.productReview.findUnique({
      where: { userId_listingId: { userId, listingId } },
    });
    if (existing) return next(createError('You have already reviewed this listing', 409));

    // Only users who have completed a transaction for this listing may review it.
    // "Completed" = the reviewer has a DELIVERED order containing this listing.
    const completedOrderItem = await prisma.orderItem.findFirst({
      where: {
        listingId,
        order: { buyerId: userId, status: 'DELIVERED' },
      },
    });
    if (!completedOrderItem) {
      return next(createError('Only buyers who have completed a purchase of this item can leave a review', 403));
    }

    const review = await prisma.productReview.create({
      data: {
        listingId,
        userId,
        rating: ratingNum,
        title: title || null,
        content,
        status: 'PENDING',
        verifiedPurchase: true,
      },
      include: { user: { select: { id: true, name: true, avatar: true } } },
    });

    res.status(201).json(review);
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/reviews/:id/helpful
 * Authenticated – toggle helpful vote on a product review.
 */
router.post('/:id/helpful', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const reviewId = req.params.id;
    const userId = req.user!.userId;

    const review = await prisma.productReview.findUnique({ where: { id: reviewId } });
    if (!review) return next(createError('Review not found', 404));
    if (review.status !== 'APPROVED') return next(createError('Review is not published', 400));

    const existing = await prisma.helpfulVote.findUnique({
      where: { reviewId_userId: { reviewId, userId } },
    });

    if (existing) {
      // Remove vote
      await prisma.$transaction([
        prisma.helpfulVote.delete({ where: { reviewId_userId: { reviewId, userId } } }),
        prisma.productReview.update({
          where: { id: reviewId },
          data: { helpfulCount: { decrement: 1 } },
        }),
      ]);
      return res.json({ helpful: false });
    } else {
      // Add vote
      await prisma.$transaction([
        prisma.helpfulVote.create({ data: { reviewId, userId } }),
        prisma.productReview.update({
          where: { id: reviewId },
          data: { helpfulCount: { increment: 1 } },
        }),
      ]);
      return res.json({ helpful: true });
    }
  } catch (err) {
    next(err);
  }
});

export default router;
