/**
 * Public environment access — safe to import from client components.
 *
 * Only `NEXT_PUBLIC_*` values live here. Anything privileged goes in
 * `env.server.ts`, which is guarded by `server-only` so a mistake becomes a
 * build error rather than a leaked key in the browser bundle.
 *
 * Every value is validated with a helpful message instead of surfacing as
 * `undefined` deep inside a Supabase client error.
 */
import { z } from "zod";

const publicSchema = z.object({
  siteUrl: z.string().url().default("http://localhost:3000"),
  companyName: z.string().min(1).default("Pacific Hill Global"),
  supabaseUrl: z.string().url().optional(),
  supabaseAnonKey: z.string().min(20).optional(),
  requireMfa: z
    .enum(["true", "false"])
    .default("false")
    .transform((v) => v === "true"),
});

function readPublicEnv() {
  const raw = {
    siteUrl: process.env.NEXT_PUBLIC_SITE_URL,
    companyName: process.env.NEXT_PUBLIC_COMPANY_NAME,
    supabaseUrl: process.env.NEXT_PUBLIC_SUPABASE_URL,
    supabaseAnonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    requireMfa: process.env.NEXT_PUBLIC_REQUIRE_MFA,
  };

  // During `next build` with no .env present, fall back to documented defaults
  // instead of throwing, so a clean checkout still builds.
  const result = publicSchema.safeParse({
    siteUrl: raw.siteUrl || undefined,
    companyName: raw.companyName || undefined,
    supabaseUrl: raw.supabaseUrl || undefined,
    supabaseAnonKey: raw.supabaseAnonKey || undefined,
    requireMfa: raw.requireMfa || undefined,
  });

  if (!result.success) {
    const detail = result.error.issues
      .map((i) => `${i.path.join(".")}: ${i.message}`)
      .join("; ");
    throw new Error(`Invalid public environment configuration — ${detail}`);
  }

  return result.data;
}

export const env = readPublicEnv();

/**
 * True when a Supabase project is configured.
 *
 * The app is fully functional without one in a *degraded* mode: the public
 * site renders built-in default content, and authenticated surfaces show a
 * configuration notice. This is what lets `next build` and CI run on a clean
 * checkout with no secrets.
 */
export const isSupabaseConfigured = Boolean(env.supabaseUrl && env.supabaseAnonKey);

/** Absolute site origin without a trailing slash. */
export function siteUrl(path = ""): string {
  const base = env.siteUrl.replace(/\/+$/, "");
  if (!path) return base;
  return `${base}${path.startsWith("/") ? path : `/${path}`}`;
}
