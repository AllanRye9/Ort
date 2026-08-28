import { Router, Response, NextFunction } from 'express';
import { Prisma } from '@prisma/client';
import { prisma } from '../utils/prisma';
import { authenticate, AuthRequest } from '../middleware/auth';
import { createError } from '../middleware/errorHandler';
import { v4 as uuidv4 } from 'uuid';

const router = Router();

/** Generates a human-readable order number like ORD-2026-XXXXXX */
function generateOrderNumber(): string {
  const year = new Date().getFullYear();
  const rand = uuidv4().replace(/-/g, '').substring(0, 6).toUpperCase();
  return `ORD-${year}-${rand}`;
}

// ─── Buyer routes ─────────────────────────────────────────────────────────────

// POST /api/orders — place a new order
router.post('/', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const {
      items,           // [{ listingId, quantity, selectedColor?, selectedSize?, selectedAttributes? }]
      shippingAddressId,
      billingAddressId,
      couponCode,
      paymentMethod,
      notes,
      currency,
    } = req.body;

    if (!items || !Array.isArray(items) || items.length === 0) {
      return next(createError('Order must contain at least one item', 400));
    }

    // Validate coupon if provided
    let coupon = null;
    if (couponCode) {
      coupon = await prisma.coupon.findUnique({ where: { code: couponCode.trim().toUpperCase() } });
      if (!coupon || !coupon.isActive) return next(createError('Invalid or inactive coupon', 400));
      if (coupon.expiresAt && coupon.expiresAt < new Date()) return next(createError('Coupon has expired', 400));
      if (coupon.maxUses != null && coupon.usedCount >= coupon.maxUses) {
        return next(createError('Coupon usage limit reached', 400));
      }
    }

    // Resolve listings and build order items
    const listingIds = items.map((i: { listingId: string }) => i.listingId);
    const listings = await prisma.listing.findMany({
      where: { id: { in: listingIds }, status: 'ACTIVE' },
      include: {
        productImages: { where: { status: 'APPROVED' }, select: { cdnUrl: true }, take: 1 },
      },
    });

    if (listings.length !== listingIds.length) {
      return next(createError('One or more listings are unavailable', 400));
    }

    // All items must belong to the same seller (for simplicity; multi-seller orders
    // would require splitting into separate orders — handled in a future iteration).
    const sellerIds = [...new Set(listings.map((l) => l.userId))];
    if (sellerIds.length > 1) {
      return next(createError('All items in an order must be from the same seller', 400));
    }
    const sellerId = sellerIds[0];

    if (sellerId === req.user!.userId) {
      return next(createError('You cannot order your own listings', 400));
    }

    let subtotal = 0;
    const orderItemsData = items.map((item: {
      listingId: string;
      quantity: number;
      selectedColor?: string;
      selectedSize?: string;
      selectedAttributes?: Record<string, string>;
    }) => {
      const listing = listings.find((l) => l.id === item.listingId)!;
      const qty = Math.max(1, Number(item.quantity) || 1);
      subtotal += listing.price * qty;
      // Build a human-readable variants summary for logistics / admin fulfilment.
      const variantParts: string[] = [];
      if (item.selectedColor) variantParts.push(`Colour: ${item.selectedColor}`);
      if (item.selectedSize)  variantParts.push(`Size: ${item.selectedSize}`);
      if (item.selectedAttributes) {
        for (const [k, v] of Object.entries(item.selectedAttributes)) {
          if (v) variantParts.push(`${k}: ${v}`);
        }
      }
      return {
        listingId:   listing.id,
        title:       listing.title,
        price:       listing.price,
        quantity:    qty,
        currency:    listing.currency,
        imageUrl:    listing.productImages[0]?.cdnUrl ?? listing.images[0] ?? null,
        // Variant summary stored as a note so it surfaces in admin order views
        // without requiring a DB schema change.
        ...(variantParts.length > 0 ? { variantSummary: variantParts.join(' | ') } : {}),
      };
    });

    // Apply coupon discount
    let discount = 0;
    if (coupon) {
      if (coupon.type === 'PERCENTAGE') discount = subtotal * (coupon.value / 100);
      else if (coupon.type === 'FIXED_AMOUNT') discount = Math.min(coupon.value, subtotal);
      // FREE_SHIPPING handled at checkout UI level (shippingCost = 0)
    }

    if (coupon?.minOrderAmount && subtotal < coupon.minOrderAmount) {
      return next(createError(`Minimum order amount for this coupon is ${coupon.minOrderAmount}`, 400));
    }

    const shippingCost = 0; // shipping calculated by admin-configured ShippingRate table
    const tax = 0; // tax logic can be added per region
    const total = Math.max(0, subtotal - discount + shippingCost + tax);

    const order = await prisma.$transaction(async (tx) => {
      const newOrder = await tx.order.create({
        data: {
          orderNumber: generateOrderNumber(),
          buyerId: req.user!.userId,
          sellerId,
          currency: currency || 'AED',
          subtotal,
          discount,
          shippingCost,
          tax,
          total,
          notes,
          ...(shippingAddressId && { shippingAddressId }),
          ...(billingAddressId && { billingAddressId }),
          ...(coupon && { couponId: coupon.id }),
          items: { create: orderItemsData },
          payment: {
            create: {
              method: paymentMethod || 'CASH_ON_DELIVERY',
              status: 'PENDING',
              amount: total,
              currency: currency || 'AED',
            },
          },
        },
        include: {
          items: true,
          payment: true,
          shippingAddress: true,
        },
      });

      // Increment coupon usage
      if (coupon) {
        await tx.coupon.update({ where: { id: coupon.id }, data: { usedCount: { increment: 1 } } });
      }

      // Clear server-side cart items for this user+listings
      await tx.cartItem.deleteMany({
        where: { userId: req.user!.userId, listingId: { in: listingIds } },
      });

      // Build a rich order detail object for notifications (product options + all details).
      // Cast to Prisma.InputJsonValue: Prisma's Json fields require a value assignable to
      // InputJsonValue, which does not accept `unknown` — even though variantSummary here
      // is always either a string or null at runtime.
      const orderDetails = {
        orderId: newOrder.id,
        orderNumber: newOrder.orderNumber,
        total: newOrder.total,
        currency: newOrder.currency,
        items: orderItemsData.map((oi) => ({
          title: oi.title,
          quantity: oi.quantity,
          price: oi.price,
          variantSummary: ((oi as Record<string, unknown>).variantSummary ?? null) as Prisma.InputJsonValue,
        })),
      } as Prisma.InputJsonValue;

      // Collect admin user IDs to notify
      const admins = await tx.user.findMany({
        where: { role: 'ADMIN' },
        select: { id: true },
      });

      const notificationRows = [
        {
          userId: req.user!.userId,
          type: 'ORDER_PLACED' as const,
          title: 'Order placed',
          message: `Your order ${newOrder.orderNumber} has been placed successfully.`,
          data: orderDetails,
        },
        {
          userId: sellerId,
          type: 'ORDER_PLACED' as const,
          title: 'New order received',
          message: `New order ${newOrder.orderNumber} received. Check your dashboard for product option details.`,
          data: orderDetails,
        },
        ...admins.map((admin) => ({
          userId: admin.id,
          type: 'ORDER_PLACED' as const,
          title: 'New order (admin)',
          message: `Order ${newOrder.orderNumber} placed. All product options are included in data.`,
          data: orderDetails,
        })),
      ];

      // Deduplicate: if seller is also admin, avoid double notification
      const seen = new Set<string>();
      const dedupedRows = notificationRows.filter((r) => {
        if (seen.has(r.userId)) return false;
        seen.add(r.userId);
        return true;
      });

      await tx.notification.createMany({ data: dedupedRows });

      return newOrder;
    });

    res.status(201).json({ order });
  } catch (err) {
    next(err);
  }
});

