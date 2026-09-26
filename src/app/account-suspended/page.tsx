import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Account suspended",
  robots: { index: false, follow: false },
};

/**
 * Shown when a session is valid but the account is not `active` — suspended,
 * pending review, or archived.
 *
 * The wording deliberately does not say which of those it is, and does not
 * promise when access returns. A suspended employee should not be able to learn
 * the state of their case from this page, and the reason belongs in a direct
 * conversation with the group IT team, not on a page that could be cached or
 * screenshotted.
 */
export default function AccountSuspendedPage() {
  return (
    <main className="flex min-h-dvh items-center justify-center bg-canvas px-5 py-16">
      <div className="w-full max-w-md text-center">
        <p className="font-display text-xl text-ink-950">
          Pacific Hill <span className="text-bronze-700">Global</span>
        </p>

        <h1 className="display-hero mt-10 text-ink-950">Account not active</h1>
        <p className="lede mt-5">
          Your account exists but is not currently permitted to sign in.
        </p>
        <p className="mt-5 text-sm leading-relaxed text-ink-600">
          This can happen while an account is being set up, after a period of
          inactivity, or if access has been withdrawn. Please contact the group IT
          team to have it reviewed.
        </p>

        <div className="mt-9 flex flex-wrap justify-center gap-3">
          <Link href="/contact" className="btn btn-primary">
            Contact us
          </Link>
          <Link href="/builditandtheywillcome" className="btn btn-ghost">
            Back to sign in
          </Link>
        </div>
      </div>
    </main>
  );
}
