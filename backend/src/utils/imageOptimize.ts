import sharp from 'sharp';
import fs from 'fs';
import { logger } from './logger';

/**
 * Resizes an image file in place (overwriting it at the same path) to a
 * sane maximum dimension and re-encodes it at a quality level tuned for
 * marketplace photos, WITHOUT altering its format or applying any
 * watermark/crop — this is purely a page-weight optimization.
 *
 * Why this exists: uploads were previously stored and served completely
 * untouched. A phone photo straight off a modern camera is routinely
 * 3000–4000px wide and several MB — every visitor browsing listings (many
 * on mobile data in the target market) was downloading that full-size
 * original just to see it rendered at a few hundred pixels on a card or
 * gallery thumbnail. Capping the stored dimension and re-encoding
 * typically cuts file size by 5–10x with no visible quality loss at the
 * sizes the site actually displays images at.
 *
 * Best-effort: if sharp fails for any reason (corrupt file, unsupported
 * edge case, etc.) the original file is left untouched and the upload
 * proceeds with it as-is, rather than failing the whole request.
 */
export async function optimizeImageInPlace(
  filePath: string,
  opts: { maxDimension?: number; quality?: number } = {},
): Promise<void> {
  const { maxDimension = 1920, quality = 82 } = opts;

  try {
    const image = sharp(filePath, { failOn: 'none' });
    const metadata = await image.metadata();

    // Skip GIFs entirely — sharp would collapse an animated GIF down to a
    // single still frame, which is a functional regression, not an
    // optimization.
    if (metadata.format === 'gif') return;

    const pipeline = image.rotate(); // auto-orient from EXIF, then strip it

    if ((metadata.width ?? 0) > maxDimension || (metadata.height ?? 0) > maxDimension) {
      pipeline.resize({ width: maxDimension, height: maxDimension, fit: 'inside', withoutEnlargement: true });
    }

    switch (metadata.format) {
      case 'png':
        pipeline.png({ quality, compressionLevel: 9 });
        break;
      case 'webp':
        pipeline.webp({ quality });
        break;
      default:
        pipeline.jpeg({ quality, mozjpeg: true });
    }

    const optimizedBuffer = await pipeline.toBuffer();

    // Only replace the original if optimization actually shrank it — a
    // tiny already-optimized image can occasionally re-encode larger.
    const originalSize = fs.statSync(filePath).size;
    if (optimizedBuffer.length < originalSize) {
      fs.writeFileSync(filePath, optimizedBuffer);
    }
  } catch (err) {
    logger.warn(`Image optimization skipped for "${filePath}": ${String(err)}`);
  }
}