// GET /api/orders — list orders for the current user (buyer or seller)
router.get('/', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { role = 'buyer', status, page = '1', limit = '20' } = req.query as Record<string, string>;
    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.min(50, Math.max(1, parseInt(limit)));
    const skip = (pageNum - 1) * limitNum;

    const isSeller = role === 'seller';
    const where = {
      ...(isSeller ? { sellerId: req.user!.userId } : { buyerId: req.user!.userId }),
      ...(status && { status: status as 'PENDING' }),
    };

    const [orders, total] = await Promise.all([
      prisma.order.findMany({
        where,
        include: {
          items: { include: { listing: { select: { id: true, title: true, images: true } } } },
          payment: { select: { status: true, method: true } },
          shippingAddress: true,
          buyer: { select: { id: true, name: true, avatar: true, email: true } },
          seller: { select: { id: true, name: true, avatar: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limitNum,
      }),
      prisma.order.count({ where }),
    ]);

    res.json({ orders, pagination: { total, page: pageNum, limit: limitNum, pages: Math.ceil(total / limitNum) } });
  } catch (err) {
    next(err);
  }
});

// GET /api/orders/:id — get a single order
router.get('/:id', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const order = await prisma.order.findUnique({
      where: { id: req.params.id },
      include: {
        items: { include: { listing: { select: { id: true, title: true, images: true, productImages: { where: { status: 'APPROVED' }, select: { cdnUrl: true }, take: 1 } } } } },
        payment: true,
        shippingAddress: true,
        billingAddress: true,
        coupon: { select: { code: true, type: true, value: true } },
        buyer: { select: { id: true, name: true, avatar: true, email: true, phone: true } },
        seller: { select: { id: true, name: true, avatar: true, email: true, phone: true } },
        returns: true,
      },
    });

    if (!order) return next(createError('Order not found', 404));
    if (order.buyerId !== req.user!.userId && order.sellerId !== req.user!.userId && req.user!.role !== 'ADMIN') {
      return next(createError('Forbidden', 403));
    }

    res.json({ order });
  } catch (err) {
    next(err);
  }
});

