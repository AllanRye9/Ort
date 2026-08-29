# syntax=docker/dockerfile:1

# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: deps — install dependencies.
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

RUN apk add --no-cache libc6-compat

COPY package.json package-lock.json ./

RUN npm ci --no-audit --no-fund


# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: builder — build the Next.js app.
# NEXT_PUBLIC_* variables must be present at BUILD time (they're inlined into
# the client bundle), so they're accepted as build args and re-exported as
# ENV before `next build` runs.
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
ENV NEXT_TELEMETRY_DISABLED=1

# Node's default V8 heap ceiling is derived from the host's total memory.
# Set an explicit ceiling for containerized builds.
ARG BUILD_MAX_OLD_SPACE_MB=4096
ENV NODE_OPTIONS=--max-old-space-size=${BUILD_MAX_OLD_SPACE_MB}

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# BuildKit cache mount for Next.js incremental build cache.
#
# IMPORTANT:
# The explicit `id` is required by some Docker/BuildKit versions.
RUN --mount=type=cache,id=nextjs-cache,target=/app/.next/cache \
    npm run build


# ─────────────────────────────────────────────────────────────────────────────
# Stage 3: runner — minimal production image using the Next.js standalone
# output (server.js + only the required node_modules subset).
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS runner

WORKDIR /app

RUN apk add --no-cache curl \
  && addgroup -g 1001 -S nodejs \
  && adduser -S nextjs -u 1001

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0

COPY --from=builder /app/public ./public

COPY --from=builder \
  --chown=nextjs:nodejs \
  /app/.next/standalone ./

COPY --from=builder \
  --chown=nextjs:nodejs \
  /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -f http://127.0.0.1:${PORT}/ || exit 1

CMD ["node", "server.js"]
