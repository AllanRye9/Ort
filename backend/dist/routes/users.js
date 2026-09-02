"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const prisma_1 = require("../utils/prisma");
const auth_1 = require("../middleware/auth");
const errorHandler_1 = require("../middleware/errorHandler");
const userSchema_1 = require("../utils/userSchema");
const logger_1 = require("../utils/logger");
const router = (0, express_1.Router)();
router.get('/me', auth_1.authenticate, async (req, res, next) => {
    try {
        const includePersonalId = await (0, userSchema_1.hasUserPersonalIdColumn)();
        const user = await prisma_1.prisma.user.findUnique({
            where: { id: req.user.userId },
            select: (0, userSchema_1.buildCurrentUserSelect)(includePersonalId),
        });
        if (!user)
            return next((0, errorHandler_1.createError)('User not found', 404));
        res.json(user);
    }
    catch (err) {
        next(err);
    }
});
router.put('/me', auth_1.authenticate, async (req, res, next) => {
    try {
        const includePersonalId = await (0, userSchema_1.hasUserPersonalIdColumn)();
        const { name, phone, avatar, country, cvThemeColor, companyName, registrationNumber, agentLicense, agentType, website, businessDescription, socialLinks, } = req.body;
        const data = {};
        if (name)
            data.name = name;
        if (phone !== undefined)
            data.phone = phone === '' ? null : phone;
        if (country)
            data.country = country;
        if (avatar !== undefined)
            data.avatar = avatar === '' ? null : avatar;
        if (cvThemeColor !== undefined)
            data.cvThemeColor = cvThemeColor === '' ? null : cvThemeColor;
        if (companyName !== undefined)
            data.companyName = companyName === '' ? null : companyName;
        if (registrationNumber !== undefined)
            data.registrationNumber = registrationNumber === '' ? null : registrationNumber;
        if (agentLicense !== undefined)
            data.agentLicense = agentLicense === '' ? null : agentLicense;
        if (agentType !== undefined)
            data.agentType = agentType === '' ? null : agentType;
        if (website !== undefined)
            data.website = website === '' ? null : website;
        if (businessDescription !== undefined)
            data.businessDescription = businessDescription === '' ? null : businessDescription;
        if (socialLinks !== undefined)
            data.socialLinks = socialLinks;
        const user = await prisma_1.prisma.user.update({
            where: { id: req.user.userId },
            data,
            select: (0, userSchema_1.buildCurrentUserSelect)(includePersonalId),
        });
        res.json(user);
    }
    catch (err) {
        next(err);
    }
});
router.get('/favorites', auth_1.authenticate, async (req, res, next) => {
    try {
        const now = new Date();
        const favorites = await prisma_1.prisma.favorite.findMany({
            where: { userId: req.user.userId },
            include: {
                listing: {
                    include: { category: true, user: { select: { id: true, name: true, avatar: true } } },
                },
            },
            orderBy: { createdAt: 'desc' },
        });
        // Separate valid from stale favorites
        const staleIds = [];
        const activeListings = [];
        for (const f of favorites) {
            const listing = f.listing;
            const isAvailable = listing !== null &&
                listing.status === 'ACTIVE' &&
                (listing.expiresAt === null || listing.expiresAt > now);
            if (isAvailable) {
                activeListings.push(listing);
            }
            else {
                staleIds.push(f.id);
            }
        }
        // Clean up stale favorites in the background (don't await to avoid slowing the response)
        if (staleIds.length > 0) {
            void prisma_1.prisma.favorite
                .deleteMany({ where: { id: { in: staleIds } } })
                .catch((err) => logger_1.logger.warn(`Failed to clean up stale favorites: ${String(err)}`));
        }
        res.json(activeListings);
    }
    catch (err) {
        next(err);
    }
});
router.get('/:id/reviews', async (req, res, next) => {
    try {
        const reviews = await prisma_1.prisma.review.findMany({
            where: { revieweeId: req.params.id },
            include: { reviewer: { select: { id: true, name: true, avatar: true } } },
            orderBy: { createdAt: 'desc' },
        });
        res.json(reviews);
    }
    catch (err) {
        next(err);
    }
});
// GET /users/candidate/:id — authenticated CV profile for the job market
router.get('/candidate/:id', auth_1.authenticate, async (req, res, next) => {
    try {
        const candidate = await prisma_1.prisma.user.findUnique({
            where: { id: req.params.id },
            select: {
                id: true,
                name: true,
                avatar: true,
                country: true,
                cvThemeColor: true,
                createdAt: true,
                documents: {
                    where: { isPublic: true },
                    orderBy: { createdAt: 'desc' },
                },
            },
        });
        if (!candidate)
            return next((0, errorHandler_1.createError)('Candidate not found', 404));
        // Only return candidates who have at least one public document
        if (candidate.documents.length === 0)
            return next((0, errorHandler_1.createError)('Candidate not found', 404));
        res.json({ candidate });
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=users.js.map