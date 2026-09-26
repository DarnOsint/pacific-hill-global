import type { Metadata } from "next";

import { SignOutButton } from "./sign-out-button";
import { getUserContext } from "@/lib/rbac/guards";

export const metadata: Metadata = {
  title: "Portal",
  robots: { index: false, follow: false },
};

/**
 * Staff portal landing page.
 *
 * The permission model is intentionally not rendered here. This page proves two
 * things and nothing more: that the session is real, and who it belongs to. What
 * a given user may then reach is decided by `requirePermission` on each module
 * page, not by hiding links in a menu — a hidden link is not an authorisation
 * control, and treating it as one is how privilege escalation bugs start.
 */
export default async function PortalPage() {
  const ctx = await getUserContext();

  // `getUserContext()` returns null only if the session vanished between the
  // proxy's check and this render; `guardPage` handles the normal case.
  if (!ctx) return null;

  const scope = ctx.scopes.map((s) => s.type);
  const scopeLabel = scope.includes("global")
    ? "Group-wide"
    : scope.includes("businessUnit")
      ? "Business unit"
      : scope.includes("department")
        ? "Department"
        : "Unassigned";

  return (
    <div className="flex min-h-dvh flex-col bg-canvas">
      <header className="border-b border-hairline bg-surface-muted">
        <div className="container-page flex h-16 items-center justify-between">
          <p className="font-display text-[1.0625rem]">
            Pacific Hill <span className="text-bronze-700">Global</span>
          </p>
          <SignOutButton />
        </div>
      </header>

      <main className="flex-1">
        <div className="container-page section-y">
          <p className="eyebrow">Staff portal</p>
          <h1 className="display-hero mt-5 text-ink-950">Welcome back</h1>
          <p className="lede mt-6 max-w-2xl">
            Signed in as {ctx.email}
            {ctx.fullName ? ` (${ctx.fullName})` : ""}. Your modules appear here as
            they are enabled.
          </p>

          <dl className="mt-12 grid gap-6 sm:grid-cols-3">
            <div className="rounded-lg border border-hairline bg-surface p-6">
              <dt className="text-2xs font-semibold uppercase tracking-[0.14em] text-ink-500">
                Scope
              </dt>
              <dd className="mt-2 font-display text-lg text-ink-950">{scopeLabel}</dd>
            </div>

            <div className="rounded-lg border border-hairline bg-surface p-6">
              <dt className="text-2xs font-semibold uppercase tracking-[0.14em] text-ink-500">
                Permissions
              </dt>
              <dd className="tabular mt-2 font-display text-lg text-ink-950">
                {ctx.permissions.size}
              </dd>
            </div>

            <div className="rounded-lg border border-hairline bg-surface p-6">
              <dt className="text-2xs font-semibold uppercase tracking-[0.14em] text-ink-500">
                Account
              </dt>
              <dd className="mt-2 font-display text-lg capitalize text-ink-950">
                {ctx.accountStatus}
              </dd>
            </div>
          </dl>

          <p className="mt-10 max-w-2xl text-sm leading-relaxed text-ink-600">
            The module pages for vehicles, property, agriculture, mining, finance and
            communications are being enabled now. Access to each one is granted
            individually to your role, and each page checks that grant again when it
            loads.
          </p>
        </div>
      </main>
    </div>
  );
}
