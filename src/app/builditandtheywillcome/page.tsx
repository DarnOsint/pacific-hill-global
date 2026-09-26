import type { Metadata } from "next";

import { LoginForm } from "./login-form";

export const metadata: Metadata = {
  title: "Staff sign in",
  robots: { index: false, follow: false },
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string }>;
}) {
  const { next } = await searchParams;

  return (
    <main className="flex min-h-dvh flex-col bg-ink-950">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 opacity-[0.07]"
        style={{
          backgroundImage:
            "linear-gradient(to right, #fff 1px, transparent 1px), linear-gradient(to bottom, #fff 1px, transparent 1px)",
          backgroundSize: "72px 72px",
        }}
      />

      <div className="relative flex flex-1 items-center justify-center px-5 py-16">
        <div className="w-full max-w-md">
          <div className="mb-10 text-center">
            <p className="font-display text-xl text-canvas">
              Pacific Hill <span className="text-bronze-400">Global</span>
            </p>
            <h1 className="mt-8 font-display text-3xl text-canvas">Staff sign in</h1>
            <p className="mt-3 text-sm text-ink-400">
              For employees. Use the email address issued by the group.
            </p>
          </div>

          <LoginForm next={next} />
        </div>
      </div>

      <p className="relative pb-8 text-center text-xs text-ink-500">
        Authorised access only. Activity is logged.
      </p>
    </main>
  );
}
