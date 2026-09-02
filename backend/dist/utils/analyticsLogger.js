"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.recordSearchLog = recordSearchLog;
exports.recordListingClick = recordListingClick;
const prisma_1 = require("./prisma");
const requestMeta_1 = require("./requestMeta");
/**
 * Resolves the phone number to snapshot onto a log row for a signed-in
 * user. Email/userId already come from the JWT payload (no DB hit needed);
 * phone isn't carried in the token, so this is the one extra lookup —
 * skipped entirely for anonymous requests.
 */
async function resolveUserPhone(userId) {
    if (!userId)
        return null;
    const user = await prisma_1.prisma.user.findUnique({ where: { id: userId }, select: { phone: true } });
    return user?.phone ?? null;
}
/**
 * Records one search event (SearchLog). Callers should invoke this without
 * `await` (fire-and-forget, `.catch(err => logger.error(...))`) so a
 * logging failure or slow write never delays or breaks the actual search
 * response — see the call sites in routes/listings.ts.
 */
async function recordSearchLog(req, params) {
    const geo = (0, requestMeta_1.getRequestGeo)(req);
    const userPhone = await resolveUserPhone(req.user?.userId);
    await prisma_1.prisma.searchLog.create({
        data: {
            query: params.query,
            context: JSON.stringify(params.context),
            resultCount: params.resultCount,
            userId: req.user?.userId ?? null,
            userEmail: req.user?.email ?? null,
            userPhone,
            ip: (0, requestMeta_1.getClientIp)(req),
            ipCountry: (0, requestMeta_1.getIpCountry)(req) ?? null,
            latitude: geo.latitude,
            longitude: geo.longitude,
            locationAccuracy: geo.accuracy,
            userAgent: req.headers['user-agent'] ?? null,
        },
    });
}
/**
 * Records one "item clicked" event (ListingClickLog) for a listing detail
 * view. `listingTitle`/`listingImage` are snapshotted at click time so the
 * "most clicked items" report keeps a title and image preview even if the
 * listing is later edited or deleted. Fire-and-forget — see recordSearchLog
 * above.
 */
async function recordListingClick(req, listing) {
    const geo = (0, requestMeta_1.getRequestGeo)(req);
    const userPhone = await resolveUserPhone(req.user?.userId);
    // Same "best available image" resolution the frontend uses for listing
    // cards (see frontend/components/listings/ListingCard.tsx): prefer an
    // approved product image, fall back to the legacy `images[0]`.
    const primaryImage = listing.productImages?.find((img) => img.cdnUrl)?.cdnUrl ??
        listing.images?.[0] ??
        null;
    await prisma_1.prisma.listingClickLog.create({
        data: {
            listingId: listing.id,
            listingTitle: listing.title,
            listingImage: primaryImage,
            userId: req.user?.userId ?? null,
            userEmail: req.user?.email ?? null,
            userPhone,
            ip: (0, requestMeta_1.getClientIp)(req),
            ipCountry: (0, requestMeta_1.getIpCountry)(req) ?? null,
            latitude: geo.latitude,
            longitude: geo.longitude,
            locationAccuracy: geo.accuracy,
            userAgent: req.headers['user-agent'] ?? null,
        },
    });
}
//# sourceMappingURL=analyticsLogger.js.map