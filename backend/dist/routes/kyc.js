"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const prisma_1 = require("../utils/prisma");
const auth_1 = require("../middleware/auth");
const errorHandler_1 = require("../middleware/errorHandler");
const router = (0, express_1.Router)();
const VALID_DOCUMENT_TYPES = [
    'NATIONAL_ID',
    'PASSPORT',
    'DRIVERS_LICENSE',
    'BUSINESS_LICENSE',
];
// Document types that require both a front and a back upload. Everything
// else (passport identity page, business licence) is a single document —
// see Doc 2 §4 / Doc 1 Cluster 4: "require only the passport's
// identity/information page... do not require a back-side upload."
const TWO_SIDED_DOCUMENT_TYPES = ['NATIONAL_ID', 'DRIVERS_LICENSE'];
/**
 * GET /api/kyc/status
 * Authenticated — returns the current user's own KYC state so the frontend
 * can show "not started / pending review / approved / rejected" UI.
 */
router.get('/status', auth_1.authenticate, async (req, res, next) => {
    try {
        const user = await prisma_1.prisma.user.findUnique({
            where: { id: req.user.userId },
            select: {
                kycStatus: true,
                kycDocumentType: true,
                kycDocumentUrl: true,
                kycDocumentBackUrl: true,
                kycSelfieUrl: true,
                kycFullName: true,
                kycSubmittedAt: true,
                kycReviewedAt: true,
                kycRejectionReason: true,
            },
        });
        if (!user)
            return next((0, errorHandler_1.createError)('User not found', 404));
        res.json(user);
    }
    catch (err) {
        next(err);
    }
});
/**
 * GET /api/kyc/draft
 * Authenticated — returns the current user's in-progress (not yet
 * submitted) verification draft, if any, so the frontend can restore the
 * form after a refresh, closed tab, dropped connection, or navigation away
 * mid-flow. Draft documents were already uploaded server-side via
 * POST /api/upload/kyc-document when originally selected (see PUT
 * /api/kyc/draft below), so this never has to touch browser storage.
 */
router.get('/draft', auth_1.authenticate, async (req, res, next) => {
    try {
        const user = await prisma_1.prisma.user.findUnique({
            where: { id: req.user.userId },
            select: {
                kycDraftDocumentType: true,
                kycDraftFullName: true,
                kycDraftDocumentUrl: true,
                kycDraftDocumentBackUrl: true,
                kycDraftSelfieUrl: true,
                kycDraftUpdatedAt: true,
            },
        });
        if (!user)
            return next((0, errorHandler_1.createError)('User not found', 404));
        res.json(user);
    }
    catch (err) {
        next(err);
    }
});
/**
 * PUT /api/kyc/draft
 * Authenticated — upserts the in-progress verification draft. Called
 * whenever the user changes the document type / full name, or right after
 * a document image finishes uploading, so partial progress is never lost.
 * Every field is optional and only provided fields are updated, so the
 * frontend can save each change (e.g. just a new documentUrl) independently
 * without having to resend the whole form.
 */
router.put('/draft', auth_1.authenticate, async (req, res, next) => {
    try {
        const { documentType, fullName, documentUrl, documentBackUrl, selfieUrl } = req.body;
        if (documentType !== undefined && documentType !== null && !VALID_DOCUMENT_TYPES.includes(documentType)) {
            return next((0, errorHandler_1.createError)(`documentType must be one of: ${VALID_DOCUMENT_TYPES.join(', ')}`, 400));
        }
        const data = { kycDraftUpdatedAt: new Date() };
        if (documentType !== undefined)
            data.kycDraftDocumentType = documentType || null;
        if (fullName !== undefined)
            data.kycDraftFullName = typeof fullName === 'string' ? fullName.slice(0, 200) : null;
        if (documentUrl !== undefined)
            data.kycDraftDocumentUrl = documentUrl || null;
        if (documentBackUrl !== undefined)
            data.kycDraftDocumentBackUrl = documentBackUrl || null;
        if (selfieUrl !== undefined)
            data.kycDraftSelfieUrl = selfieUrl || null;
        const user = await prisma_1.prisma.user.update({
            where: { id: req.user.userId },
            data,
            select: {
                kycDraftDocumentType: true,
                kycDraftFullName: true,
                kycDraftDocumentUrl: true,
                kycDraftDocumentBackUrl: true,
                kycDraftSelfieUrl: true,
                kycDraftUpdatedAt: true,
            },
        });
        res.json(user);
    }
    catch (err) {
        next(err);
    }
});
/**
 * DELETE /api/kyc/draft
 * Authenticated — discards the in-progress draft (e.g. the user manually
 * clears the form, or switches document type in a way that invalidates
 * prior uploads). POST /kyc/submit also clears the draft automatically on
 * a successful submission.
 */
