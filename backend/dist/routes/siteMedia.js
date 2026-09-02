"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const prisma_1 = require("../utils/prisma");
const router = (0, express_1.Router)();
/**
 * GET /api/site-media?section=hero
 * Public endpoint: returns active site media items for a given page section.
 * Used by the frontend home page to populate dynamic hero slides, banners, etc.
 */
router.get('/', async (req, res, next) => {
    try {
        const section = req.query.section;
        const where = { isActive: true };
        if (section)
            where.section = section;
        const media = await prisma_1.prisma.siteMedia.findMany({
            where,
            orderBy: [{ section: 'asc' }, { sortOrder: 'asc' }, { createdAt: 'desc' }],
            select: {
                id: true,
                section: true,
                cdnUrl: true,
                title: true,
                shortDescription: true,
                price: true,
                originalPrice: true,
                currency: true,
                altText: true,
                linkUrl: true,
                sortOrder: true,
            },
        });
        res.json({ media });
    }
    catch (err) {
        next(err);
    }
});
/**
 * GET /api/site-media/social-links
 * Public endpoint: returns admin-configured social media links for the footer.
 */
router.get('/social-links', async (_req, res, next) => {
    try {
        const links = await prisma_1.prisma.socialLinks.findUnique({ where: { id: 'global' } });
        res.json(links || { facebook: null, instagram: null, linkedin: null, x: null, whatsapp: null, youtube: null, tiktok: null });
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=siteMedia.js.map