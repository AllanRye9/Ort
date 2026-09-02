"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const prisma_1 = require("../utils/prisma");
const auth_1 = require("../middleware/auth");
const errorHandler_1 = require("../middleware/errorHandler");
const router = (0, express_1.Router)();
const VALID_SERVICE_TYPES = [
    'linkedin',
    'cv-writing',
    'career',
    'coaching',
    'interview',
    'cover-letter',
    'template',
];
// POST /api/cv-service-requests — submit a CV service request (public)
router.post('/', async (req, res, next) => {
    try {
        const serviceType = String(req.body?.serviceType ?? 'cv-service');
        if (!VALID_SERVICE_TYPES.includes(serviceType)) {
            return next((0, errorHandler_1.createError)('Invalid serviceType', 400));
        }
        res.status(410).json({
            message: 'Manual CV service requests have been retired. Use the in-app digital CV tools with an active subscription.',
        });
    }
    catch (err) {
        next(err);
    }
});
// GET /api/cv-service-requests — admin only: list all requests
router.get('/', auth_1.authenticate, (0, auth_1.authorize)('ADMIN'), async (req, res, next) => {
    try {
        const page = Math.max(1, parseInt(req.query.page || '1'));
        const limit = Math.min(100, Math.max(1, parseInt(req.query.limit || '20')));
        const skip = (page - 1) * limit;
        const status = req.query.status;
        const serviceType = req.query.serviceType;
        const where = {};
        if (status)
            where.status = status;
        if (serviceType)
            where.serviceType = serviceType;
        const [requests, total] = await Promise.all([
            prisma_1.prisma.cvServiceRequest.findMany({
                where,
                orderBy: { createdAt: 'desc' },
                skip,
                take: limit,
            }),
            prisma_1.prisma.cvServiceRequest.count({ where }),
        ]);
        res.json({ requests, total, page, limit, pages: Math.ceil(total / limit) });
    }
    catch (err) {
        next(err);
    }
});
// PATCH /api/cv-service-requests/:id — admin only: update status
router.patch('/:id', auth_1.authenticate, (0, auth_1.authorize)('ADMIN'), async (req, res, next) => {
    try {
        const { status } = req.body;
        const validStatuses = ['pending', 'in-progress', 'completed', 'cancelled'];
        if (!status || !validStatuses.includes(status)) {
            return next((0, errorHandler_1.createError)('Invalid status', 400));
        }
        const updated = await prisma_1.prisma.cvServiceRequest.update({
            where: { id: req.params.id },
            data: { status },
        });
        res.json(updated);
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=cvServiceRequests.js.map