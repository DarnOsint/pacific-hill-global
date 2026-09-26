import type { Metadata } from "next";
import Link from "next/link";

import { getUserContext } from "@/lib/rbac/guards";

export const metadata: Metadata = {
  title: "Access denied",
  robots: { index: false, follow: false },
};

/**
 * Shown when an authenticated user lacks the permission a page requires.
 *
 * The user is identified so the page can say "you", which makes the denial
 * legible, but it never lists the permissions the account was missing: that
 * would turn this into a discovery tool for probing the permission model.
 */
export default async function ForbiddenPage() {
  const ctx = await getUserContext();

  return (
    <main className="flex min-h-dvh items-center justify-center bg-canvas px-5 py-16">
      <div className="w-full max-w-md text-center">
        <p className="font-display text-xl text-ink-950">
          Pacific Hill <span className="text-bronze-700">Global</span>
        </p>

        <h1 className="display-hero mt-10 text-ink-950">Access denied</h1>
        <p className="lede mt-5">
          {ctx
            ? `Your role does not permit this part of the platform, ${ctx.email}.`
            : "You do not have access to this part of the platform."}
        </p>
        <p className="mt-5 text-sm leading-relaxed text-ink-600">
          If you need this for your work, ask the group IT team to extend your role.
          Access is granted per module rather than by default.
        </p>

        <div className="mt-9 flex flex-wrap justify-center gap-3">
          {ctx ? (
            <Link href="/portal" className="btn btn-primary">
              Back to portal
            </Link>
          ) : (
            <Link href="/builditandtheywillcome" className="btn btn-primary">
              Sign in
            </Link>
          )}
        </div>
      </div>
    </main>
  );
}
