/**
 * Server-only environment access.
 *
 * `import "server-only"` makes any accidental import from a client component a
 * build-time error rather than a leaked secret. Nothing privileged may be read
 * from `process.env` anywhere else in the codebase.
 */
import "server-only";

import { z } from "zod";

const serverSchema = z.object({
  serviceRoleKey: z.string().min(20).optional(),
  sessionAbsoluteTimeout: z.coerce.number().int().positive().default(43_200),
  sessionIdleTimeout: z.coerce.number().int().positive().default(7_200),
  maxUploadBytes: z.coerce.number().int().positive().default(26_214_400),
  buckets: z.object({
    websitePublic: z.string().default("website-public"),
    documents: z.string().default("documents"),
    employees: z.string().default("employees"),
    messages: z.string().default("messages"),
    finance: z.string().default("finance"),
  }),
  rateLimit: z.object({
    loginAttempts: z.coerce.number().int().positive().default(5),
    loginWindowSeconds: z.coerce.number().int().positive().default(900),
    writesPerMinute: z.coerce.number().int().positive().default(120),
  }),
  cronSecret: z.string().optional(),
  email: z.object({
    provider: z.string().default(""),
    fromAddress: z.string().default("no-reply@pacifichillglobal.com"),
    fromName: z.string().default("Pacific Hill Global"),
  }),
  sentryDsn: z.string().optional(),
});

function readServerEnv() {
  const result = serverSchema.safeParse({
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || undefined,
    sessionAbsoluteTimeout:
      process.env.SESSION_ABSOLUTE_TIMEOUT_SECONDS || undefined,
    sessionIdleTimeout: process.env.SESSION_IDLE_TIMEOUT_SECONDS || undefined,
    maxUploadBytes: process.env.MAX_UPLOAD_BYTES || undefined,
    buckets: {
      websitePublic: process.env.STORAGE_BUCKET_WEBSITE_PUBLIC || undefined,
      documents: process.env.STORAGE_BUCKET_DOCUMENTS || undefined,
      employees: process.env.STORAGE_BUCKET_EMPLOYEES || undefined,
      messages: process.env.STORAGE_BUCKET_MESSAGES || undefined,
      finance: process.env.STORAGE_BUCKET_FINANCE || undefined,
    },
    rateLimit: {
      loginAttempts: process.env.RATE_LIMIT_LOGIN_ATTEMPTS || undefined,
      loginWindowSeconds:
        process.env.RATE_LIMIT_LOGIN_WINDOW_SECONDS || undefined,
      writesPerMinute: process.env.RATE_LIMIT_WRITE_ACTIONS_PER_MINUTE || undefined,
    },
    cronSecret: process.env.CRON_SECRET || undefined,
    email: {
      provider: process.env.EMAIL_PROVIDER || undefined,
      fromAddress: process.env.EMAIL_FROM_ADDRESS || undefined,
      fromName: process.env.EMAIL_FROM_NAME || undefined,
    },
    sentryDsn: process.env.SENTRY_DSN || undefined,
  });

  if (!result.success) {
    const detail = result.error.issues
      .map((i) => `${i.path.join(".")}: ${i.message}`)
      .join("; ");
    throw new Error(`Invalid server environment configuration — ${detail}`);
  }

  return result.data;
}

export const serverEnv = readServerEnv();

/** Throws if the service role key is missing. Only for privileged operations. */
export function requireServiceRoleKey(): string {
  if (!serverEnv.serviceRoleKey) {
    throw new Error(
      "SUPABASE_SERVICE_ROLE_KEY is not configured. This operation cannot be performed as the signed-in user.",
    );
  }
  return serverEnv.serviceRoleKey;
}

export const isProduction = process.env.NODE_ENV === "production";
