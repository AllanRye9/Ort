"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const prisma_1 = require("../utils/prisma");
const auth_1 = require("../middleware/auth");
const errorHandler_1 = require("../middleware/errorHandler");
const router = (0, express_1.Router)();
router.use(auth_1.authenticate);
// GET /api/messages/conversations — one row per counterpart the current
// user has exchanged messages with, most-recent-first. Powers the Web
// Store "Customer communication" tool as well as the general inbox.
router.get('/conversations', async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const messages = await prisma_1.prisma.message.findMany({
            where: { OR: [{ senderId: userId }, { receiverId: userId }] },
            orderBy: { createdAt: 'desc' },
            include: {
                sender: { select: { id: true, name: true, avatar: true } },
                receiver: { select: { id: true, name: true, avatar: true } },
                listing: { select: { id: true, title: true, images: true } },
            },
            take: 500, // bounded scan; fine for a per-user inbox
        });
        const conversations = new Map();
        for (const m of messages) {
            const counterpart = m.senderId === userId ? m.receiver : m.sender;
            const key = counterpart.id;
            if (!conversations.has(key)) {
                conversations.set(key, {
                    counterpart: { id: counterpart.id, name: counterpart.name, avatar: counterpart.avatar },
                    lastMessage: m.content,
                    lastMessageAt: m.createdAt.toISOString(),
                    listing: m.listing ? { id: m.listing.id, title: m.listing.title, images: m.listing.images } : null,
                    unreadCount: 0,
                });
            }
            if (m.receiverId === userId && !m.read) {
                conversations.get(key).unreadCount += 1;
            }
        }
        res.json({ conversations: Array.from(conversations.values()) });
    }
    catch (err) {
        next(err);
    }
});
// GET /api/messages/thread/:userId — full message thread with one counterpart
router.get('/thread/:userId', async (req, res, next) => {
    try {
        const me = req.user.userId;
        const other = req.params.userId;
        const thread = await prisma_1.prisma.message.findMany({
            where: {
                OR: [
                    { senderId: me, receiverId: other },
                    { senderId: other, receiverId: me },
                ],
            },
            orderBy: { createdAt: 'asc' },
            include: { listing: { select: { id: true, title: true, images: true } } },
        });
        // Mark incoming messages in this thread as read
        await prisma_1.prisma.message.updateMany({
            where: { senderId: other, receiverId: me, read: false },
            data: { read: true },
        });
        res.json({ messages: thread });
    }
    catch (err) {
        next(err);
    }
});
// POST /api/messages — send a message (buyer <-> seller/store owner)
router.post('/', async (req, res, next) => {
    try {
        const { receiverId, content, listingId } = req.body;
        if (!receiverId)
            return next((0, errorHandler_1.createError)('receiverId is required', 400));
        if (!content || !content.trim())
            return next((0, errorHandler_1.createError)('Message content is required', 400));
        if (receiverId === req.user.userId)
            return next((0, errorHandler_1.createError)('Cannot message yourself', 400));
        const receiver = await prisma_1.prisma.user.findUnique({ where: { id: receiverId }, select: { id: true } });
        if (!receiver)
            return next((0, errorHandler_1.createError)('Recipient not found', 404));
        const message = await prisma_1.prisma.message.create({
            data: {
                senderId: req.user.userId,
                receiverId,
                content: content.trim(),
                listingId: listingId || null,
            },
            include: { listing: { select: { id: true, title: true, images: true } } },
        });
        await prisma_1.prisma.notification.create({
            data: {
                userId: receiverId,
                type: 'MESSAGE_RECEIVED',
                title: 'New message',
                message: content.trim().slice(0, 140),
                data: { senderId: req.user.userId, listingId: listingId || null },
            },
        }).catch(() => { });
        res.status(201).json({ message });
    }
    catch (err) {
        next(err);
    }
});
// PUT /api/messages/:id/read — mark a single message read
router.put('/:id/read', async (req, res, next) => {
    try {
        const message = await prisma_1.prisma.message.findUnique({ where: { id: req.params.id } });
        if (!message)
            return next((0, errorHandler_1.createError)('Message not found', 404));
        if (message.receiverId !== req.user.userId)
            return next((0, errorHandler_1.createError)('Forbidden', 403));
        const updated = await prisma_1.prisma.message.update({ where: { id: req.params.id }, data: { read: true } });
        res.json({ message: updated });
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=messages.js.map