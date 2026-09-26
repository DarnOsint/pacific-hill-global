/**
 * Browser Supabase client.
 *
 * The ONLY Supabase client allowed in a client component. Uses the anon key, so
 * row-level security applies to the signed-in user exactly as it does on the
 * server. There is deliberately no import path from here to the admin client:
 * keeping them in separate modules makes "which key is this using?" answerable
 * from the filename alone.
 *
 * Note this file has no `import "server-only"` — that is the point. See
 * `server.ts` for the server-scoped clients.
 */
"use client";

import { createBrowserClient as createSupabaseBrowserClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";

import { env, isSupabaseConfigured } from "@/lib/env";
import type { Database } from "@/types/database";

/**
 * Returns `null` when Supabase is not configured, so a clean checkout without
 * secrets renders the public site instead of throwing.
 *
 * Callers in client components must handle `null`; the app treats "no client"
 * as "no authenticated features available" rather than an error.
 */
export function createBrowserClient(): SupabaseClient<Database> | null {
  if (!isSupabaseConfigured) return null;
  return createSupabaseBrowserClient<Database>(
    env.supabaseUrl!,
    env.supabaseAnonKey!,
  );
}
