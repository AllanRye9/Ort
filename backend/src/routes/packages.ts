import { Router, Request, Response, NextFunction } from 'express';
import { prisma } from '../utils/prisma';
import { authenticate } from '../middleware/auth';
import { AuthRequest } from '../middleware/auth';
import { createError } from '../middleware/errorHandler';
import { sendSubscriptionActivatedEmail } from '../utils/email';

const router = Router();

const PACKAGE_SCOPES = ['LISTING', 'CV'] as const;
type PackageScope = (typeof PACKAGE_SCOPES)[number];

function parseScope(scope?: string): PackageScope {
  if (!scope) return 'LISTING';
  if (PACKAGE_SCOPES.includes(scope as PackageScope)) return scope as PackageScope;
  throw createError('scope must be LISTING or CV', 400);
}

// ─── Public: list active packages ─────────────────────────────────────────────

router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const scope = parseScope(req.query.scope as string | undefined);

    const packages = await prisma.sellerPackage.findMany({
      where: { isActive: true, scope },
      orderBy: [{ isFree: 'desc' }, { price: 'asc' }],
    });
    res.json({ packages });
  } catch (err) {
    next(err);
  }
});

// ─── Authenticated: get caller's current active subscription ──────────────────

router.get('/my-subscription', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = (req as AuthRequest).user!.userId;
    const scope = parseScope(req.query.scope as string | undefined);

    // Mark any expired subscriptions first
    await prisma.sellerSubscription.updateMany({
      where: { userId, status: 'ACTIVE', endDate: { lt: new Date() } },
      data: { status: 'EXPIRED' },
    });

    const subscription = await prisma.sellerSubscription.findFirst({
      where: { userId, status: 'ACTIVE', package: { scope } },
      include: { package: true },
      orderBy: { endDate: 'desc' },
    });

    res.json({ subscription: subscription ?? null });
  } catch (err) {
    next(err);
  }
});

// ─── Authenticated: subscribe to a package ────────────────────────────────────

router.post('/:id/subscribe', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = (req as AuthRequest).user!.userId;
    const { id: packageId } = req.params;
    const { paymentRef } = req.body;

    const pkg = await prisma.sellerPackage.findUnique({ where: { id: packageId } });
    if (!pkg || !pkg.isActive) throw createError('Package not found or inactive', 404);

    // Paid packages require a payment reference
    if (!pkg.isFree && !paymentRef) {
      throw createError('paymentRef is required for paid packages', 400);
    }

    // Check if seller already has an active subscription
    await prisma.sellerSubscription.updateMany({
      where: { userId, status: 'ACTIVE', endDate: { lt: new Date() } },
      data: { status: 'EXPIRED' },
    });

    const existing = await prisma.sellerSubscription.findFirst({
      where: { userId, status: 'ACTIVE', package: { scope: pkg.scope } },
    });
    if (existing) throw createError(`You already have an active ${pkg.scope.toLowerCase()} subscription`, 409);

    const startDate = new Date();
    const endDate = new Date(startDate);
    endDate.setDate(endDate.getDate() + pkg.durationDays);

    // Free packages activate immediately; paid CV packages also activate immediately.
    const subscriptionStatus = pkg.isFree ? 'ACTIVE' : pkg.scope === 'CV' ? 'ACTIVE' : 'PENDING_PAYMENT';

    const subscription = await prisma.sellerSubscription.create({
      data: {
        userId,
        packageId,
        status: subscriptionStatus,
        startDate,
        endDate,
        paymentRef: paymentRef ?? null,
      },
      include: { package: true },
    });

    // Notify the seller and activate their account if needed.
    if (subscriptionStatus === 'ACTIVE') {
      await prisma.notification.create({
        data: {
          userId,
          type: 'SUBSCRIPTION_ACTIVATED',
          title: 'Subscription Activated',
          message: `Your "${pkg.name}" package is now active until ${endDate.toLocaleDateString()}.`,
          data: { subscriptionId: subscription.id, packageName: pkg.name },
        },
      });

      if (!pkg.isFree) {
        const user = await prisma.user.findUnique({ where: { id: userId } });
        if (user?.email) {
          await sendSubscriptionActivatedEmail(user.email, user.name ?? 'Member', pkg.name, endDate);
        }
      }
    } else {
      await prisma.notification.create({
        data: {
          userId,
          type: 'SUBSCRIPTION_PENDING',
          title: 'Subscription Pending Approval',
          message: `Your "${pkg.name}" subscription request has been received and is awaiting admin approval.`,
          data: { subscriptionId: subscription.id, packageName: pkg.name },
        },
      });
    }

    res.status(201).json({ subscription });
  } catch (err) {
    next(err);
  }
});

export default router;
