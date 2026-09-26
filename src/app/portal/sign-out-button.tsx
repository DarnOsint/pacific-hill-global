"use client";

import { useTransition } from "react";

import { signOut } from "./sign-out-action";

export function SignOutButton() {
  const [pending, start] = useTransition();

  return (
    <form
      action={() => start(() => void signOut())}
      className="flex items-center gap-3"
    >
      <button type="submit" disabled={pending} className="btn btn-ghost btn-sm">
        {pending ? "Signing out…" : "Sign out"}
      </button>
    </form>
  );
}
