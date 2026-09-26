/**
 * Small shared utilities.
 */
import type { Route } from "next";

import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}

/* -------------------------------------------------------------------------- */
/* Identifiers                                                                 */
/* -------------------------------------------------------------------------- */

export function slugify(input: string): string {
  return input
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

/** Human document reference, e.g. `VEH-2026-00042`. */
export function reference(prefix: string, sequence: number, year = new Date().getFullYear()): string {
  return `${prefix.toUpperCase()}-${year}-${String(sequence).padStart(5, "0")}`;
}

/* -------------------------------------------------------------------------- */
/* Text                                                                        */
/* -------------------------------------------------------------------------- */

export function initials(name: string): string {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");
}

export function truncate(input: string, max: number): string {
  return input.length <= max ? input : `${input.slice(0, max - 1)}\u2026`;
}

export function pluralise(
  count: number,
  singular: string,
  plural = `${singular}s`,
): string {
  return `${count} ${count === 1 ? singular : plural}`;
}

export function titleCase(input: string): string {
  return input
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

/** `vehicle_status` → `Vehicle status`. */
export function humaniseEnum(input: string): string {
  return titleCase(input);
}

export function bytesToSize(bytes: number, fractionDigits = 1): string {
  if (bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  return `${(bytes / 1024 ** i).toFixed(i === 0 ? 0 : fractionDigits)} ${units[i]}`;
}

/* -------------------------------------------------------------------------- */
/* Dates                                                                       */
/* -------------------------------------------------------------------------- */

/** `2026-03-14` — the value an <input type="date"> expects. */
export function toDateInput(value: string | Date | null | undefined): string {
  if (!value) return "";
  const date = typeof value === "string" ? new Date(value) : value;
  if (Number.isNaN(date.getTime())) return "";
  return date.toISOString().slice(0, 10);
}

export function toDateTimeInput(value: string | Date | null | undefined): string {
  if (!value) return "";
  const date = typeof value === "string" ? new Date(value) : value;
  if (Number.isNaN(date.getTime())) return "";
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

export type RelativeTime = { value: number; unit: Intl.RelativeTimeFormatUnit };

export function relativeParts(from: string | Date, to: Date = new Date()): RelativeTime {
  const start = typeof from === "string" ? new Date(from) : from;
  const seconds = Math.round((start.getTime() - to.getTime()) / 1000);
  const abs = Math.abs(seconds);

  if (abs < 60) return { value: seconds, unit: "second" };
  if (abs < 3600) return { value: Math.round(seconds / 60), unit: "minute" };
  if (abs < 86_400) return { value: Math.round(seconds / 3600), unit: "hour" };
  if (abs < 2_592_000) return { value: Math.round(seconds / 86_400), unit: "day" };
  if (abs < 31_536_000) return { value: Math.round(seconds / 2_592_000), unit: "month" };
  return { value: Math.round(seconds / 31_536_000), unit: "year" };
}

/* -------------------------------------------------------------------------- */
/* Validation helpers                                                          */
/* -------------------------------------------------------------------------- */

export function isUuid(value: unknown): value is string {
  return (
    typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
  );
}

export function isIsoDate(value: unknown): value is string {
  return typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value);
}

/** Only allow same-origin relative paths in hrefs we render from user data. */
export function safeHref(href: string | null | undefined, fallback = "#"): string {
  if (!href) return fallback;
  if (href.startsWith("/")) return href;
  if (/^https:\/\//i.test(href)) return href;
  if (href.startsWith("#") || href.startsWith("mailto:") || href.startsWith("tel:")) {
    return href;
  }
  return fallback;
}

/**
 * A link target that came out of the database.
 *
 * `typedRoutes` proves at compile time that every literal href matches a real
 * page, which is genuinely valuable — but it can only do that for hrefs written
 * in source. A CTA stored in `website_sections.cta_href`, or a sector slug from
 * `business_units.slug`, is a string this compiler has never seen.
 *
 * So the unprovable cases funnel through one function instead of scattering
 * `as Route` across the marketing components. The cast is confined here, the
 * value is still run through `safeHref` first so a CMS editor cannot inject
 * `javascript:` or an off-site URL into a button, and the fallback keeps a bad
 * row from producing a dead link.
 */
export function cmsHref(href: string | null | undefined, fallback: Route = "/"): Route {
  const value = safeHref(href, fallback as string);
  return value as Route;
}

/**
 * A first-party redirect target that is assembled at runtime.
 *
 * Same reasoning as `cmsHref`: `typedRoutes` verifies literal hrefs, but a
 * redirect built from a `next` parameter is not a literal. Guard code runs
 * before the destination is known to be reachable, so the cast marks that
 * deliberate deferral in one documented place rather than at each call site.
 */
export function appRoute(path: string): Route {
  return path as Route;
}

/* -------------------------------------------------------------------------- */
/* Misc                                                                        */
/* -------------------------------------------------------------------------- */

export function unique<T>(items: T[]): T[] {
  return Array.from(new Set(items));
}

export function groupBy<T, K extends string | number>(
  items: T[],
  key: (item: T) => K,
): Record<K, T[]> {
  return items.reduce(
    (acc, item) => {
      const k = key(item);
      (acc[k] ??= []).push(item);
      return acc;
    },
    {} as Record<K, T[]>,
  );
}

export function sumBy<T>(items: T[], value: (item: T) => number | null | undefined): number {
  return items.reduce((acc, item) => acc + (value(item) ?? 0), 0);
}

export function range(n: number): number[] {
  return Array.from({ length: n }, (_, i) => i);
}

/** Stable, dependency-free id for client-side keys. */
export function shortId(prefix = "id"): string {
  return `${prefix}-${Math.random().toString(36).slice(2, 10)}`;
}
