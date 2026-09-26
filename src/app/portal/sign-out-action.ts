"use server";

import { redirect } from "next/navigation";

import { createServerClient } from "@/lib/supabase/server";
import { appRoute } from "@/lib/utils";

/**
 * Sign out.
 *
 * Calls `supabase.auth.signOut()`, which revokes the refresh token server-side.
 * Clearing cookies alone would leave a still-valid refresh token in the browser,
 * so the redirect happens here in the action rather than in the client, where a
 * navigation could be skipped or raced.
 */
export async function signOut(): Promise<void> {
  const supabase = await createServerClient();
  await supabase?.auth.signOut();

  redirect(appRoute("/login"));
}
