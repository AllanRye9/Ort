import 'dotenv/config';
import { spawnSync } from 'child_process';
import fs from 'fs';
import path from 'path';

const projectRoot = path.resolve(__dirname, '..');
const prismaDir = path.join(projectRoot, 'prisma');
const hotfixesDir = path.join(prismaDir, 'hotfixes');

const log = (message: string) => console.log(`[db-setup] ${message}`);
const warn = (message: string) => console.warn(`[db-setup] ${message}`);

const ensureDatabaseUrl = () => {
  if (!process.env.DATABASE_URL && process.env.DATABASE_PRIVATE_URL) {
    process.env.DATABASE_URL = process.env.DATABASE_PRIVATE_URL;
    log('DATABASE_URL not set — using DATABASE_PRIVATE_URL for Prisma CLI calls.');
  }

  if (!process.env.DATABASE_URL) {
    throw new Error(
      'No database URL found. Set DATABASE_URL (or DATABASE_PRIVATE_URL on Railway) before running Prisma migrations or hotfixes.'
    );
  }
};

const run = (command: string, args: string[]) => {
  const result = spawnSync(command, args, {
    cwd: projectRoot,
    env: process.env,
    stdio: 'inherit',
    shell: process.platform === 'win32',
  });

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(' ')} exited with code ${result.status ?? 'unknown'}`);
  }
};

const getMigrationDirCount = (): number => {
  const migrationsDir = path.join(prismaDir, 'migrations');
  if (!fs.existsSync(migrationsDir)) return 0;

  return fs
    .readdirSync(migrationsDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .filter((entry) => !entry.name.startsWith('.'))
    .length;
};

const runMigrations = () => {
  const migrationCount = getMigrationDirCount();

  if (migrationCount === 0) {
    log("No committed migrations found — bootstrapping schema with 'prisma db push'.");
    run('npx', ['prisma', 'db', 'push', '--accept-data-loss', '--skip-generate']);
    log('Schema bootstrap complete.');
    return;
  }

  log(`Running prisma migrate deploy (${migrationCount} migration(s) found)...`);
  run('npx', ['prisma', 'migrate', 'deploy']);
  log('Migrations applied successfully.');
};

const runHotfixes = () => {
  if (!fs.existsSync(hotfixesDir)) {
    log('No hotfix directory found — skipping compatibility SQL files.');
    return;
  }

  const files = fs
    .readdirSync(hotfixesDir)
    .filter((file) => file.toLowerCase().endsWith('.sql'))
    .sort();

  if (files.length === 0) {
    log('No hotfix SQL files found — skipping compatibility SQL files.');
    return;
  }

  log(`Applying ${files.length} compatibility hotfix(es)...`);

  for (const file of files) {
    const relativePath = path.join('prisma', 'hotfixes', file);
    log(`Applying hotfix: ${file}`);

    try {
      run('npx', ['prisma', 'db', 'execute', '--file', relativePath, '--schema', 'prisma/schema.prisma']);
    } catch (error) {
      warn(`Hotfix failed: ${file}. Continuing with remaining hotfixes.`);
      console.error(error);
    }
  }

  log('Compatibility hotfixes complete.');
};

const args = new Set(process.argv.slice(2));

try {
  ensureDatabaseUrl();

  if (args.has('--hotfixes-only')) {
    runHotfixes();
    process.exit(0);
  }

  runMigrations();
  runHotfixes();
  log('Database setup complete.');
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error('[db-setup] Database setup failed.');
  console.error(message);
  process.exit(1);
}
