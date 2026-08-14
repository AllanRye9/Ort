import { Router, Response, NextFunction } from 'express';
import { prisma } from '../utils/prisma';
import { authenticate, AuthRequest } from '../middleware/auth';
import { createError } from '../middleware/errorHandler';

const router = Router();

router.use(authenticate);

const EXCLUDED_NOTIFICATION_TYPES = ['MESSAGE_RECEIVED'] as const;

// GET /api/notifications — list current user's notifications
router.get('/', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { page = '1', limit = '30', unreadOnly } = req.query as Record<string, string>;
    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
    const skip = (pageNum - 1) * limitNum;

    const where = {
      userId: req.user!.userId,
      type: { notIn: [...EXCLUDED_NOTIFICATION_TYPES] },
      ...(unreadOnly === 'true' && { read: false }),
    };

    const [notifications, total, unreadCount] = await Promise.all([
      prisma.notification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limitNum,
      }),
      prisma.notification.count({ where }),
      prisma.notification.count({ where: { userId: req.user!.userId, read: false, type: { notIn: [...EXCLUDED_NOTIFICATION_TYPES] } } }),
    ]);

    res.json({ notifications, total, unreadCount, page: pageNum, limit: limitNum });
  } catch (err) {
    next(err);
  }
});

// GET /api/notifications/unread-count
router.get('/unread-count', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
      const count = await prisma.notification.count({
      where: { userId: req.user!.userId, read: false, type: { notIn: [...EXCLUDED_NOTIFICATION_TYPES] } },
      });
    res.json({ count });
  } catch (err) {
    next(err);
  }
});

// PUT /api/notifications/:id/read — mark a notification as read
router.put('/:id/read', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const notif = await prisma.notification.findUnique({ where: { id: req.params.id } });
    if (!notif || notif.userId !== req.user!.userId) {
      return next(createError('Notification not found', 404));
    }
    const updated = await prisma.notification.update({
      where: { id: req.params.id },
      data: { read: true },
    });
    res.json({ notification: updated });
  } catch (err) {
    next(err);
  }
});

// PUT /api/notifications/read-all — mark all notifications as read
router.put('/read-all', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    await prisma.notification.updateMany({
      where: { userId: req.user!.userId, read: false, type: { notIn: [...EXCLUDED_NOTIFICATION_TYPES] } },
      data: { read: true },
    });
    res.json({ message: 'All notifications marked as read' });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/notifications/:id
router.delete('/:id', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const notif = await prisma.notification.findUnique({ where: { id: req.params.id } });
    if (!notif || notif.userId !== req.user!.userId) {
      return next(createError('Notification not found', 404));
    }
    await prisma.notification.delete({ where: { id: req.params.id } });
    res.json({ message: 'Notification deleted' });
  } catch (err) {
    next(err);
  }
});

export default router;
