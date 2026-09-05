"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const prisma_1 = require("../utils/prisma");
const auth_1 = require("../middleware/auth");
const errorHandler_1 = require("../middleware/errorHandler");
const router = (0, express_1.Router)();
// ─── Public routes ─────────────────────────────────────────────────────────────
// GET /api/blog/popup — resolved homepage popup config for the public site.
// Reads SiteConfig.blogPopup ({ enabled, intervalSeconds, postId }) and
// resolves it down to a single ready-to-render post:
//   - feature off, or no published posts exist at all → { enabled: false }
//   - a pinned postId that is still PUBLISHED → that post
//   - otherwise → the most recently published post
// Mounted before the `/:slug` route below so "popup" is never swallowed as
// a slug lookup.
router.get('/popup', async (_req, res, next) => {
    try {
        const config = await prisma_1.prisma.siteConfig.findUnique({ where: { id: 'global' } });
        const stored = config?.blogPopup || {};
        const intervalSeconds = typeof stored.intervalSeconds === 'number' && stored.intervalSeconds > 0 ? stored.intervalSeconds : 60;
        if (!stored.enabled) {
            res.json({ enabled: false });
            return;
        }
        const postSelect = {
            id: true,
            title: true,
            slug: true,
            excerpt: true,
            featuredImage: true,
            publishedAt: true,
        };
        let post = stored.postId
            ? await prisma_1.prisma.blogPost.findFirst({ where: { id: stored.postId, status: 'PUBLISHED' }, select: postSelect })
            : null;
        if (!post) {
            post = await prisma_1.prisma.blogPost.findFirst({
                where: { status: 'PUBLISHED' },
                select: postSelect,
                orderBy: { publishedAt: 'desc' },
            });
        }
        if (!post) {
            // Admin has the popup switched on but there's nothing publishable to
            // show — fail closed rather than surface an empty popup.
            res.json({ enabled: false });
            return;
        }
        res.set('Cache-Control', 'public, max-age=60, stale-while-revalidate=120');
        res.json({ enabled: true, intervalSeconds, post });
    }
    catch (err) {
        next(err);
    }
});
// GET /api/blog — list published posts (paginated)
router.get('/', async (req, res, next) => {
    try {
        const page = Math.max(1, parseInt(req.query.page || '1'));
        const limit = Math.min(50, Math.max(1, parseInt(req.query.limit || '10')));
        const skip = (page - 1) * limit;
        const [posts, total] = await Promise.all([
            prisma_1.prisma.blogPost.findMany({
                where: { status: 'PUBLISHED' },
                select: {
                    id: true,
                    title: true,
                    slug: true,
                    excerpt: true,
                    featuredImage: true,
                    publishedAt: true,
                    createdAt: true,
                    author: { select: { id: true, name: true, avatar: true } },
                },
                orderBy: { publishedAt: 'desc' },
                skip,
                take: limit,
            }),
            prisma_1.prisma.blogPost.count({ where: { status: 'PUBLISHED' } }),
        ]);
        res.json({ posts, total, page, limit, pages: Math.ceil(total / limit) });
    }
    catch (err) {
        next(err);
    }
});
// GET /api/blog/:slug — get a single published post
router.get('/:slug', async (req, res, next) => {
    try {
        const post = await prisma_1.prisma.blogPost.findFirst({
            where: { slug: req.params.slug, status: 'PUBLISHED' },
            include: { author: { select: { id: true, name: true, avatar: true } } },
        });
        if (!post)
            return next((0, errorHandler_1.createError)('Post not found', 404));
        res.json({ post });
    }
    catch (err) {
        next(err);
    }
});
// ─── Admin routes ──────────────────────────────────────────────────────────────
// GET /api/blog/admin/all — list all posts (draft + published)
router.get('/admin/all', auth_1.authenticate, (0, auth_1.authorize)('ADMIN'), async (_req, res, next) => {
    try {
        const posts = await prisma_1.prisma.blogPost.findMany({
            select: {
                id: true,
                title: true,
                slug: true,
                status: true,
                publishedAt: true,
                createdAt: true,
                author: { select: { id: true, name: true } },
            },
            orderBy: { createdAt: 'desc' },
        });
        res.json({ posts });
    }
    catch (err) {
        next(err);
    }
});
// GET /api/blog/admin/:id — get a single post by id (admin)
router.get('/admin/:id', auth_1.authenticate, (0, auth_1.authorize)('ADMIN'), async (req, res, next) => {
    try {
        const post = await prisma_1.prisma.blogPost.findUnique({ where: { id: req.params.id } });
        if (!post)
            return next((0, errorHandler_1.createError)('Post not found', 404));
        res.json({ post });
    }
    catch (err) {
        next(err);
    }
});
// POST /api/blog — create a new post
router.post('/', auth_1.authenticate, (0, auth_1.authorize)('ADMIN'), async (req, res, next) => {
    try {
        const { title, slug, content, excerpt, featuredImage, status } = req.body;
        if (!title || !slug || !content) {
            return next((0, errorHandler_1.createError)('title, slug, and content are required', 400));
        }
        const existing = await prisma_1.prisma.blogPost.findUnique({ where: { slug } });
        if (existing)
            return next((0, errorHandler_1.createError)('A post with this slug already exists', 400));
        const post = await prisma_1.prisma.blogPost.create({
            data: {
                title,
                slug: slug.toLowerCase().replace(/[^a-z0-9-]/g, '-'),
                content,
                excerpt: excerpt || null,
                featuredImage: featuredImage || null,
                status: status === 'PUBLISHED' ? 'PUBLISHED' : 'DRAFT',
                publishedAt: status === 'PUBLISHED' ? new Date() : null,
                authorId: req.user.userId,
            },
        });
        res.status(201).json({ post });
    }
    catch (err) {
        next(err);
    }
});
// PATCH /api/blog/:id — update a post
router.patch('/:id', auth_1.authenticate, (0, auth_1.authorize)('ADMIN'), async (req, res, next) => {
    try {
        const { title, slug, content, excerpt, featuredImage, status } = req.body;
        const existing = await prisma_1.prisma.blogPost.findUnique({ where: { id: req.params.id } });
        if (!existing)
            return next((0, errorHandler_1.createError)('Post not found', 404));
        const wasPublished = existing.status === 'PUBLISHED';
        const nowPublished = status === 'PUBLISHED';
        const post = await prisma_1.prisma.blogPost.update({
            where: { id: req.params.id },
            data: {
                ...(title && { title }),
                ...(slug && { slug: slug.toLowerCase().replace(/[^a-z0-9-]/g, '-') }),
                ...(content !== undefined && { content }),
                ...(excerpt !== undefined && { excerpt: excerpt || null }),
                ...(featuredImage !== undefined && { featuredImage: featuredImage || null }),
                ...(status && { status: nowPublished ? 'PUBLISHED' : 'DRAFT' }),
                ...(!wasPublished && nowPublished ? { publishedAt: new Date() } : {}),
            },
        });
        res.json({ post });
    }
    catch (err) {
        next(err);
    }
});
// DELETE /api/blog/:id — delete a post
router.delete('/:id', auth_1.authenticate, (0, auth_1.authorize)('ADMIN'), async (req, res, next) => {
    try {
        const existing = await prisma_1.prisma.blogPost.findUnique({ where: { id: req.params.id } });
        if (!existing)
            return next((0, errorHandler_1.createError)('Post not found', 404));
        await prisma_1.prisma.blogPost.delete({ where: { id: req.params.id } });
        res.json({ message: 'Post deleted' });
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=blog.js.map