/**
 * Proxy (Next 16 renamed `middleware` → `proxy`).
 *
 * Three jobs, and only three:
 *
 *   1. Refresh the Supabase session cookie so Server Components see a valid
 *      session without a full re-authentication.
 *   2. Coarse-gate `/portal` and `/admin` for an anonymous visitor, as a fast UX
 *      redirect before the expensive layout guard runs.
 *   3. Attach a request id so audit rows and logs can be correlated.
 *
 * This is NOT the security boundary. Anyone reaching the origin can bypass it,
 * and it cannot evaluate business-unit scope. Every protected page additionally
 * runs `guardPage()`, every server action runs `requirePermission()`, and every
 * query is protected by RLS. See docs/ARCHITECTURE.md §3.
 *
 * Runs on the Node.js runtime — the `edge` runtime is not supported in `proxy`.
 */
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import { env, isSupabaseConfigured } from "@/lib/env";
import type { Database } from "@/types/database";

const PUBLIC_FILE =
  /\.(?:svg|png|jpg|jpeg|gif|webp|avif|ico|woff2?|ttf|map|txt|xml|webmanifest|json)$/i;

const PROTECTED_PREFIXES = [
  "/portal",
  "/admin",
  "/reports",
  "/api/files",
  "/api/uploads",
];

const AUTH_ROUTES = [
  "/builditandtheywillcome",
  "/forgot-password",
  "/reset-password",
  "/auth/callback",
];

export async function proxy(request: NextRequest) {
  const { pathname, search } = request.nextUrl;

  // Never touch static assets or the auth endpoints.
  if (
    PUBLIC_FILE.test(pathname) ||
    pathname.startsWith("/_next") ||
    pathname.startsWith("/images") ||
    AUTH_ROUTES.some((r) => pathname === r || pathname.startsWith(`${r}/`))
  ) {
    return NextResponse.next({ request });
  }

  if (!isSupabaseConfigured) {
    // Unconfigured environment: let the app render its setup notice rather than
    // bouncing the user between pages that cannot work.
    return NextResponse.next({ request });
  }

  let response = NextResponse.next({ request });

  const supabase = createServerClient<Database>(
    env.supabaseUrl!,
    env.supabaseAnonKey!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (cookiesToSet) => {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  // IMPORTANT: getUser() revalidates the token with the auth server. Using
  // getSession() here would trust an unverified JWT straight from the cookie.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const isProtected = PROTECTED_PREFIXES.some(
    (p) => pathname === p || pathname.startsWith(`${p}/`),
  );

  if (isProtected && !user) {
    const url = request.nextUrl.clone();
    url.pathname = "/builditandtheywillcome";
    url.search = `?next=${encodeURIComponent(pathname + search)}`;
    return NextResponse.redirect(url);
  }

  // A signed-in user has no business on the login page.
  if (user && pathname === "/builditandtheywillcome") {
    const url = request.nextUrl.clone();
    url.pathname = "/portal";
    url.search = "";
    return NextResponse.redirect(url);
  }

  return response;
}

export const config = {
  matcher: [
    /*
     * Everything except:
     *   - _next/static, _next/image (optimised assets)
     *   - favicon and common public files
     *   - the public marketing surface, which must be crawlable and cacheable
     */
    "/((?!_next/static|_next/image|favicon.ico|images|robots.txt|sitemap.xml|manifest.webmanifest|sw.js).*)",
  ],
};
