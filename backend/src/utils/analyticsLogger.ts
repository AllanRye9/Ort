import { prisma } from './prisma';
import { AuthRequest } from '../middleware/auth';
import { getClientIp, getIpCountry, getRequestGeo } from './requestMeta';

/**
 * Resolves the phone number to snapshot onto a log row for a signed-in
 * user. Email/userId already come from the JWT payload (no DB hit needed);
 * phone isn't carried in the token, so this is the one extra lookup —
 * skipped entirely for anonymous requests.
 */
async function resolveUserPhone(userId: string | undefined): Promise<string | null> {
  if (!userId) return null;
  const user = await prisma.user.findUnique({ where: { id: userId }, select: { phone: true } });
  return user?.phone ?? null;
}

/**
 * Records one search event (SearchLog). Callers should invoke this without
 * `await` (fire-and-forget, `.catch(err => logger.error(...))`) so a
 * logging failure or slow write never delays or breaks the actual search
 * response — see the call sites in routes/listings.ts.
 */
export async function recordSearchLog(
  req: AuthRequest,
  params: { query: string | null; context: Record<string, unknown>; resultCount: number },
): Promise<void> {
  const geo = getRequestGeo(req);
  const userPhone = await resolveUserPhone(req.user?.userId);

  await prisma.searchLog.create({
    data: {
      query: params.query,
      context: JSON.stringify(params.context),
      resultCount: params.resultCount,
      userId: req.user?.userId ?? null,
      userEmail: req.user?.email ?? null,
      userPhone,
      ip: getClientIp(req),
      ipCountry: getIpCountry(req) ?? null,
      latitude: geo.latitude,
      longitude: geo.longitude,
      locationAccuracy: geo.accuracy,
      userAgent: (req.headers['user-agent'] as string | undefined) ?? null,
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
export async function recordListingClick(
  req: AuthRequest,
  listing: {
    id: string;
    title: string;
    images: string[];
    productImages?: { cdnUrl: string | null }[];
  },
): Promise<void> {
  const geo = getRequestGeo(req);
  const userPhone = await resolveUserPhone(req.user?.userId);

  // Same "best available image" resolution the frontend uses for listing
  // cards (see frontend/components/listings/ListingCard.tsx): prefer an
  // approved product image, fall back to the legacy `images[0]`.
  const primaryImage =
    listing.productImages?.find((img) => img.cdnUrl)?.cdnUrl ??
    listing.images?.[0] ??
    null;

  await prisma.listingClickLog.create({
    data: {
      listingId: listing.id,
      listingTitle: listing.title,
      listingImage: primaryImage,
      userId: req.user?.userId ?? null,
      userEmail: req.user?.email ?? null,
      userPhone,
      ip: getClientIp(req),
      ipCountry: getIpCountry(req) ?? null,
      latitude: geo.latitude,
      longitude: geo.longitude,
      locationAccuracy: geo.accuracy,
      userAgent: (req.headers['user-agent'] as string | undefined) ?? null,
    },
  });
}
