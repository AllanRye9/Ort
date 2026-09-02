import { withIntlayer } from 'next-intlayer/server';

/** @type {import('next').NextConfig} */

// Warn during builds if NEXT_PUBLIC_API_URL isn't set, and hard-fail if it's
// still the unfilled `<...>` placeholder from .env.example. Railway may
// expose service variables at runtime without forwarding them into Docker
// ARGs, so refusing to create the image makes the deployment failure less
// actionable to leave as a warning alone.
//
// NEXT_PUBLIC_* variables are inlined into the client JS bundle at build
// time. Once a build ships with this wrong, no runtime fix is possible —
// setting the variable in the hosting dashboard afterwards does nothing
// until the frontend is rebuilt. That's exactly what happened on
// piitrade.com (twice now — see the committed root `.env` this was found
// in): the deployed bundle had NEXT_PUBLIC_API_URL baked in as either
// missing or the literal `https://<your-backend-service>.up.railway.app`
// placeholder text, so every API call in the browser tried to resolve a
// domain that doesn't exist and failed outright — every /auth/login,
// /auth/register, etc. request included.
//
if (process.env.NEXT_PUBLIC_API_URL?.includes('<') && !process.env.SKIP_API_URL_CHECK) {
  throw new Error(
    `NEXT_PUBLIC_API_URL is still set to the unfilled placeholder "${process.env.NEXT_PUBLIC_API_URL}". `
      + 'Replace it with the real backend URL (e.g. http://localhost:5000 for local docker-compose, or '
      + 'the deployed backend\'s https URL) before building. Set SKIP_API_URL_CHECK=1 to bypass this check.'
  );
}
if (!process.env.NEXT_PUBLIC_API_URL && !process.env.SKIP_API_URL_CHECK) {
  console.warn(
    '\n⚠ NEXT_PUBLIC_API_URL is not set. The build will continue, but browser API calls '
      + 'will use the local fallback. Set this as a FRONTEND build-time variable and rebuild.\n'
  );
}

const nextConfig = {
  // Produces a minimal, self-contained `.next/standalone` build (server +
  // only the node_modules actually used) so the production Docker image
  // doesn't need to ship the full node_modules tree.
  output: 'standalone',

  // Keep a higher ceiling for any page or route that may add a slow
  // build-time fetch. Static pages and the sitemap do not depend on the
  // backend during generation; their optional API requests are bounded.
  staticPageGenerationTimeout: 120,

  eslint: {
    // Linting is run in CI / locally; don't let it block production builds.
    ignoreDuringBuilds: true,
  },

  images: {
    // Listing/avatar/site-media images are served from the backend API
    // (local disk in dev, S3-compatible storage in production) rather than
    // from a fixed set of remote hosts, so we allow any https(s) source and
    // let the backend be the actual access-control boundary. Tighten this
    // to explicit remotePatterns once the production image domain(s) are
    // finalized.
    remotePatterns: [
      { protocol: 'http', hostname: '**' },
      { protocol: 'https', hostname: '**' },
    ],
  },
};

// withIntlayer() reads frontend/intlayer.config.ts, builds the content
// dictionaries, and wires the plugin into webpack/Turbopack. It's async
// (it prepares dictionaries before the build starts), so it's awaited here
// at the top level — supported because this file is loaded as ESM.
export default await withIntlayer(nextConfig);