// PUT /api/orders/:id/status — update order status (seller or admin)
router.put('/:id/status', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { status, trackingNumber, cancellationNote } = req.body;
    if (!status) return next(createError('status is required', 400));

    const order = await prisma.order.findUnique({ where: { id: req.params.id } });
    if (!order) return next(createError('Order not found', 404));

    const canUpdate =
      req.user!.role === 'ADMIN' ||
      order.sellerId === req.user!.userId ||
      (order.buyerId === req.user!.userId && ['CANCELLED'].includes(status));

    if (!canUpdate) return next(createError('Forbidden', 403));

    const updateData: Record<string, unknown> = { status };
    if (trackingNumber) updateData.trackingNumber = trackingNumber;
    if (status === 'SHIPPED') updateData.shippedAt = new Date();
    if (status === 'DELIVERED') {
      updateData.deliveredAt = new Date();
      // Credit seller balance on delivery
      const sellerShare = order.total - order.shippingCost;
      await prisma.user.update({ where: { id: order.sellerId }, data: { balance: { increment: sellerShare } } });
      await prisma.payment.updateMany({ where: { orderId: order.id }, data: { status: 'COMPLETED', paidAt: new Date() } });
    }
    if (status === 'CANCELLED') {
      updateData.cancelledAt = new Date();
      if (cancellationNote) updateData.cancellationNote = cancellationNote;
    }

    const updated = await prisma.order.update({
      where: { id: req.params.id },
      data: updateData as Parameters<typeof prisma.order.update>[0]['data'],
      include: { items: true, payment: true },
    });

    // Notify buyer of status change
    const notifMap: Record<string, string> = {
      CONFIRMED: 'ORDER_CONFIRMED',
      SHIPPED: 'ORDER_SHIPPED',
      DELIVERED: 'ORDER_DELIVERED',
      CANCELLED: 'ORDER_CANCELLED',
    };
    if (notifMap[status]) {
      await prisma.notification.create({
        data: {
          userId: order.buyerId,
          type: notifMap[status] as 'ORDER_CONFIRMED',
          title: `Order ${status.toLowerCase()}`,
          message: `Your order ${order.orderNumber} has been ${status.toLowerCase()}.`,
          data: { orderId: order.id } as Prisma.InputJsonValue,
        },
      });
    }

    res.json({ order: updated });
  } catch (err) {
    next(err);
  }
});

// POST /api/orders/:id/return — buyer requests a return
router.post('/:id/return', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const order = await prisma.order.findUnique({ where: { id: req.params.id } });
    if (!order) return next(createError('Order not found', 404));
    if (order.buyerId !== req.user!.userId) return next(createError('Forbidden', 403));
    if (order.status !== 'DELIVERED') return next(createError('Only delivered orders can be returned', 400));

    const { reason, description, images } = req.body;
    if (!reason) return next(createError('Reason is required', 400));

    const ret = await prisma.return.create({
      data: {
        orderId: order.id,
        buyerId: req.user!.userId,
        reason,
        description,
        images: images || [],
      },
    });

    await prisma.notification.create({
      data: {
        userId: order.sellerId,
        type: 'RETURN_REQUESTED',
        title: 'Return requested',
        message: `Buyer has requested a return for order ${order.orderNumber}.`,
        data: { orderId: order.id, returnId: ret.id } as Prisma.InputJsonValue,
      },
    });

    res.status(201).json({ return: ret });
  } catch (err) {
    next(err);
  }
});

export default router;