/**
 * Audit logging.
 *
 * Every material action writes here. `audit_logs` has no INSERT policy for
 * clients, so the only writable path is the security-definer RPC
 * `public.write_audit`, which fills in actor identity from the session rather
 * than trusting parameters.
 *
 * Auditing must never break the operation it is recording. `write()` therefore
 * swallows its own errors after logging them: a failed audit write is a
 * problem to investigate, but failing the user's completed action because of it
 * is worse. Failures are surfaced through `onAuditFailure` so the deployment can
 * wire an error reporter.
 */
import "server-only";

import { headers } from "next/headers";

import { createServerClient } from "@/lib/supabase/server";
import type { UserContext } from "@/lib/rbac/permissions";
import type { Json } from "@/types/database";

type Severity = "info" | "notice" | "warning" | "critical";

type AuditEvent = {
  action: string;
  resourceType: string;
  resourceId?: string | null;
  resourceLabel?: string | null;
  summary?: string;
  metadata?: Json;
  severity?: Severity;
};

/** Replace with Sentry/OTel in production. Wired through env.SENTRY_DSN. */
let onAuditFailure: (error: unknown, event: AuditEvent) => void = (error, event) => {
  if (process.env.NODE_ENV === "development") {
    console.error("[audit] write failed", { action: event.action, error });
  }
};

export function setAuditFailureHandler(
  handler: (error: unknown, event: AuditEvent) => void,
): void {
  onAuditFailure = handler;
}

export const audit = {
  /**
   * Record one event. Fire-and-forget from the caller's perspective: never
   * throws, so it can be called immediately after a mutation without wrapping.
   */
  async write(actor: UserContext, event: AuditEvent): Promise<void> {
    const supabase = await createServerClient();
    if (!supabase) return;

    try {
      const headerList = await headers();
      const requestId =
        headerList.get("x-request-id") ?? headerList.get("x-vercel-id") ?? null;

      const { error } = await supabase.rpc("write_audit", {
        p_action: event.action,
        p_resource_type: event.resourceType,
        p_resource_id: event.resourceId ?? null,
        p_resource_label: event.resourceLabel ?? null,
        p_summary: event.summary ?? null,
        p_metadata: event.metadata ?? {},
        p_severity: event.severity ?? "info",
      });

      if (error) throw error;
      if (requestId) {
        // The request id is already on the row via request.headers; nothing to
        // do. Kept explicit so a future schema change has an obvious hook.
      }
    } catch (error) {
      onAuditFailure(error, event);
    }
  },

  /** Record several events from a single mutation. */
  async writeMany(actor: UserContext, events: AuditEvent[]): Promise<void> {
    await Promise.all(events.map((event) => audit.write(actor, event)));
  },

  /** The activity feed entry that powers the human-readable company timeline. */
  async activity(
    actor: UserContext,
    entry: {
      verb: string;
      summary: string;
      detail?: string;
      domain: string;
      businessUnitId?: string | null;
      departmentId?: string | null;
      resourceType?: string;
      resourceId?: string | null;
      url?: string | null;
      visibility?:
        | "private"
        | "department"
        | "business_unit"
        | "company";
      audienceUserIds?: string[];
      metadata?: Json;
    },
  ): Promise<void> {
    const supabase = await createServerClient();
    if (!supabase) return;

    try {
      const { error } = await supabase.from("activity_feed").insert({
        actor_id: actor.userId,
        actor_name: actor.fullName,
        actor_avatar: actor.avatarUrl,
        verb: entry.verb,
        summary: entry.summary,
        detail: entry.detail ?? null,
        domain: entry.domain,
        business_unit_id: entry.businessUnitId ?? null,
        department_id: entry.departmentId ?? null,
        resource_type: entry.resourceType ?? null,
        resource_id: entry.resourceId ?? null,
        url: entry.url ?? null,
        visibility: entry.visibility ?? "company",
        audience_user_ids: entry.audienceUserIds ?? [],
        metadata: entry.metadata ?? {},
      });
      if (error) throw error;
    } catch (error) {
      onAuditFailure(error, {
        action: "activity.failed",
        resourceType: "activity_feed",
        metadata: { domain: entry.domain },
      });
    }
  },

  /** Convenience wrapper: audit + activity in one call for a single mutation. */
  async record(
    actor: UserContext,
    event: AuditEvent & {
      activityVerb?: string;
      activityDomain?: string;
      businessUnitId?: string | null;
      departmentId?: string | null;
      url?: string | null;
      visibility?:
        | "private"
        | "department"
        | "business_unit"
        | "company";
    },
  ): Promise<void> {
    await audit.write(actor, event);

    if (event.activityDomain && event.activityVerb) {
      await audit.activity(actor, {
        verb: event.activityVerb,
        summary: event.summary ?? event.action,
        domain: event.activityDomain,
        businessUnitId: event.businessUnitId,
        departmentId: event.departmentId,
        resourceType: event.resourceType,
        resourceId: event.resourceId,
        url: event.url,
        visibility: event.visibility,
        metadata: event.metadata,
      });
    }
  },

  /** Notify a set of users. Used by approvals, mentions, assignments. */
  async notify(params: {
    recipientIds: string[];
    actorId?: string | null;
    kind:
      | "message"
      | "group_message"
      | "task_assigned"
      | "task_due"
      | "task_completed"
      | "announcement"
      | "approval_request"
      | "approval_decision"
      | "mention"
      | "system"
      | "document"
      | "lead"
      | "system_alert";
    title: string;
    body?: string;
    url?: string;
    resourceType?: string;
    resourceId?: string | null;
    priority?: "low" | "normal" | "high";
    metadata?: Json;
  }): Promise<void> {
    const supabase = await createServerClient();
    if (!supabase) return;
    if (params.recipientIds.length === 0) return;

    const actorId = params.actorId ?? null;
    const recipients = actorId
      ? params.recipientIds.filter((id) => id !== actorId)
      : params.recipientIds;
    if (recipients.length === 0) return;

    try {
      const { error } = await supabase.from("notifications").insert(
        recipients.map((recipient_id) => ({
          recipient_id,
          kind: params.kind,
          title: params.title,
          body: params.body ?? null,
          url: params.url ?? null,
          actor_id: actorId,
          resource_type: params.resourceType ?? null,
          resource_id: params.resourceId ?? null,
          priority: params.priority ?? "normal",
          metadata: params.metadata ?? {},
        })),
      );
      if (error) throw error;
    } catch (error) {
      onAuditFailure(error, {
        action: "notification.failed",
        resourceType: "notifications",
      });
    }
  },
};
