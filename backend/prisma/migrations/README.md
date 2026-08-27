# Prisma migrations

This project ships without a committed migration history (the schema was
authored and evolved via `prisma db push` during early development). The
`migration_lock.toml` file above pins the provider to `postgresql` so the
first real migration is created against the right database.

## One-time setup (do this once, from a machine with real DATABASE_URL access)

```bash
cd backend
npm install
export DATABASE_URL="postgresql://user:pass@host:5432/db?schema=public"
npx prisma migrate dev --name init
git add prisma/migrations
git commit -m "chore: baseline initial prisma migration"
```

After that, every schema change should go through:

```bash
npx prisma migrate dev --name <description>
```

and the generated SQL in `prisma/migrations/<timestamp>_<description>/` must
be committed. `docker-entrypoint.sh` and `src/index.ts` both run
`prisma migrate deploy` on container start, which applies any migrations
found here in order.

## Until the first migration exists

`docker-entrypoint.sh` detects an empty `prisma/migrations` directory and
falls back to `prisma db push --accept-data-loss --skip-generate` so the
container still boots with a correct schema on a fresh database. This
fallback is safe only because there is no data to lose on a brand-new
database — once real migrations exist, `migrate deploy` takes over and the
fallback is skipped automatically.
