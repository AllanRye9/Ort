import { Router, Response, NextFunction } from 'express';
import { prisma } from '../utils/prisma';
import { authenticate, AuthRequest } from '../middleware/auth';
import { createError } from '../middleware/errorHandler';

const router = Router();

router.use(authenticate);

// GET /api/addresses — list user's saved addresses
router.get('/', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const addresses = await prisma.address.findMany({
      where: { userId: req.user!.userId },
      orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
    });
    res.json({ addresses });
  } catch (err) {
    next(err);
  }
});

// POST /api/addresses — create a new address
router.post('/', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { type, fullName, phone, line1, line2, city, state, postalCode, country, isDefault } = req.body;

    if (!fullName || !phone || !line1 || !city || !country) {
      return next(createError('Missing required address fields', 400));
    }

    // If setting as default, clear existing defaults
    if (isDefault) {
      await prisma.address.updateMany({
        where: { userId: req.user!.userId },
        data: { isDefault: false },
      });
    }

    const address = await prisma.address.create({
      data: {
        userId: req.user!.userId,
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
  } catch (err) {
    next(err);
  }
});

// PUT /api/addresses/:id — update an address
router.put('/:id', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const existing = await prisma.address.findUnique({ where: { id: req.params.id } });
    if (!existing || existing.userId !== req.user!.userId) {
      return next(createError('Address not found', 404));
    }

    const { type, fullName, phone, line1, line2, city, state, postalCode, country, isDefault } = req.body;

    if (isDefault) {
      await prisma.address.updateMany({
        where: { userId: req.user!.userId, id: { not: req.params.id } },
        data: { isDefault: false },
      });
    }

    const address = await prisma.address.update({
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
  } catch (err) {
    next(err);
  }
});

// DELETE /api/addresses/:id — delete an address
router.delete('/:id', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const existing = await prisma.address.findUnique({ where: { id: req.params.id } });
    if (!existing || existing.userId !== req.user!.userId) {
      return next(createError('Address not found', 404));
    }
    await prisma.address.delete({ where: { id: req.params.id } });
    res.json({ message: 'Address deleted' });
  } catch (err) {
    next(err);
  }
});

export default router;
