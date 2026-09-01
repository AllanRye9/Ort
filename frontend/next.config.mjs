import { withIntlayer } from 'next-intlayer/server';

/** @type {import('next').NextConfig} */

// Warn during builds if NEXT_PUBLIC_API_URL isn't set. Railway may expose
// service variables at runtime without forwarding them into Docker ARGs, so
// refusing to create the image makes the deployment failure less actionable.
//
// NEXT_PUBLIC_* variables are inlined into the client JS bundle at build
// time. Once a build ships without this set, no runtime fix is possible —
// setting the variable in the hosting dashboard afterwards does nothing
// until the frontend is rebuilt. That's exactly what happened on
// piitrade.com: the deployed bundle had NEXT_PUBLIC_API_URL baked in as
// missing, so every API call in the browser went to localhost:5000 and hit
// ERR_CONNECTION_REFUSED, since there is obviously no backend running on
// the visitor's own machine.
//
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
