"use strict";
/**
 * CV Payment & Download Token Routes
 *
 * Flow:
 * 1. POST /api/cv-payment/initiate  — creates a pending token, returns tokenId
 * 2. POST /api/cv-payment/confirm   — marks token as paid (real: called by payment webhook)
 * 3. GET  /api/cv-payment/token/:id — validates token; returns {valid, token} for frontend
 *
 * The frontend generates the CV HTML client-side but must hit /token/:id first
 * to confirm payment before enabling the download blob.
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const crypto_1 = __importDefault(require("crypto"));
const express_1 = require("express");
const prisma_1 = require("../utils/prisma");
const auth_1 = require("../middleware/auth");
const errorHandler_1 = require("../middleware/errorHandler");
const cvPackage_1 = require("../utils/cvPackage");
const router = (0, express_1.Router)();
// ── GET /api/cv-payment/active-package ────────────────────────────────────────
// Tells the frontend which CV package (if any) currently governs the builder,
// the exact price it should show/charge (sourced solely from that package —
// there is no hardcoded fallback), and whether this user/device has already
// hit that package's "max generated CV" limit. When no package is active (or
// the active one's duration window has elapsed) this returns
// { configured: false, package: null, price: null } and the frontend must
// disable downloading until the admin activates a package.
router.get('/active-package', auth_1.optionalAuthenticate, async (req, res, next) => {
    try {
        const { country, deviceId } = req.query;
        const context = await (0, cvPackage_1.resolveCvCheckoutContext)({
            country,
            userId: req.user?.userId ?? null,
            deviceId: deviceId ?? null,
        });
        res.json(context);
    }
    catch (err) {
        next(err);
    }
});
// ── POST /api/cv-payment/initiate ─────────────────────────────────────────────
// Creates a pending CvDownloadToken and returns its ID so the frontend can
// redirect to the payment gateway with it as a reference. Pricing and limits
// come exclusively from the currently active CV package — there is no
// per-country default. If no CV package is active, there is nothing to
// charge, so the request is rejected.
router.post('/initiate', auth_1.optionalAuthenticate, async (req, res, next) => {
    try {
        const { country = 'UAE', deviceId, holder } = req.body;
        const userId = req.user?.userId ?? null;
        const pkg = await (0, cvPackage_1.getActiveCvPackage)();
        if (!pkg) {
            return next((0, errorHandler_1.createError)('No CV package is currently active — pricing has not been configured yet.', 400));
        }
        if (pkg.isFree) {
            return next((0, errorHandler_1.createError)('This package is free — use the free download endpoint instead of paying.', 400));
        }
        const used = await (0, cvPackage_1.countGenerationsForOwner)(pkg.id, userId, deviceId ?? null);
        if (pkg.maxListings != null && used >= pkg.maxListings) {
            return next((0, errorHandler_1.createError)(`You've reached the maximum of ${pkg.maxListings} CV download${pkg.maxListings === 1 ? '' : 's'} allowed under the "${pkg.name}" package.`, 403));
        }
        const price = { amount: pkg.price, currency: pkg.currency };
        const rawToken = crypto_1.default.randomBytes(32).toString('hex');
        const tokenHash = crypto_1.default.createHash('sha256').update(rawToken).digest('hex');
        const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 h
        const record = await prisma_1.prisma.cvDownloadToken.create({
            data: {
                userId,
                deviceId: deviceId ?? null,
                packageId: pkg.id,
                tokenHash,
                paid: false,
                amount: price.amount,
                currency: price.currency,
                country,
                expiresAt,
                holderName: holder?.name?.trim() || null,
                holderTitle: holder?.title?.trim() || null,
                holderEmail: holder?.email?.trim() || null,
                holderPhone: holder?.phone?.trim() || null,
            },
        });
        // Return the record ID and the raw token.
        // The raw token is what the client stores; the hash is what the DB stores.
        // The client presents rawToken at confirm and validate time.
        res.status(201).json({
            tokenId: record.id,
            rawToken, // store in sessionStorage — never exposed in URL
            amount: price.amount,
            currency: price.currency,
        });
    }
    catch (err) {
        next(err);
    }
});
// ── POST /api/cv-payment/free-download ─────────────────────────────────────────
// Used only when the currently active CV package is marked free. Skips the
// payment gateway entirely — issues an already-paid token (subject to the
// package's max-generations limit) so the frontend can go straight to
// /validate and download, with no payment modal shown.
router.post('/free-download', auth_1.optionalAuthenticate, async (req, res, next) => {
    try {
        const { country = 'UAE', deviceId, holder } = req.body;
        const userId = req.user?.userId ?? null;
        const pkg = await (0, cvPackage_1.getActiveCvPackage)();
        if (!pkg || !pkg.isFree) {
            return next((0, errorHandler_1.createError)('No free CV package is currently active.', 400));
        }
        const used = await (0, cvPackage_1.countGenerationsForOwner)(pkg.id, userId, deviceId ?? null);
        if (pkg.maxListings != null && used >= pkg.maxListings) {
            return next((0, errorHandler_1.createError)(`You've reached the maximum of ${pkg.maxListings} free CV download${pkg.maxListings === 1 ? '' : 's'} allowed under the "${pkg.name}" package.`, 403));
        }
        const rawToken = crypto_1.default.randomBytes(32).toString('hex');
        const tokenHash = crypto_1.default.createHash('sha256').update(rawToken).digest('hex');
        const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 h
        const record = await prisma_1.prisma.cvDownloadToken.create({
            data: {
                userId,
                deviceId: deviceId ?? null,
                packageId: pkg.id,
                tokenHash,
                paid: true, // free packages skip the payment step entirely
                amount: 0,
                currency: pkg.currency,
                country,
                expiresAt,
                holderName: holder?.name?.trim() || null,
                holderTitle: holder?.title?.trim() || null,
                holderEmail: holder?.email?.trim() || null,
                holderPhone: holder?.phone?.trim() || null,
            },
        });
        res.status(201).json({
            tokenId: record.id,
            rawToken,
            amount: 0,
            currency: pkg.currency,
        });
    }
    catch (err) {
        next(err);
    }
});
// ── POST /api/cv-payment/confirm ─────────────────────────────────────────────
// Called by the payment gateway webhook (or by the frontend after a successful
// gateway callback) to mark the token as paid.
// In production: verify the gateway signature before trusting this call.
router.post('/confirm', async (req, res, next) => {
    try {
        const { rawToken } = req.body;
        if (!rawToken)
            return next((0, errorHandler_1.createError)('rawToken is required', 400));
        const tokenHash = crypto_1.default.createHash('sha256').update(rawToken).digest('hex');
        const record = await prisma_1.prisma.cvDownloadToken.findUnique({ where: { tokenHash } });
        if (!record)
            return next((0, errorHandler_1.createError)('Invalid token', 404));
        if (record.expiresAt < new Date())
            return next((0, errorHandler_1.createError)('Token expired', 410));
        if (record.paid)
            return res.json({ already: true, tokenId: record.id });
        await prisma_1.prisma.cvDownloadToken.update({
            where: { id: record.id },
            data: { paid: true },
        });
        res.json({ confirmed: true, tokenId: record.id });
    }
    catch (err) {
        next(err);
    }
});
// ── GET /api/cv-payment/validate/:tokenId ─────────────────────────────────────
// Called by the frontend just before triggering the download blob.
// Returns { valid: true } only when the token is paid, not expired, not used.
router.get('/validate/:tokenId', async (req, res, next) => {
    try {
        const { tokenId } = req.params;
        const { rawToken } = req.query;
        if (!rawToken)
            return next((0, errorHandler_1.createError)('rawToken query param required', 400));
        const tokenHash = crypto_1.default.createHash('sha256').update(rawToken).digest('hex');
        const record = await prisma_1.prisma.cvDownloadToken.findUnique({ where: { id: tokenId } });
        if (!record || record.tokenHash !== tokenHash)
            return res.json({ valid: false, reason: 'invalid' });
        if (!record.paid)
            return res.json({ valid: false, reason: 'unpaid' });
        if (record.expiresAt < new Date())
            return res.json({ valid: false, reason: 'expired' });
        // Mark as used (single-use download unlock per token)
        if (!record.usedAt) {
            await prisma_1.prisma.cvDownloadToken.update({ where: { id: tokenId }, data: { usedAt: new Date() } });
        }
        res.json({ valid: true, currency: record.currency, amount: Number(record.amount) });
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=cvPayment.js.map