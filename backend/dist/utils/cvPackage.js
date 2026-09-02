"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getActiveCvPackage = getActiveCvPackage;
exports.countGenerationsForOwner = countGenerationsForOwner;
exports.resolveCvCheckoutContext = resolveCvCheckoutContext;
/**
 * CV Package resolution & rule enforcement
 * ─────────────────────────────────────────────────────────────────────────
 * The CV builder (cv-generator/builder) does not let sellers subscribe —
 * instead, at any given moment there is at most ONE active CV-scope
 * SellerPackage that governs pricing and limits for every visitor:
 *
 *  - When an admin creates (or activates) a CV package, it overwrites —
 *    i.e. supersedes — whichever CV package was previously governing the
 *    builder (enforced in routes/admin.ts by deactivating older ones).
 *  - There is no hardcoded fallback price. When the admin removes or
 *    deactivates every CV package, pricing is simply unavailable — the
 *    builder disables the download button until the admin activates a
 *    package again.
 *  - A package's `durationDays` is its validity window counted from its
 *    createdAt date. Once that window elapses the package stops applying
 *    (even if it's still marked active) and pricing again becomes
 *    unavailable until the admin creates a fresh package.
 *  - A package's `maxListings` field doubles, for CV-scope packages, as
 *    the maximum number of CVs a given user/device may generate under it.
 *    `null` means unlimited.
 */
const prisma_1 = require("./prisma");
/**
 * Returns the single CV package currently governing the builder, or null if
 * none is active / the active one's duration window has elapsed (in which
 * case pricing is unavailable and callers must not charge or display any
 * price).
 */
async function getActiveCvPackage() {
    const pkg = await prisma_1.prisma.sellerPackage.findFirst({
        where: { scope: 'CV', isActive: true },
        orderBy: { createdAt: 'desc' },
    });
    if (!pkg)
        return null;
    const expiresAt = new Date(pkg.createdAt);
    expiresAt.setDate(expiresAt.getDate() + pkg.durationDays);
    if (expiresAt.getTime() < Date.now())
        return null;
    return pkg;
}
/**
 * Counts how many CVs this user (or, for guests, this device) has already
 * generated under the given package. Only tokens that were actually used
 * to complete a download (usedAt set) count towards the limit.
 */
async function countGenerationsForOwner(packageId, userId, deviceId) {
    if (!userId && !deviceId)
        return 0;
    const ownerFilters = [
        userId ? { userId } : null,
        deviceId ? { deviceId } : null,
    ].filter(Boolean);
    if (ownerFilters.length === 0)
        return 0;
    return prisma_1.prisma.cvDownloadToken.count({
        where: {
            packageId,
            usedAt: { not: null },
            OR: ownerFilters,
        },
    });
}
/**
 * Resolves everything the frontend needs to render the correct download
 * button + payment flow, and to gate downloads once a package's rules
 * (max generations, duration) have been exhausted. Every price here comes
 * exclusively from the active CV package — there is no hardcoded fallback.
 * When no package is active, `configured` is false and `price` is null;
 * the frontend must disable downloads in that state rather than invent
 * a number.
 */
async function resolveCvCheckoutContext(opts) {
    const pkg = await getActiveCvPackage();
    if (!pkg) {
        return {
            configured: false,
            package: null,
            isFree: false,
            price: null,
            limit: null,
            used: 0,
            limitReached: false,
        };
    }
    const used = await countGenerationsForOwner(pkg.id, opts.userId, opts.deviceId);
    const limit = pkg.maxListings ?? null;
    const limitReached = limit != null && used >= limit;
    return {
        configured: true,
        package: {
            id: pkg.id,
            name: pkg.name,
            description: pkg.description,
            isFree: pkg.isFree,
            price: pkg.price,
            currency: pkg.currency,
            durationDays: pkg.durationDays,
            maxListings: pkg.maxListings,
            createdAt: pkg.createdAt,
        },
        isFree: pkg.isFree,
        price: pkg.isFree ? { amount: 0, currency: pkg.currency } : { amount: pkg.price, currency: pkg.currency },
        limit,
        used,
        limitReached,
    };
}
//# sourceMappingURL=cvPackage.js.map