"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const prisma_1 = require("../utils/prisma");
const auth_1 = require("../middleware/auth");
const errorHandler_1 = require("../middleware/errorHandler");
const router = (0, express_1.Router)();
router.use(auth_1.authenticate);
// GET /api/addresses — list user's saved addresses
router.get('/', async (req, res, next) => {
    try {
        const addresses = await prisma_1.prisma.address.findMany({
            where: { userId: req.user.userId },
            orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
        });
        res.json({ addresses });
    }
    catch (err) {
        next(err);
    }
});
// POST /api/addresses — create a new address
router.post('/', async (req, res, next) => {
    try {
        const { type, fullName, phone, line1, line2, city, state, postalCode, country, isDefault } = req.body;
        if (!fullName || !phone || !line1 || !city || !country) {
            return next((0, errorHandler_1.createError)('Missing required address fields', 400));
        }
        // If setting as default, clear existing defaults
        if (isDefault) {
            await prisma_1.prisma.address.updateMany({
                where: { userId: req.user.userId },
                data: { isDefault: false },
            });
        }
        const address = await prisma_1.prisma.address.create({
            data: {
                userId: req.user.userId,
                type: type || 'BOTH',
                fullName,
                phone,
                line1,
                line2,
                city,
                state,
                postalCode,
                country,
                isDefault: isDefault || false,
            },
        });
        res.status(201).json({ address });
    }
    catch (err) {
        next(err);
    }
});
// PUT /api/addresses/:id — update an address
router.put('/:id', async (req, res, next) => {
    try {
        const existing = await prisma_1.prisma.address.findUnique({ where: { id: req.params.id } });
        if (!existing || existing.userId !== req.user.userId) {
            return next((0, errorHandler_1.createError)('Address not found', 404));
        }
        const { type, fullName, phone, line1, line2, city, state, postalCode, country, isDefault } = req.body;
        if (isDefault) {
            await prisma_1.prisma.address.updateMany({
                where: { userId: req.user.userId, id: { not: req.params.id } },
                data: { isDefault: false },
            });
        }
        const address = await prisma_1.prisma.address.update({
            where: { id: req.params.id },
            data: {
                ...(type && { type }),
                ...(fullName && { fullName }),
                ...(phone && { phone }),
                ...(line1 && { line1 }),
                ...(line2 !== undefined && { line2 }),
                ...(city && { city }),
                ...(state !== undefined && { state }),
                ...(postalCode !== undefined && { postalCode }),
                ...(country && { country }),
                ...(isDefault !== undefined && { isDefault }),
            },
        });
        res.json({ address });
    }
    catch (err) {
        next(err);
    }
});
// DELETE /api/addresses/:id — delete an address
router.delete('/:id', async (req, res, next) => {
    try {
        const existing = await prisma_1.prisma.address.findUnique({ where: { id: req.params.id } });
        if (!existing || existing.userId !== req.user.userId) {
            return next((0, errorHandler_1.createError)('Address not found', 404));
        }
        await prisma_1.prisma.address.delete({ where: { id: req.params.id } });
        res.json({ message: 'Address deleted' });
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=addresses.js.map