router.delete('/draft', auth_1.authenticate, async (req, res, next) => {
    try {
        await prisma_1.prisma.user.update({
            where: { id: req.user.userId },
            data: {
                kycDraftDocumentType: null,
                kycDraftFullName: null,
                kycDraftDocumentUrl: null,
                kycDraftDocumentBackUrl: null,
                kycDraftSelfieUrl: null,
                kycDraftUpdatedAt: null,
            },
        });
        res.status(204).end();
    }
    catch (err) {
        next(err);
    }
});
/**
 * POST /api/kyc/submit
 * Authenticated — submit (or resubmit after a rejection) identity documents
 * for review. Document/selfie files must already be uploaded via
 * POST /api/upload and their returned CDN URLs passed here.
 *
 * documentBackUrl is required for two-sided document types (national ID,
 * driver's licence) and rejected for single-sided ones (passport, business
 * licence) — the requirement is driven entirely by documentType, so the
 * frontend can't submit a mismatched pair by mistake.
 */
router.post('/submit', auth_1.authenticate, async (req, res, next) => {
    try {
        const { documentType, documentUrl, documentBackUrl, selfieUrl, fullName } = req.body;
        if (!documentType || !VALID_DOCUMENT_TYPES.includes(documentType)) {
            return next((0, errorHandler_1.createError)(`documentType must be one of: ${VALID_DOCUMENT_TYPES.join(', ')}`, 400));
        }
        if (!documentUrl || typeof documentUrl !== 'string') {
            return next((0, errorHandler_1.createError)('documentUrl is required — upload the document via /api/upload first', 400));
        }
        if (!fullName || typeof fullName !== 'string' || fullName.trim().length < 2) {
            return next((0, errorHandler_1.createError)('fullName is required', 400));
        }
        const requiresBack = TWO_SIDED_DOCUMENT_TYPES.includes(documentType);
        if (requiresBack && (!documentBackUrl || typeof documentBackUrl !== 'string')) {
            return next((0, errorHandler_1.createError)('Please upload the back of your ID.', 400));
        }
        // For single-sided types (passport, business licence) any stray
        // documentBackUrl left over from switching document types is simply
        // discarded below rather than validated against.
        const existing = await prisma_1.prisma.user.findUnique({
            where: { id: req.user.userId },
            select: { kycStatus: true },
        });
        if (existing?.kycStatus === 'PENDING') {
            return next((0, errorHandler_1.createError)('Your KYC submission is already pending review', 409));
        }
        if (existing?.kycStatus === 'APPROVED') {
            return next((0, errorHandler_1.createError)('You are already a KYC-verified seller', 409));
        }
        const user = await prisma_1.prisma.user.update({
            where: { id: req.user.userId },
            data: {
                kycStatus: 'PENDING',
                kycDocumentType: documentType,
                kycDocumentUrl: documentUrl,
                kycDocumentBackUrl: requiresBack ? documentBackUrl : null,
                kycSelfieUrl: selfieUrl || null,
                kycFullName: fullName.trim(),
                kycSubmittedAt: new Date(),
                kycReviewedAt: null,
                kycReviewedBy: null,
                kycRejectionReason: null,
                // A successful submission promotes the draft to a real submission,
                // so the draft itself is no longer needed — clear it rather than
                // leaving stale in-progress data behind.
                kycDraftDocumentType: null,
                kycDraftFullName: null,
                kycDraftDocumentUrl: null,
                kycDraftDocumentBackUrl: null,
                kycDraftSelfieUrl: null,
                kycDraftUpdatedAt: null,
            },
            select: {
                kycStatus: true,
                kycDocumentType: true,
                kycSubmittedAt: true,
            },
        });
        res.status(201).json(user);
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=kyc.js.map