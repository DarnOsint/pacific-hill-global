/**
 * Authentication context and the authorisation guards.
 *
 * The full lifecycle is in docs/ARCHITECTURE.md §5. In short, every protected
 * code path does:
 *
 *     requirePermission('vehicles.create')   // 401 → 403, in that order
 *
 * There is deliberately no `hasRole()` and no `isDirector` helper. If you find
 * yourself wanting one, the correct answer is a new permission.
 */
import "server-only";

import { cache } from "react";
import { redirect } from "next/navigation";

import { createServerClient } from "@/lib/supabase/server";
import { serverEnv } from "@/lib/env.server";
import type { Permission, Scope, UserContext } from "@/lib/rbac/permissions";
import { can, canForUnit } from "@/lib/rbac/permissions";
import type { MyPermissionsResult } from "@/types/database";
import { appRoute } from "@/lib/utils";

/* -------------------------------------------------------------------------- */
/* Errors                                                                      */
/* -------------------------------------------------------------------------- */

export class UnauthenticatedError extends Error {
  readonly status = 401;
  constructor(message = "Authentication required") {
    super(message);
    this.name = "UnauthenticatedError";
  }
}

export class ForbiddenError extends Error {
  readonly status = 403;
  constructor(
    message = "You do not have permission to perform this action",
    readonly permission?: Permission,
  ) {
    super(message);
    this.name = "ForbiddenError";
  }
}

export class AccountInactiveError extends Error {
  readonly status = 403;
  constructor(
    message = "This account is not active. Contact your administrator.",
  ) {
    super(message);
    this.name = "AccountInactiveError";
  }
}

export class NotConfiguredError extends Error {
  readonly status = 503;
  constructor() {
    super(
      "The platform database is not configured. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY.",
    );
    this.name = "NotConfiguredError";
  }
}

/* -------------------------------------------------------------------------- */
/* Next parameter safety                                                       */
/* -------------------------------------------------------------------------- */

/**
 * Validate a `?next=` value before redirecting to it.
 *
 * Rejects absolute URLs, protocol-relative URLs (`//evil.com`) and backslash
 * variants, all of which would otherwise turn the login page into an open
 * redirect.
 */
export function safeNextPath(next: string | undefined | null, fallback = "/portal"): string {
  if (!next) return fallback;
  if (!next.startsWith("/")) return fallback;
  if (next.startsWith("//")) return fallback;
  if (next.startsWith("/\\")) return fallback;
  if (next.includes("\\")) return fallback;
  if (/^\/[a-z][a-z0-9+.-]*:/i.test(next)) return fallback;
  return next;
}

/* -------------------------------------------------------------------------- */
/* User context                                                                */
/* -------------------------------------------------------------------------- */

/**
 * Resolve the caller's identity, permissions and scopes.
 *
 * Memoised for the lifetime of the request (React `cache`), so a page that
 * guards in three places performs one read.
 *
 * Returns `null` when there is no session. It never throws for the anonymous
 * case, because public pages call it to decide what to render.
 */
export const getUserContext = cache(async (): Promise<UserContext | null> => {
  const supabase = await createServerClient();
  if (!supabase) return null;

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const { data, error } = await supabase.rpc("get_my_permissions");
  if (error) {
    // The function is absent on an un-migrated database. Fail closed: the user
    // is authenticated but has no permissions, so every guard will 403 and the
    // admin will see an actionable message instead of a blank page.
    return {
      userId: user.id,
      employeeId: null,
      departmentId: null,
      email: user.email ?? "",
      fullName: (user.user_metadata?.full_name as string) ?? (user.email ?? ""),
      avatarUrl: null,
      accountStatus: "pending",
      permissions: new Set<Permission>(),
      scopes: [],
      isSuperuser: false,
      sessionExpiresAt: null,
    };
  }

  const payload = data as unknown as MyPermissionsResult;
  const scopes = buildScopes(payload);
  const permissions = new Set<Permission>(payload.permissions as Permission[]);

  return {
    userId: payload.userId ?? user.id,
    employeeId: payload.employeeId ?? null,
    departmentId: payload.departmentId ?? null,
    email: user.email ?? "",
    fullName: (user.user_metadata?.full_name as string) ?? (user.email ?? ""),
    avatarUrl: (user.user_metadata?.avatar_url as string) ?? null,
    accountStatus: payload.accountStatus ?? "active",
    permissions,
    scopes,
    // "Superuser" means exactly one thing: this account holds the platform
    // administration permission. It is deliberately NOT derived from a role
    // name, from seniority, or from "has any permission at all" — an earlier
    // draft used `permissions.length > 0 && isStaff`, which handed every
    // manager a bypass of every permission and scope check.
    isSuperuser: permissions.has("platform.admin"),
    sessionExpiresAt: null,
  };
});

