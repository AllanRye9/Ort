import { logger } from './logger';

interface ServiceReadiness {
  jwt: {
    ready: boolean;
    missing: string[];
  };
  storage: {
    s3: boolean;
    s3Endpoint: string | null;
    localFallback: boolean;
  };
  email: {
    resend: boolean;
    smtp: boolean;
    logFallback: boolean;
  };
}

function missing(keys: string[]): string[] {
  return keys.filter((key) => !process.env[key]);
}

function hasAll(keys: string[]): boolean {
  return missing(keys).length === 0;
}

function hasAny(keys: string[]): boolean {
  return keys.some((key) => !!process.env[key]);
}

function warnPartialConfig(serviceName: string, keys: string[]): void {
  const missingKeys = missing(keys);
  if (missingKeys.length === 0) return;
  if (!hasAny(keys)) return;

  logger.warn(
    `${serviceName} partially configured. Missing: ${missingKeys.join(', ')}. ` +
    'Service will not be used until all required variables are set.'
  );
}

export function validateAndLogServiceConfig(): void {
  const readiness = getServiceReadiness();

  const missingJwt = readiness.jwt.missing;
  if (missingJwt.length > 0) {
    throw new Error(`Missing required environment variables: ${missingJwt.join(', ')}`);
  }

  const s3Keys = ['ACCESS_KEY_ID', 'SECRET_ACCESS_KEY', 'BUCKET'];
  const resendKeys = ['RESEND_API_KEY', 'RESEND_FROM_EMAIL'];
  const smtpKeys = ['SMTP_HOST', 'SMTP_USER', 'SMTP_PASS'];

  warnPartialConfig('S3 Storage', s3Keys);
  warnPartialConfig('Resend', resendKeys);
  warnPartialConfig('SMTP', smtpKeys);

  const s = readiness.storage;
  const endpointInfo = s.s3 && s.s3Endpoint ? ` (endpoint: ${s.s3Endpoint})` : '';
  logger.info(
    `Service config: JWT=ready, ` +
    `Storage=[S3:${s.s3 ? 'on' : 'off'}${endpointInfo}, LocalFallback:on], ` +
    `Email=[Resend:${readiness.email.resend ? 'on' : 'off'}, SMTP:${readiness.email.smtp ? 'on' : 'off'}, LogFallback:on]`
  );

  // Loud, hard-to-miss warning: on Railway (and most PaaS containers) the
  // filesystem is ephemeral — anything written to the local `uploads/`
  // fallback disappears on the next deploy/restart. Without S3 configured,
  // every uploaded listing photo is one redeploy away from silently
  // 404ing for every user (this is exactly what caused the electronics
  // listing images to break in production). Uploads that already went to
  // local disk under a since-recycled container cannot be recovered — this
  // only prevents it from happening again going forward.
  const isEphemeralHost = Boolean(
    process.env.RAILWAY_ENVIRONMENT_ID || process.env.RAILWAY_PROJECT_ID
  );
  if (!s.s3 && isEphemeralHost) {
    logger.warn(
      '⚠ S3 storage is NOT configured (ACCESS_KEY_ID / SECRET_ACCESS_KEY / BUCKET missing) ' +
      'while running on Railway. Uploaded images are being written to the local ' +
      'filesystem fallback (/uploads), which is wiped on every deploy or restart — ' +
      'previously uploaded listing photos WILL 404 after the next deploy. ' +
      'Fix by either (1) setting ACCESS_KEY_ID, SECRET_ACCESS_KEY, BUCKET (and ' +
      'ENDPOINT if using a non-AWS S3-compatible bucket) so uploads persist in ' +
      'object storage, or (2) attaching a Railway Volume mounted at /app/uploads ' +
      'so the local fallback itself survives deploys.'
    );
  }
}

export function getServiceReadiness(): ServiceReadiness {
  const requiredJwtKeys = ['JWT_SECRET', 'JWT_REFRESH_SECRET'];
  const s3Keys = ['ACCESS_KEY_ID', 'SECRET_ACCESS_KEY', 'BUCKET'];
  const resendKeys = ['RESEND_API_KEY', 'RESEND_FROM_EMAIL'];
  const smtpKeys = ['SMTP_HOST', 'SMTP_USER', 'SMTP_PASS'];

  return {
    jwt: {
      ready: hasAll(requiredJwtKeys),
      missing: missing(requiredJwtKeys),
    },
    storage: {
      s3: hasAll(s3Keys),
      s3Endpoint: process.env.ENDPOINT || null,
      localFallback: true,
    },
    email: {
      resend: hasAll(resendKeys),
      smtp: hasAll(smtpKeys),
      logFallback: true,
    },
  };
}
