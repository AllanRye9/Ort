import { Router, Response, NextFunction } from 'express';
import { KycDocumentType } from '@prisma/client';
import { prisma } from '../utils/prisma';
import { authenticate, AuthRequest } from '../middleware/auth';
import { createError } from '../middleware/errorHandler';

const router = Router();

const VALID_DOCUMENT_TYPES: KycDocumentType[] = [
  'NATIONAL_ID',
  'PASSPORT',
  'DRIVERS_LICENSE',
  'BUSINESS_LICENSE',
];

/**
 * GET /api/kyc/status
 * Authenticated — returns the current user's own KYC state so the frontend
 * can show "not started / pending review / approved / rejected" UI.
 */
router.get('/status', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.userId },
      select: {
        kycStatus: true,
        kycDocumentType: true,
        kycDocumentUrl: true,
        kycSelfieUrl: true,
        kycFullName: true,
        kycSubmittedAt: true,
        kycReviewedAt: true,
        kycRejectionReason: true,
      },
    });
    if (!user) return next(createError('User not found', 404));
    res.json(user);
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/kyc/submit
 * Authenticated — submit (or resubmit after a rejection) identity documents
 * for review. Document/selfie files must already be uploaded via
 * POST /api/upload and their returned CDN URLs passed here.
 */
router.post('/submit', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { documentType, documentUrl, selfieUrl, fullName } = req.body;

    if (!documentType || !VALID_DOCUMENT_TYPES.includes(documentType)) {
      return next(createError(`documentType must be one of: ${VALID_DOCUMENT_TYPES.join(', ')}`, 400));
    }
    if (!documentUrl || typeof documentUrl !== 'string') {
      return next(createError('documentUrl is required — upload the document via /api/upload first', 400));
    }
    if (!fullName || typeof fullName !== 'string' || fullName.trim().length < 2) {
      return next(createError('fullName is required', 400));
    }

    const existing = await prisma.user.findUnique({
      where: { id: req.user!.userId },
      select: { kycStatus: true },
    });
    if (existing?.kycStatus === 'PENDING') {
      return next(createError('Your KYC submission is already pending review', 409));
    }
    if (existing?.kycStatus === 'APPROVED') {
      return next(createError('You are already a KYC-verified seller', 409));
    }

    const user = await prisma.user.update({
      where: { id: req.user!.userId },
      data: {
        kycStatus: 'PENDING',
        kycDocumentType: documentType,
        kycDocumentUrl: documentUrl,
        kycSelfieUrl: selfieUrl || null,
        kycFullName: fullName.trim(),
        kycSubmittedAt: new Date(),
        kycReviewedAt: null,
        kycReviewedBy: null,
        kycRejectionReason: null,
      },
      select: {
        kycStatus: true,
        kycDocumentType: true,
        kycSubmittedAt: true,
      },
    });

    res.status(201).json(user);
  } catch (err) {
    next(err);
  }
});

export default router;