function buildScopes(payload: MyPermissionsResult): Scope[] {
  const departments = payload.scopes?.departments ?? [];
  const businessUnits = payload.scopes?.businessUnits ?? [];

  // The database states globalness explicitly. An earlier draft inferred it
  // from `departments.length > 100`, which silently changed meaning as the
  // organisation grew and treated "assigned to every current department" as
  // equivalent to "will reach every future department".
  if (payload.globalScope) return [{ type: "global" }];

  const scopes: Scope[] = [];
  for (const id of departments) scopes.push({ type: "department", departmentId: id });
  for (const id of businessUnits)
    scopes.push({ type: "businessUnit", businessUnitId: id });

  return scopes;
}

/* -------------------------------------------------------------------------- */
/* Guards                                                                      */
/* -------------------------------------------------------------------------- */

/** Session required. Throws `UnauthenticatedError`. */
export async function requireUser(): Promise<UserContext> {
  const ctx = await getUserContext();
  if (!ctx) throw new UnauthenticatedError();
  return ctx;
}

/** Session required, and the account must be active. */
export async function requireActiveUser(): Promise<UserContext> {
  const ctx = await requireUser();
  if (ctx.accountStatus !== "active") throw new AccountInactiveError();
  return ctx;
}

/** Session + at least one of the given permissions. */
export async function requirePermission(
  ...permissions: Permission[]
): Promise<UserContext> {
  const ctx = await requireActiveUser();
  if (!can(ctx, ...permissions)) {
    throw new ForbiddenError(undefined, permissions[0]);
  }
  return ctx;
}

/** Session + a permission, narrowed to a specific business unit. */
export async function requireUnitPermission(
  permission: Permission,
  businessUnitId: string | null,
): Promise<UserContext> {
  const ctx = await requireActiveUser();
  if (!canForUnit(ctx, permission, businessUnitId)) {
    throw new ForbiddenError(undefined, permission);
  }
  return ctx;
}

/** Session + a permission, narrowed to a department. */
export async function requireDepartmentPermission(
  permission: Permission,
  departmentId: string | null,
): Promise<UserContext> {
  const ctx = await requireActiveUser();
  if (!ctx.permissions.has(permission) || !reachesDepartment(ctx, departmentId)) {
    throw new ForbiddenError(undefined, permission);
  }
  return ctx;
}

function reachesDepartment(ctx: UserContext, departmentId: string | null): boolean {
  if (ctx.isSuperuser) return true;
  if (ctx.scopes.some((s) => s.type === "global")) return true;
  if (!departmentId) return true;
  return ctx.scopes.some(
    (s) => s.type === "department" && s.departmentId === departmentId,
  );
}

/** Any authenticated user — used by /portal/dashboard, which adapts by permission. */
export async function requireAnySession(): Promise<UserContext> {
  return requireActiveUser();
}

/* -------------------------------------------------------------------------- */
/* Page guards                                                                 */
/* -------------------------------------------------------------------------- */

/**
 * Guard for a protected **page**. Redirects rather than throwing, because a
 * thrown error in a page render becomes an error boundary rather than a 401.
 *
 * `nextPath` is passed explicitly (the current route, known by the caller) and
 * validated through `safeNextPath`, so the login page can never be turned into
 * an open redirect.
 */
export async function guardPage(
  permissions: Permission[],
  nextPath?: string,
): Promise<UserContext> {
  const ctx = await getUserContext();

  if (!ctx) {
    const target = safeNextPath(nextPath, "/portal");
    redirect(appRoute(`/login?next=${encodeURIComponent(target)}`));
  }

  if (ctx.accountStatus !== "active") {
    redirect(appRoute("/account-suspended"));
  }

  if (permissions.length > 0 && !can(ctx, ...permissions)) {
    redirect(appRoute("/forbidden"));
  }

  return ctx;
}

/** Guard that throws 403 so an API/handler returns the right status. */
export async function guardApi(...permissions: Permission[]): Promise<UserContext> {
  const ctx = await requireActiveUser();
  if (permissions.length > 0 && !can(ctx, ...permissions)) {
    throw new ForbiddenError(undefined, permissions[0]);
  }
  return ctx;
}

/* -------------------------------------------------------------------------- */
/* Session hygiene                                                             */
/* -------------------------------------------------------------------------- */

/** Update last-login markers. Called after a successful sign-in. */
export async function recordSuccessfulLogin(userId: string): Promise<void> {
  const supabase = await createServerClient();
  if (!supabase) return;

  await supabase
    .from("users")
    .update({
      last_login_at: new Date().toISOString(),
      failed_login_count: 0,
      locked_until: null,
    })
    .eq("id", userId);
}

/** Whether the caller's session has exceeded the configured absolute lifetime. */
export function sessionWithinPolicy(sessionExpiresAt: string | null): boolean {
  if (!sessionExpiresAt) return true;
  return new Date(sessionExpiresAt).getTime() > Date.now();
}

export const sessionPolicy = {
  absoluteTimeoutSeconds: serverEnv.sessionAbsoluteTimeout,
  idleTimeoutSeconds: serverEnv.sessionIdleTimeout,
};
