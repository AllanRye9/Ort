/** @type {import('next').NextConfig} */

// FAIL THE BUILD if NEXT_PUBLIC_API_URL isn't set, instead of silently
// shipping a bundle that falls back to http://localhost:5000.
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
// This check only ever runs during `next build` — verified empirically:
// this file is not copied into `.next/standalone`, and the standalone
// server (`node server.js`) reads only the pre-resolved config baked into
// `.next/required-server-files.json` at build time, so this throw can never
// fire at container startup/runtime, only when actually building.
//
// Escape hatch: set SKIP_API_URL_CHECK=1 for builds that intentionally
// don't need a real backend (e.g. a type-check-only CI job).
if (!process.env.NEXT_PUBLIC_API_URL && !process.env.SKIP_API_URL_CHECK) {
  throw new Error(
    '\n\n' +
    '✖ NEXT_PUBLIC_API_URL is not set — refusing to build.\n\n' +
    '  This value is inlined into the client bundle at build time, so it\n' +
    '  cannot be fixed later by setting it in a hosting dashboard alone —\n' +
    '  the frontend must be REBUILT after setting it.\n\n' +
    '  Set it to the backend\'s public URL, e.g.:\n' +
    '    NEXT_PUBLIC_API_URL=https://<your-backend-service>.up.railway.app\n' +
    '  or\n' +
    '    NEXT_PUBLIC_API_URL=https://<your-backend-service>.onrender.com\n\n' +
    '  On Railway/Render, set this as a build-time variable on the FRONTEND\n' +
    '  service (Variables tab), then trigger a new deployment so it rebuilds.\n\n' +
    '  Building locally without a real backend? Copy .env.example to\n' +
    '  .env.local, or set SKIP_API_URL_CHECK=1 to bypass this check.\n'
  );
}

const nextConfig = {
  // Produces a minimal, self-contained `.next/standalone` build (server +
  // only the node_modules actually used) so the production Docker image
  // doesn't need to ship the full node_modules tree.
  output: 'standalone',

  // Safety net on top of the fetch-level fix in app/layout.tsx: the default
  // is 60s, which is exactly what was being hit ("took more than 60
  // seconds") when the backend was slow to respond during static
  // generation. The root-layout fetch now times out itself well before
  // this, but a higher ceiling here avoids the same failure mode if any
  // other page/route ever adds its own slow build-time fetch.
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

export default nextConfig;
