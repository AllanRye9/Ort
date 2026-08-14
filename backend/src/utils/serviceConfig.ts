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
