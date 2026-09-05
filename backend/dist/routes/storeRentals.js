"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const prisma_1 = require("../utils/prisma");
const auth_1 = require("../middleware/auth");
const errorHandler_1 = require("../middleware/errorHandler");
const router = (0, express_1.Router)();
// Uganda-launch defaults — fees quoted in UGX (the site's default currency).
const STORE_PLANS = {
    FREE_TRIAL: { fee: 0, currency: 'UGX', durationDays: 3 },
    MONTHLY: { fee: 60000, currency: 'UGX', durationDays: 30 },
    ANNUAL: { fee: 300000, currency: 'UGX', durationDays: 365 },
};
// ─── Public / listing routes ───────────────────────────────────────────────────
// GET /api/store-rentals — list active rentals (public directory)
router.get('/', async (req, res, next) => {
    try {
        const entityType = req.query.entityType;
        const page = Math.max(1, parseInt(req.query.page || '1'));
        const limit = Math.min(50, Math.max(1, parseInt(req.query.limit || '20')));
        const skip = (page - 1) * limit;
        const now = new Date();
        const where = {
            status: 'ACTIVE',
            endDate: { gt: now },
        };
        if (entityType)
            where.entityType = entityType.toUpperCase();
        const [rentals, total] = await Promise.all([
            prisma_1.prisma.storeRental.findMany({
                where,
                include: {
                    user: {
                        select: {
                            id: true,
                            name: true,
                            avatar: true,
                            country: true,
                            role: true,
                            companyName: true,
                            businessDescription: true,
                            website: true,
                            store: { select: { id: true, name: true, slug: true, logo: true, banner: true, rating: true, ratingCount: true } },
                        },
                    },
                },
                orderBy: { createdAt: 'desc' },
                skip,
                take: limit,
            }),
            prisma_1.prisma.storeRental.count({ where }),
        ]);
        res.json({ rentals, total, page, limit, pages: Math.ceil(total / limit) });
    }
    catch (err) {
        next(err);
    }
});
// ─── Authenticated renter routes ───────────────────────────────────────────────
// GET /api/store-rentals/my — current user's active rental
router.get('/my', auth_1.authenticate, async (req, res, next) => {
    try {
        const now = new Date();
        const latestRental = await prisma_1.prisma.storeRental.findFirst({
            where: { userId: req.user.userId },
            orderBy: { createdAt: 'desc' },
        });
        if (!latestRental)
            return res.json({ rental: null });
        const shouldExpire = latestRental.status === 'ACTIVE' && latestRental.endDate <= now;
        const rental = shouldExpire
            ? await prisma_1.prisma.storeRental.update({
                where: { id: latestRental.id },
                data: { status: 'EXPIRED' },
            })
            : latestRental;
        res.json({ rental });
    }
    catch (err) {
        next(err);
    }
});
// POST /api/store-rentals — request a rental (admin approves)
// Any authenticated user can apply; if their role is USER we auto-promote them
// to AGENT (the minimum seller role) so they can post listings after approval.
router.post('/', auth_1.authenticate, async (req, res, next) => {
    try {
        const { entityType, plan, placements } = req.body;
        const currentRole = req.user.role;
        // Determine the effective entity type the user wants to register as
        const validEntityTypes = ['USER', 'AGENT', 'COMPANY', 'ORGANIZATION'];
        const rawEntityType = (entityType || currentRole || 'AGENT').toUpperCase();
        // Default USER-role registrants to AGENT unless they specified something else
        const et = rawEntityType === 'USER' ? 'AGENT' : rawEntityType;
        if (!validEntityTypes.includes(et)) {
            return next((0, errorHandler_1.createError)('Invalid entityType', 400));
        }
        const selectedPlan = String(plan || '').toUpperCase();
        if (!selectedPlan || !STORE_PLANS[selectedPlan]) {
            return next((0, errorHandler_1.createError)('plan must be FREE_TRIAL, MONTHLY, or ANNUAL', 400));
        }
        // Auto-promote regular USER accounts to the seller role they selected
        // This happens before the rental is created so the role is available immediately
        const sellerRoles = ['AGENT', 'COMPANY', 'ORGANIZATION'];
        if (!sellerRoles.includes(currentRole) && currentRole !== 'ADMIN') {
            const newRole = sellerRoles.includes(et) ? et : 'AGENT';
            await prisma_1.prisma.user.update({
                where: { id: req.user.userId },
                data: { role: newRole },
            });
        }
        const now = new Date();
        const existingActiveOrPending = await prisma_1.prisma.storeRental.findFirst({
            where: {
                userId: req.user.userId,
                status: { in: ['PENDING', 'ACTIVE'] },
                endDate: { gt: now },
            },
        });
        if (existingActiveOrPending) {
            return next((0, errorHandler_1.createError)('You already have an active or pending store application', 409));
        }
        const planDef = STORE_PLANS[selectedPlan];
        const end = new Date(now.getTime() + planDef.durationDays * 24 * 60 * 60 * 1000);
        const rental = await prisma_1.prisma.storeRental.create({
            data: {
                userId: req.user.userId,
                entityType: et,
                fee: planDef.fee,
                currency: planDef.currency,
                startDate: now,
                endDate: end,
                placements: {
                    ...(placements || {}),
                    subscriptionPlan: selectedPlan,
                    paymentStatus: planDef.fee === 0 ? 'WAIVED' : 'PENDING',
                    renewalDate: end.toISOString(),
                },
                status: 'PENDING',
            },
        });
        const admins = await prisma_1.prisma.user.findMany({
            where: { role: 'ADMIN' },
            select: { id: true },
        });
        if (admins.length > 0) {
            await prisma_1.prisma.notification.createMany({
                data: admins.map((admin) => ({
                    userId: admin.id,
                    type: 'SYSTEM',
                    title: 'New Store Application',
                    message: `A user requested a ${selectedPlan.replace('_', ' ')} store plan.`,
                    data: { rentalId: rental.id, userId: req.user.userId, plan: selectedPlan },
                })),
            });
        }
        res.status(201).json({
            rental,
            message: 'Store application submitted for admin review.',
        });
    }
    catch (err) {
        next(err);
    }
});
// PATCH /api/store-rentals/my/placements — update placement preferences
router.patch('/my/placements', auth_1.authenticate, async (req, res, next) => {
    try {
        const { placements } = req.body;
        const now = new Date();
        const rental = await prisma_1.prisma.storeRental.findFirst({
            where: { userId: req.user.userId, status: 'ACTIVE', endDate: { gt: now } },
            orderBy: { createdAt: 'desc' },
        });
        if (!rental)
            return next((0, errorHandler_1.createError)('No active rental found', 404));
        const updated = await prisma_1.prisma.storeRental.update({
            where: { id: rental.id },
            data: { placements },
        });
        res.json({ rental: updated });
    }
    catch (err) {
        next(err);
    }
});
// ─── Admin routes ──────────────────────────────────────────────────────────────
// GET /api/store-rentals/admin/all — list all rentals
router.get('/admin/all', auth_1.authenticate, (0, auth_1.authorize)('ADMIN'), async (req, res, next) => {
    try {
        const status = req.query.status;
        const page = Math.max(1, parseInt(req.query.page || '1'));
        const limit = Math.min(100, Math.max(1, parseInt(req.query.limit || '20')));
        const skip = (page - 1) * limit;
        const where = {};
        if (status)
            where.status = status.toUpperCase();
        const [rentals, total] = await Promise.all([
            prisma_1.prisma.storeRental.findMany({
                where,
                include: {
                    user: { select: { id: true, name: true, email: true, role: true, companyName: true } },
                },
                orderBy: { createdAt: 'desc' },
                skip,
                take: limit,
            }),
            prisma_1.prisma.storeRental.count({ where }),
        ]);
        res.json({ rentals, total, page, limit, pages: Math.ceil(total / limit) });
    }
    catch (err) {
        next(err);
    }
});
// PATCH /api/store-rentals/admin/:id — approve/reject/update a rental
router.patch('/admin/:id', auth_1.authenticate, (0, auth_1.authorize)('ADMIN'), async (req, res, next) => {
    try {
        const { status, fee, endDate, maxListings } = req.body;
        const existing = await prisma_1.prisma.storeRental.findUnique({
            where: { id: req.params.id },
            include: { user: { select: { id: true, name: true, email: true, role: true } } },
        });
        if (!existing)
            return next((0, errorHandler_1.createError)('Rental not found', 404));
        const validStatuses = ['PENDING', 'ACTIVE', 'EXPIRED', 'CANCELLED'];
        if (status && !validStatuses.includes(status.toUpperCase())) {
            return next((0, errorHandler_1.createError)('Invalid status', 400));
        }
        const newStatus = status ? status.toUpperCase() : undefined;
        const updated = await prisma_1.prisma.storeRental.update({
            where: { id: req.params.id },
            data: {
                ...(newStatus && { status: newStatus }),
                ...(fee !== undefined && { fee: Number(fee) }),
                ...(endDate && { endDate: new Date(endDate) }),
                ...(maxListings !== undefined && { maxListings: Number(maxListings) }),
            },
            include: {
                user: { select: { id: true, name: true, email: true } },
            },
        });
        // ── When a rental is APPROVED (ACTIVE): grant store owner unlimited listing access ──
        // This removes the subscription requirement: store owners who paid the store fee
        // ($100 USD) should not need a separate listing subscription.
        if (newStatus === 'ACTIVE' && existing.status !== 'ACTIVE') {
            const userId = existing.userId;
            // Ensure the user has the correct seller role
            const sellerRoles = ['AGENT', 'COMPANY', 'ORGANIZATION', 'SELLER'];
            if (!sellerRoles.includes(existing.user.role) && existing.user.role !== 'ADMIN') {
                const targetRole = sellerRoles.includes(existing.entityType) ? existing.entityType : 'AGENT';
                await prisma_1.prisma.user.update({
                    where: { id: userId },
                    data: { role: targetRole },
                });
            }
            // Find or create an unlimited/store listing package
            let storePkg = await prisma_1.prisma.sellerPackage.findFirst({
                where: { scope: 'LISTING', isFree: false, maxListings: null, isActive: true },
                orderBy: { createdAt: 'asc' },
            });
            // If no unlimited package exists, create one specifically for store owners
            if (!storePkg) {
                storePkg = await prisma_1.prisma.sellerPackage.create({
                    data: {
                        name: 'Store Owner — Unlimited Listings',
                        description: 'Granted automatically to approved store owners. Includes unlimited listings for the duration of their store rental.',
                        scope: 'LISTING',
                        isFree: false,
                        price: 0,
                        currency: 'AED',
                        durationDays: 3650, // 10 years — effectively permanent
                        maxListings: null, // null = unlimited
                        isActive: true,
                    },
                });
            }
            // Cancel any existing listing subscriptions to avoid conflicts
            await prisma_1.prisma.sellerSubscription.updateMany({
                where: { userId, status: 'ACTIVE', package: { scope: 'LISTING' } },
                data: { status: 'EXPIRED' },
            });
            // Grant a new unlimited subscription tied to the store rental end date
            const rentalEndDate = endDate ? new Date(endDate) : existing.endDate;
            await prisma_1.prisma.sellerSubscription.create({
                data: {
                    userId,
                    packageId: storePkg.id,
                    status: 'ACTIVE',
                    startDate: new Date(),
                    endDate: rentalEndDate,
                },
            });
            // Notify the store owner
            await prisma_1.prisma.notification.create({
                data: {
                    userId,
                    type: 'SUBSCRIPTION_ACTIVATED',
                    title: '🎉 Your Store is Now Active!',
                    message: `Congratulations! Your store has been approved. You can now list up to ${existing.maxListings} active listings — no additional subscription required.`,
                    data: { rentalId: existing.id },
                },
            }).catch(() => { });
            // Provision a Store record if it doesn't exist yet
            const existingStore = await prisma_1.prisma.store.findUnique({ where: { userId } });
            if (!existingStore) {
                const placementsData = existing.placements || {};
                const providedName = typeof placementsData.storeName === 'string' ? placementsData.storeName.trim() : '';
                const providedDescription = typeof placementsData.storeDescription === 'string' ? placementsData.storeDescription.trim() : '';
                const baseName = providedName || existing.user.name || 'My Store';
                const baseSlug = baseName.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '') + '-' + userId.slice(0, 6);
                // Guarantee slug uniqueness — try base slug, then append -2, -3, etc.
                let finalSlug = baseSlug;
                let attempt = 1;
                while (await prisma_1.prisma.store.findUnique({ where: { slug: finalSlug } })) {
                    attempt++;
                    finalSlug = `${baseSlug}-${attempt}`;
                }
                await prisma_1.prisma.store.create({
                    data: {
                        userId,
                        name: baseName,
                        slug: finalSlug,
                        description: providedDescription || null,
                        isActive: true,
                    },
                });
            }
            else if (!existingStore.isActive) {
                // Re-activate the store if it was previously deactivated
                await prisma_1.prisma.store.update({
                    where: { userId },
                    data: { isActive: true },
                });
            }
        }
        // ── When a rental is CANCELLED/EXPIRED: deactivate the store ──
        if ((newStatus === 'CANCELLED' || newStatus === 'EXPIRED') && existing.status === 'ACTIVE') {
            await prisma_1.prisma.store.updateMany({
                where: { userId: existing.userId },
                data: { isActive: false },
            });
            // Expire the unlimited listing subscription
            await prisma_1.prisma.sellerSubscription.updateMany({
                where: { userId: existing.userId, status: 'ACTIVE', package: { scope: 'LISTING' } },
                data: { status: 'EXPIRED' },
            });
            await prisma_1.prisma.notification.create({
                data: {
                    userId: existing.userId,
                    type: 'SYSTEM',
                    title: 'Store Deactivated',
                    message: 'Your store rental has ended and your store has been deactivated. Renew your store rental to reactivate it.',
                    data: { rentalId: existing.id },
                },
            }).catch(() => { });
        }
        res.json({ rental: updated });
    }
    catch (err) {
        next(err);
    }
});
// DELETE /api/store-rentals/admin/:id — delete a rental
router.delete('/admin/:id', auth_1.authenticate, (0, auth_1.authorize)('ADMIN'), async (req, res, next) => {
    try {
        const existing = await prisma_1.prisma.storeRental.findUnique({ where: { id: req.params.id } });
        if (!existing)
            return next((0, errorHandler_1.createError)('Rental not found', 404));
        await prisma_1.prisma.storeRental.delete({ where: { id: req.params.id } });
        res.json({ message: 'Rental deleted' });
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=storeRentals.js.map