"use client";

import { useActionState } from "react";

import { signIn, type LoginState } from "./actions";

/**
 * Sign-in form.
 *
 * A client component only because it needs `useActionState` to show the result
 * of the server action without a page reload. The credential check happens
 * entirely on the server.
 */
export function LoginForm({ next }: { next?: string }) {
  const [state, formAction, pending] = useActionState<LoginState, FormData>(signIn, {});

  return (
    <form action={formAction} className="rounded-lg border border-white/10 bg-white/[0.03] p-7">
      {next ? <input type="hidden" name="next" value={next} /> : null}

      <div>
        <label htmlFor="email" className="field-label text-ink-300">
          Email address
        </label>
        <input
          id="email"
          name="email"
          type="email"
          autoComplete="username"
          required
          autoFocus
          spellCheck={false}
          className="field-input border-white/15 bg-ink-900/60 text-canvas placeholder:text-ink-500"
          placeholder="name@pacifichillglobal.com"
        />
      </div>

      <div className="mt-5">
        <label htmlFor="password" className="field-label text-ink-300">
          Password
        </label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          className="field-input border-white/15 bg-ink-900/60 text-canvas placeholder:text-ink-500"
          placeholder="••••••••••••"
        />
      </div>

      {state.error ? (
        <p
          role="alert"
          className="mt-5 rounded-sm border border-critical/40 bg-critical/10 px-3.5 py-2.5 text-sm text-red-300"
        >
          {state.error}
        </p>
      ) : null}

      <button type="submit" disabled={pending} className="btn btn-accent btn-lg mt-7 w-full">
        {pending ? "Signing in…" : "Sign in"}
      </button>

      <p className="mt-6 text-center text-xs leading-relaxed text-ink-500">
        Trouble signing in? Contact the group IT team. Passwords are never
        requested by email or telephone.
      </p>
    </form>
  );
}
