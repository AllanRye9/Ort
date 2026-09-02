"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const prisma_1 = require("../utils/prisma");
const errorHandler_1 = require("../middleware/errorHandler");
const router = (0, express_1.Router)();
// GET /api/coupons/validate?code=... — validate a coupon code (public)
router.get('/validate', async (req, res, next) => {
    try {
        const code = req.query.code?.trim().toUpperCase();
        if (!code)
            return next((0, errorHandler_1.createError)('code is required', 400));
        const coupon = await prisma_1.prisma.coupon.findUnique({ where: { code } });
        if (!coupon || !coupon.isActive)
            return next((0, errorHandler_1.createError)('Invalid coupon code', 404));
        if (coupon.expiresAt && coupon.expiresAt < new Date())
            return next((0, errorHandler_1.createError)('Coupon has expired', 400));
        if (coupon.maxUses != null && coupon.usedCount >= coupon.maxUses) {
            return next((0, errorHandler_1.createError)('Coupon usage limit reached', 400));
        }
        res.json({
            valid: true,
            code: coupon.code,
            type: coupon.type,
            value: coupon.value,
            minOrderAmount: coupon.minOrderAmount,
            expiresAt: coupon.expiresAt,
        });
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=coupons.js.map