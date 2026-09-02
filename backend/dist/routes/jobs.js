"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const prisma_1 = require("../utils/prisma");
const auth_1 = require("../middleware/auth");
const errorHandler_1 = require("../middleware/errorHandler");
const router = (0, express_1.Router)();
const JOB_TYPES = ['Full-time', 'Part-time', 'Contract', 'Freelance', 'Internship', 'Temporary'];
const JOB_CATEGORIES = [
    'Technology', 'Finance', 'Healthcare', 'Education', 'Engineering',
    'Sales & Marketing', 'Admin & Support', 'Design & Creative',
    'Legal', 'Logistics & Transport', 'Hospitality', 'Construction', 'Other',
];
const QUALIFICATIONS = ["None Required", "High School", "Diploma", "Bachelor's", "Master's", "PhD", "Professional Cert"];
const COUNTRIES = ['UAE', 'UGANDA', 'KENYA', 'CHINA'];
router.get('/meta', (_req, res) => {
    res.json({
        categories: JOB_CATEGORIES,
        types: JOB_TYPES,
        qualifications: QUALIFICATIONS,
        countries: COUNTRIES,
    });
});
function normalizeEmploymentType(input) {
    if (typeof input !== 'string')
        return null;
    const value = input.trim().toLowerCase();
    if (!value)
        return null;
    const mapped = {
        'full-time': 'Full-time',
        'full time': 'Full-time',
        'part-time': 'Part-time',
        'part time': 'Part-time',
        contract: 'Contract',
        freelance: 'Freelance',
        internship: 'Internship',
        temporary: 'Temporary',
    };
    return mapped[value] ?? null;
}
// GET /api/jobs — public, filterable
router.get('/', auth_1.optionalAuthenticate, async (req, res, next) => {
    try {
        const { country, type, employmentType, category, industry, role, location, q, status, page = '1', limit = '50', } = req.query;
        const pageNum = Math.max(1, parseInt(page, 10));
        const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10)));
        const isPrivileged = req.user?.role === 'ADMIN' || req.user?.role === 'AGENT';
        const selectedType = normalizeEmploymentType(employmentType || type);
        const selectedIndustry = (industry || category || '').trim();
        const selectedRole = (role || '').trim();
        const selectedLocation = (location || '').trim();
        const statusFilter = isPrivileged ? status : 'ACTIVE';
        const where = {
            ...(statusFilter ? { status: statusFilter } : {}),
            ...(country && COUNTRIES.includes(country) && { country }),
            ...(selectedType && { type: { equals: selectedType, mode: 'insensitive' } }),
            ...(selectedIndustry && { category: { contains: selectedIndustry, mode: 'insensitive' } }),
            ...(selectedLocation && { location: { contains: selectedLocation, mode: 'insensitive' } }),
            ...(selectedRole && { title: { contains: selectedRole, mode: 'insensitive' } }),
            ...(q && {
                OR: [
                    { title: { contains: q, mode: 'insensitive' } },
                    { company: { contains: q, mode: 'insensitive' } },
                    { description: { contains: q, mode: 'insensitive' } },
                    { location: { contains: q, mode: 'insensitive' } },
                    { category: { contains: q, mode: 'insensitive' } },
                    { type: { contains: q, mode: 'insensitive' } },
                ],
            }),
        };
        const [jobs, total] = await Promise.all([
            prisma_1.prisma.jobPost.findMany({
                where,
                orderBy: { createdAt: 'desc' },
                skip: (pageNum - 1) * limitNum,
                take: limitNum,
            }),
            prisma_1.prisma.jobPost.count({ where }),
        ]);
        res.json({
            jobs,
            pagination: { total, page: pageNum, limit: limitNum, pages: Math.ceil(total / limitNum) },
        });
    }
    catch (err) {
        next(err);
    }
});
// GET /api/jobs/:id — public for active jobs
router.get('/:id', auth_1.optionalAuthenticate, async (req, res, next) => {
    try {
        const job = await prisma_1.prisma.jobPost.findUnique({ where: { id: req.params.id } });
        if (!job)
            return next((0, errorHandler_1.createError)('Job not found', 404));
        const isPrivileged = req.user?.role === 'ADMIN' || req.user?.role === 'AGENT';
        if (!isPrivileged && job.status !== 'ACTIVE')
            return next((0, errorHandler_1.createError)('Job not found', 404));
        res.json(job);
    }
    catch (err) {
        next(err);
    }
});
// POST /api/jobs — admin/agent/company/organization
router.post('/', auth_1.authenticate, async (req, res, next) => {
    try {
        const posterRole = req.user.role;
        if (!['ADMIN', 'AGENT', 'COMPANY', 'ORGANIZATION'].includes(posterRole)) {
            return next((0, errorHandler_1.createError)('Only admins, agents, companies, and organizations can post jobs', 403));
        }
        const { title, company, location, type, category, qualification, description, salary, deadline, imageUrl, country } = req.body;
        if (!title?.trim() || !company?.trim() || !description?.trim()) {
            return next((0, errorHandler_1.createError)('Title, company and description are required', 400));
        }
        const normalizedType = normalizeEmploymentType(type) || 'Full-time';
        const job = await prisma_1.prisma.jobPost.create({
            data: {
                title: title.trim(),
                company: company.trim(),
                location: location?.trim() || '',
                type: normalizedType,
                category: JOB_CATEGORIES.includes(category) ? category : 'Other',
                qualification: QUALIFICATIONS.includes(qualification) ? qualification : 'None Required',
                description: description.trim(),
                salary: salary?.trim() || null,
                deadline: deadline?.trim() || null,
                imageUrl: imageUrl?.trim() || null,
                country: COUNTRIES.includes(country) ? country : 'UAE',
                status: posterRole === 'ADMIN' ? 'ACTIVE' : 'DRAFT',
                postedById: req.user.userId,
            },
        });
        res.status(201).json({
            job,
            moderation: posterRole === 'ADMIN' ? 'published' : 'pending_approval',
            message: posterRole === 'ADMIN'
                ? 'Job published successfully.'
                : 'Job submitted successfully and is pending admin approval.',
        });
    }
    catch (err) {
        next(err);
    }
});
// PUT /api/jobs/:id — admin/agent only
router.put('/:id', auth_1.authenticate, async (req, res, next) => {
    try {
        if (req.user.role !== 'ADMIN' && req.user.role !== 'AGENT') {
            return next((0, errorHandler_1.createError)('Only admins and agents can update jobs', 403));
        }
        const existing = await prisma_1.prisma.jobPost.findUnique({ where: { id: req.params.id } });
        if (!existing)
            return next((0, errorHandler_1.createError)('Job not found', 404));
        const { title, company, location, type, category, qualification, description, salary, deadline, imageUrl, country, status } = req.body;
        const validStatuses = ['ACTIVE', 'CLOSED', 'DRAFT'];
        const normalizedType = normalizeEmploymentType(type);
        const job = await prisma_1.prisma.jobPost.update({
            where: { id: req.params.id },
            data: {
                ...(title?.trim() && { title: title.trim() }),
                ...(company?.trim() && { company: company.trim() }),
                ...(location !== undefined && { location: location?.trim() || '' }),
                ...(normalizedType && { type: normalizedType }),
                ...(category && JOB_CATEGORIES.includes(category) && { category }),
                ...(qualification && QUALIFICATIONS.includes(qualification) && { qualification }),
                ...(description?.trim() && { description: description.trim() }),
                ...('salary' in req.body && { salary: salary?.trim() || null }),
                ...('deadline' in req.body && { deadline: deadline?.trim() || null }),
                ...('imageUrl' in req.body && { imageUrl: imageUrl?.trim() || null }),
                ...(country && COUNTRIES.includes(country) && { country }),
                ...(status && validStatuses.includes(status) && { status }),
            },
        });
        res.json(job);
    }
    catch (err) {
        next(err);
    }
});
// DELETE /api/jobs/:id — admin/agent only
router.delete('/:id', auth_1.authenticate, async (req, res, next) => {
    try {
        if (req.user.role !== 'ADMIN' && req.user.role !== 'AGENT') {
            return next((0, errorHandler_1.createError)('Only admins and agents can delete jobs', 403));
        }
        const existing = await prisma_1.prisma.jobPost.findUnique({ where: { id: req.params.id } });
        if (!existing)
            return next((0, errorHandler_1.createError)('Job not found', 404));
        await prisma_1.prisma.jobPost.delete({ where: { id: req.params.id } });
        res.json({ message: 'Job deleted' });
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=jobs.js.map