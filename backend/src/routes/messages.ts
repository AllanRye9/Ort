import { Router, Response, NextFunction } from 'express';
import { Prisma } from '@prisma/client';
import { prisma } from '../utils/prisma';
import { authenticate, AuthRequest } from '../middleware/auth';
import { createError } from '../middleware/errorHandler';

const router = Router();

router.use(authenticate);

// GET /api/messages/conversations — one row per counterpart the current
// user has exchanged messages with, most-recent-first. Powers the Web
// Store "Customer communication" tool as well as the general inbox.
router.get('/conversations', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const userId = req.user!.userId;

    const messages = await prisma.message.findMany({
      where: { OR: [{ senderId: userId }, { receiverId: userId }] },
      orderBy: { createdAt: 'desc' },
      include: {
        sender:   { select: { id: true, name: true, avatar: true } },
        receiver: { select: { id: true, name: true, avatar: true } },
        listing:  { select: { id: true, title: true, images: true } },
      },
      take: 500, // bounded scan; fine for a per-user inbox
    });

    const conversations = new Map<string, {
      counterpart: { id: string; name: string; avatar: string | null };
      lastMessage: string;
      lastMessageAt: string;
      listing: { id: string; title: string; images: string[] } | null;
      unreadCount: number;
    }>();

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
        conversations.get(key)!.unreadCount += 1;
      }
    }

    res.json({ conversations: Array.from(conversations.values()) });
  } catch (err) {
    next(err);
  }
});

// GET /api/messages/thread/:userId — full message thread with one counterpart
router.get('/thread/:userId', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const me = req.user!.userId;
    const other = req.params.userId;

    const thread = await prisma.message.findMany({
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
    await prisma.message.updateMany({
      where: { senderId: other, receiverId: me, read: false },
      data: { read: true },
    });

    res.json({ messages: thread });
  } catch (err) {
    next(err);
  }
});

// POST /api/messages — send a message (buyer <-> seller/store owner)
router.post('/', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { receiverId, content, listingId } = req.body as {
      receiverId?: string; content?: string; listingId?: string;
    };
    if (!receiverId) return next(createError('receiverId is required', 400));
    if (!content || !content.trim()) return next(createError('Message content is required', 400));
    if (receiverId === req.user!.userId) return next(createError('Cannot message yourself', 400));

    const receiver = await prisma.user.findUnique({ where: { id: receiverId }, select: { id: true } });
    if (!receiver) return next(createError('Recipient not found', 404));

    const message = await prisma.message.create({
      data: {
        senderId:   req.user!.userId,
        receiverId,
        content:    content.trim(),
        listingId:  listingId || null,
      },
      include: { listing: { select: { id: true, title: true, images: true } } },
    });

    await prisma.notification.create({
      data: {
        userId:  receiverId,
        type:    'MESSAGE_RECEIVED',
        title:   'New message',
        message: content.trim().slice(0, 140),
        data:    { senderId: req.user!.userId, listingId: listingId || null } as Prisma.InputJsonValue,
      },
    }).catch(() => { /* notification is best-effort */ });

    res.status(201).json({ message });
  } catch (err) {
    next(err);
  }
});

// PUT /api/messages/:id/read — mark a single message read
router.put('/:id/read', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const message = await prisma.message.findUnique({ where: { id: req.params.id } });
    if (!message) return next(createError('Message not found', 404));
    if (message.receiverId !== req.user!.userId) return next(createError('Forbidden', 403));

    const updated = await prisma.message.update({ where: { id: req.params.id }, data: { read: true } });
    res.json({ message: updated });
  } catch (err) {
    next(err);
  }
});

export default router;
