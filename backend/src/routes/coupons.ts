import { Router, Request, Response, NextFunction } from 'express';
import { prisma } from '../utils/prisma';
import { createError } from '../middleware/errorHandler';

const router = Router();

// GET /api/coupons/validate?code=... — validate a coupon code (public)
router.get('/validate', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const code = (req.query.code as string)?.trim().toUpperCase();
    if (!code) return next(createError('code is required', 400));

    const coupon = await prisma.coupon.findUnique({ where: { code } });
    if (!coupon || !coupon.isActive) return next(createError('Invalid coupon code', 404));
    if (coupon.expiresAt && coupon.expiresAt < new Date()) return next(createError('Coupon has expired', 400));
    if (coupon.maxUses != null && coupon.usedCount >= coupon.maxUses) {
      return next(createError('Coupon usage limit reached', 400));
    }

    res.json({
      valid: true,
      code: coupon.code,
      type: coupon.type,
      value: coupon.value,
      minOrderAmount: coupon.minOrderAmount,
      expiresAt: coupon.expiresAt,
    });
  } catch (err) {
    next(err);
  }
});

export default router;
