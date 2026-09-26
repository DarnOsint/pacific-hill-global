/**
 * Server Supabase clients.
 *
 * Three distinct clients, three distinct trust levels. Confusing them is the
 * single most dangerous mistake available in this codebase, so each is named
 * for the authority it carries:
 *
 *   createServerClient()  — anon key + cookies. RLS applies as the signed-in
 *                           user. The default for Server Components and server
 *                           actions; nothing else should be used.
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
