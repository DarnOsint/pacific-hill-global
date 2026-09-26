"use server";

import type { Route } from "next";
import { headers } from "next/headers";
import { redirect } from "next/navigation";

import { safeNextPath } from "@/lib/rbac/guards";
import { createServerClient } from "@/lib/supabase/server";

/**
 * Staff sign-in.
 *
 * Notes on the approach:
 *
 * - The password is read from the form data and handed straight to Supabase. It
 *   is never logged, never written to the database, and never included in the
 *   return value.
 * - `safeNextPath` is applied to the `next` parameter *before* it is used, so a
 *   crafted `?next=https://evil.com` cannot turn this form into an open redirect
 *   that a phished employee would follow from a legitimate-looking login page.
 * - Failures are reported generically. Distinguishing "no such user" from "wrong
 *   password" hands an attacker a user-enumeration oracle.
 */

export type LoginState = {
  error?: string;
};

export async function signIn(
  _prev: LoginState,
  formData: FormData,
): Promise<LoginState> {
  const email = String(formData.get("email") ?? "").trim().toLowerCase();
  const password = String(formData.get("password") ?? "");
  const next = safeNextPath(String(formData.get("next") ?? ""), "/portal");

  if (!email || !password) {
    return { error: "Enter your email address and password." };
  }

  const supabase = await createServerClient();
  if (!supabase) {
    return {
      error:
        "Sign-in is unavailable because the platform database is not configured on this deployment.",
    };
  }

  const { error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    // Supabase's own message is deliberately not surfaced.
    return { error: "Those details were not recognised. Please try again." };
  }

  // Bind the session to this request so the audit trail can attribute the login.
  const h = await headers();
  h.set("x-phg-login", new Date().toISOString());

  // `next` has been through `safeNextPath`, so it is same-origin by
  // construction. The cast re-asserts that for `typedRoutes`, which cannot see
  // the validation that happened inside the helper.
  redirect(next as Route);
}
