"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const prisma_1 = require("../utils/prisma");
const auth_1 = require("../middleware/auth");
const errorHandler_1 = require("../middleware/errorHandler");
const email_1 = require("../utils/email");
const router = (0, express_1.Router)();
const PACKAGE_SCOPES = ['LISTING', 'CV'];
function parseScope(scope) {
    if (!scope)
        return 'LISTING';
    if (PACKAGE_SCOPES.includes(scope))
        return scope;
    throw (0, errorHandler_1.createError)('scope must be LISTING or CV', 400);
}
// ─── Public: list active packages ─────────────────────────────────────────────
router.get('/', async (req, res, next) => {
    try {
        const scope = parseScope(req.query.scope);
        const packages = await prisma_1.prisma.sellerPackage.findMany({
            where: { isActive: true, scope },
            orderBy: [{ isFree: 'desc' }, { price: 'asc' }],
        });
        res.json({ packages });
    }
    catch (err) {
        next(err);
    }
});
// ─── Authenticated: get caller's current active subscription ──────────────────
router.get('/my-subscription', auth_1.authenticate, async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const scope = parseScope(req.query.scope);
        // Mark any expired subscriptions first
        await prisma_1.prisma.sellerSubscription.updateMany({
            where: { userId, status: 'ACTIVE', endDate: { lt: new Date() } },
            data: { status: 'EXPIRED' },
        });
        const subscription = await prisma_1.prisma.sellerSubscription.findFirst({
            where: { userId, status: 'ACTIVE', package: { scope } },
            include: { package: true },
            orderBy: { endDate: 'desc' },
        });
        res.json({ subscription: subscription ?? null });
    }
    catch (err) {
        next(err);
    }
});
// ─── Authenticated: subscribe to a package ────────────────────────────────────
router.post('/:id/subscribe', auth_1.authenticate, async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { id: packageId } = req.params;
        const { paymentRef } = req.body;
        const pkg = await prisma_1.prisma.sellerPackage.findUnique({ where: { id: packageId } });
        if (!pkg || !pkg.isActive)
            throw (0, errorHandler_1.createError)('Package not found or inactive', 404);
        // Paid packages require a payment reference
        if (!pkg.isFree && !paymentRef) {
            throw (0, errorHandler_1.createError)('paymentRef is required for paid packages', 400);
        }
        // Check if seller already has an active subscription
        await prisma_1.prisma.sellerSubscription.updateMany({
            where: { userId, status: 'ACTIVE', endDate: { lt: new Date() } },
            data: { status: 'EXPIRED' },
        });
        const existing = await prisma_1.prisma.sellerSubscription.findFirst({
            where: { userId, status: 'ACTIVE', package: { scope: pkg.scope } },
        });
        if (existing)
            throw (0, errorHandler_1.createError)(`You already have an active ${pkg.scope.toLowerCase()} subscription`, 409);
        const startDate = new Date();
        const endDate = new Date(startDate);
        endDate.setDate(endDate.getDate() + pkg.durationDays);
        // Free packages activate immediately; paid CV packages also activate immediately.
        const subscriptionStatus = pkg.isFree ? 'ACTIVE' : pkg.scope === 'CV' ? 'ACTIVE' : 'PENDING_PAYMENT';
        const subscription = await prisma_1.prisma.sellerSubscription.create({
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
            await prisma_1.prisma.notification.create({
                data: {
                    userId,
                    type: 'SUBSCRIPTION_ACTIVATED',
                    title: 'Subscription Activated',
                    message: `Your "${pkg.name}" package is now active until ${endDate.toLocaleDateString()}.`,
                    data: { subscriptionId: subscription.id, packageName: pkg.name },
                },
            });
            if (!pkg.isFree) {
                const user = await prisma_1.prisma.user.findUnique({ where: { id: userId } });
                if (user?.email) {
                    await (0, email_1.sendSubscriptionActivatedEmail)(user.email, user.name ?? 'Member', pkg.name, endDate);
                }
            }
        }
        else {
            await prisma_1.prisma.notification.create({
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
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=packages.js.map