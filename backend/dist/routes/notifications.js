"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const prisma_1 = require("../utils/prisma");
const auth_1 = require("../middleware/auth");
const errorHandler_1 = require("../middleware/errorHandler");
const router = (0, express_1.Router)();
router.use(auth_1.authenticate);
const EXCLUDED_NOTIFICATION_TYPES = ['MESSAGE_RECEIVED'];
// GET /api/notifications — list current user's notifications
router.get('/', async (req, res, next) => {
    try {
        const { page = '1', limit = '30', unreadOnly } = req.query;
        const pageNum = Math.max(1, parseInt(page));
        const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
        const skip = (pageNum - 1) * limitNum;
        const where = {
            userId: req.user.userId,
            type: { notIn: [...EXCLUDED_NOTIFICATION_TYPES] },
            ...(unreadOnly === 'true' && { read: false }),
        };
        const [notifications, total, unreadCount] = await Promise.all([
            prisma_1.prisma.notification.findMany({
                where,
                orderBy: { createdAt: 'desc' },
                skip,
                take: limitNum,
            }),
            prisma_1.prisma.notification.count({ where }),
            prisma_1.prisma.notification.count({ where: { userId: req.user.userId, read: false, type: { notIn: [...EXCLUDED_NOTIFICATION_TYPES] } } }),
        ]);
        res.json({ notifications, total, unreadCount, page: pageNum, limit: limitNum });
    }
    catch (err) {
        next(err);
    }
});
// GET /api/notifications/unread-count
router.get('/unread-count', async (req, res, next) => {
    try {
        const count = await prisma_1.prisma.notification.count({
            where: { userId: req.user.userId, read: false, type: { notIn: [...EXCLUDED_NOTIFICATION_TYPES] } },
        });
        res.json({ count });
    }
    catch (err) {
        next(err);
    }
});
// PUT /api/notifications/:id/read — mark a notification as read
router.put('/:id/read', async (req, res, next) => {
    try {
        const notif = await prisma_1.prisma.notification.findUnique({ where: { id: req.params.id } });
        if (!notif || notif.userId !== req.user.userId) {
            return next((0, errorHandler_1.createError)('Notification not found', 404));
        }
        const updated = await prisma_1.prisma.notification.update({
            where: { id: req.params.id },
            data: { read: true },
        });
        res.json({ notification: updated });
    }
    catch (err) {
        next(err);
    }
});
// PUT /api/notifications/read-all — mark all notifications as read
router.put('/read-all', async (req, res, next) => {
    try {
        await prisma_1.prisma.notification.updateMany({
            where: { userId: req.user.userId, read: false, type: { notIn: [...EXCLUDED_NOTIFICATION_TYPES] } },
            data: { read: true },
        });
        res.json({ message: 'All notifications marked as read' });
    }
    catch (err) {
        next(err);
    }
});
// DELETE /api/notifications/:id
router.delete('/:id', async (req, res, next) => {
    try {
        const notif = await prisma_1.prisma.notification.findUnique({ where: { id: req.params.id } });
        if (!notif || notif.userId !== req.user.userId) {
            return next((0, errorHandler_1.createError)('Notification not found', 404));
        }
        await prisma_1.prisma.notification.delete({ where: { id: req.params.id } });
        res.json({ message: 'Notification deleted' });
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=notifications.js.map