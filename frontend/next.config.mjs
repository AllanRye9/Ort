/** @type {import('next').NextConfig} */
const nextConfig = {
  // Produces a minimal, self-contained `.next/standalone` build (server +
  // only the node_modules actually used) so the production Docker image
  // doesn't need to ship the full node_modules tree.
  output: 'standalone',

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

export default nextConfig;
