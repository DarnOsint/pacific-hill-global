/**
 * Server Supabase clients.
 *
 * Four distinct clients, four distinct trust levels. Confusing them is the
 * single most dangerous mistake available in this codebase, so each is named for
 * the authority it carries:
 *
 *   createPublicClient()  — anon key, NO cookies, no session. For content that
 *                           is public to every visitor. Being cookie-free is what
 *                           lets those pages prerender at build time instead of
 *                           becoming dynamic on every request.
 *   createServerClient()  — anon key + cookies. RLS applies as the signed-in
 *                           user. The default for anything user-specific; nothing
 *                           else should be used.
 *   createAdminClient()   — service role key, RLS BYPASSED. Server only, for
 *                           the few operations a user cannot perform for
 *                           themselves (admin bootstrap, webhook signature
 *                           checks, scheduled jobs).
 *
 * The browser client lives in `browser.ts` and is never re-exported here.
 */
import "server-only";

import { createServerClient as createSupabaseServerClient } from "@supabase/ssr";
import {
  createClient as createSupabaseClient,
  type SupabaseClient,
} from "@supabase/supabase-js";
import { cookies } from "next/headers";
import { cache } from "react";

import { env, isSupabaseConfigured } from "@/lib/env";
import { requireServiceRoleKey } from "@/lib/env.server";
import type { Database } from "@/types/database";

/* -------------------------------------------------------------------------- */
/* Public (anon, cookie-free) — for content every visitor may read             */
/* -------------------------------------------------------------------------- */

let publicClient: SupabaseClient<Database> | null = null;

/**
 * Reads only what RLS already exposes to `anon`. There is no cookie adapter, so
 * this client works inside `generateStaticParams` and at build time, and the
 * resulting pages can be statically cached and served from the CDN.
 *
 * Never use this for user-specific data. It carries no session, so a row that
 * is *not* publicly readable will return nothing rather than raising an error —
 * which is the safe failure direction, but it will look like missing data.
 */
export function createPublicClient(): SupabaseClient<Database> | null {
  if (!isSupabaseConfigured) return null;
  if (publicClient) return publicClient;

  publicClient = createSupabaseClient<Database>(env.supabaseUrl!, env.supabaseAnonKey!, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
    global: { headers: { "X-Client-Info": "pacific-hill-global/public" } },
  });

  return publicClient;
}

/* -------------------------------------------------------------------------- */
/* Server (session-scoped, RLS applies)                                        */
/* -------------------------------------------------------------------------- */

/**
 * Memoised per request via React `cache`, so a page that calls
 * `requirePermission` from three places still performs one session read.
 */
export const createServerClient = cache(async (): Promise<SupabaseClient<Database> | null> => {
  if (!isSupabaseConfigured) return null;

  const cookieStore = await cookies();

  return createSupabaseServerClient<Database>(
    env.supabaseUrl!,
    env.supabaseAnonKey!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // Called from a Server Component, where cookies are read-only.
            // `proxy.ts` performs the refresh, so this is safe to ignore.
          }
        },
      },
    },
  );
});

/* -------------------------------------------------------------------------- */
/* Admin (RLS bypassed) — server only                                          */
/* -------------------------------------------------------------------------- */

let adminClient: SupabaseClient<Database> | null = null;

/**
 * RLS is BYPASSED. Every caller must have already proved authorisation through
 * a different mechanism, and must not pass user-supplied identifiers straight
 * into a filter without validating them first.
 */
export function createAdminClient(): SupabaseClient<Database> {
  if (adminClient) return adminClient;

  adminClient = createSupabaseClient<Database>(
    env.supabaseUrl!,
    requireServiceRoleKey(),
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUrl: false,
      },
      global: { headers: { "X-Client-Info": "pacific-hill-global/admin" } },
    },
  );

  return adminClient;
}

/** Only safe when the caller has already proved authorisation. */
export function isAdminClient(client: SupabaseClient<Database> | null): boolean {
  return Boolean(client && adminClient && client === adminClient);
}
