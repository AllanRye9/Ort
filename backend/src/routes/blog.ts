import { Router, Request, Response, NextFunction } from 'express';
import { prisma } from '../utils/prisma';
import { authenticate, authorize, AuthRequest } from '../middleware/auth';
import { createError } from '../middleware/errorHandler';

const router = Router();

// ─── Public routes ─────────────────────────────────────────────────────────────

// GET /api/blog — list published posts (paginated)
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const page = Math.max(1, parseInt(req.query.page as string || '1'));
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit as string || '10')));
    const skip = (page - 1) * limit;

    const [posts, total] = await Promise.all([
      prisma.blogPost.findMany({
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
      prisma.blogPost.count({ where: { status: 'PUBLISHED' } }),
    ]);

    res.json({ posts, total, page, limit, pages: Math.ceil(total / limit) });
  } catch (err) {
    next(err);
  }
});

// GET /api/blog/:slug — get a single published post
router.get('/:slug', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const post = await prisma.blogPost.findFirst({
      where: { slug: req.params.slug, status: 'PUBLISHED' },
      include: { author: { select: { id: true, name: true, avatar: true } } },
    });

    if (!post) return next(createError('Post not found', 404));
    res.json({ post });
  } catch (err) {
    next(err);
  }
});

// ─── Admin routes ──────────────────────────────────────────────────────────────

// GET /api/blog/admin/all — list all posts (draft + published)
router.get('/admin/all', authenticate, authorize('ADMIN'), async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const posts = await prisma.blogPost.findMany({
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
  } catch (err) {
    next(err);
  }
});

// GET /api/blog/admin/:id — get a single post by id (admin)
router.get('/admin/:id', authenticate, authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const post = await prisma.blogPost.findUnique({ where: { id: req.params.id } });
    if (!post) return next(createError('Post not found', 404));
    res.json({ post });
  } catch (err) {
    next(err);
  }
});

// POST /api/blog — create a new post
router.post('/', authenticate, authorize('ADMIN'), async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { title, slug, content, excerpt, featuredImage, status } = req.body;
    if (!title || !slug || !content) {
      return next(createError('title, slug, and content are required', 400));
    }

    const existing = await prisma.blogPost.findUnique({ where: { slug } });
    if (existing) return next(createError('A post with this slug already exists', 400));

    const post = await prisma.blogPost.create({
      data: {
        title,
        slug: slug.toLowerCase().replace(/[^a-z0-9-]/g, '-'),
        content,
        excerpt: excerpt || null,
        featuredImage: featuredImage || null,
        status: status === 'PUBLISHED' ? 'PUBLISHED' : 'DRAFT',
        publishedAt: status === 'PUBLISHED' ? new Date() : null,
        authorId: req.user!.userId,
      },
    });

    res.status(201).json({ post });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/blog/:id — update a post
router.patch('/:id', authenticate, authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { title, slug, content, excerpt, featuredImage, status } = req.body;

    const existing = await prisma.blogPost.findUnique({ where: { id: req.params.id } });
    if (!existing) return next(createError('Post not found', 404));

    const wasPublished = existing.status === 'PUBLISHED';
    const nowPublished = status === 'PUBLISHED';

    const post = await prisma.blogPost.update({
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
  } catch (err) {
    next(err);
  }
});

// DELETE /api/blog/:id — delete a post
router.delete('/:id', authenticate, authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const existing = await prisma.blogPost.findUnique({ where: { id: req.params.id } });
    if (!existing) return next(createError('Post not found', 404));

    await prisma.blogPost.delete({ where: { id: req.params.id } });
    res.json({ message: 'Post deleted' });
  } catch (err) {
    next(err);
  }
});

export default router;
