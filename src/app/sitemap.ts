import type { MetadataRoute } from "next";

import { siteUrl } from "@/lib/env";
import { createPublicClient } from "@/lib/supabase/server";

/**
 * Public sitemap.
 *
 * Static marketing routes are listed unconditionally so the file stays useful
 * on a clean checkout with no Supabase configured; the dynamic business and
 * news routes are appended only when the database is reachable. A metadata
 * route that throws would take the whole build down, so every database failure
 * degrades to "static routes only" instead.
 */
const STATIC_ROUTES: { path: string; priority: number; changeFrequency: "daily" | "weekly" | "monthly" | "yearly" }[] = [
  { path: "/", priority: 1, changeFrequency: "weekly" },
  { path: "/about", priority: 0.8, changeFrequency: "monthly" },
  { path: "/businesses", priority: 0.9, changeFrequency: "weekly" },
  { path: "/news", priority: 0.7, changeFrequency: "daily" },
  { path: "/contact", priority: 0.8, changeFrequency: "yearly" },
  { path: "/legal/privacy", priority: 0.3, changeFrequency: "yearly" },
  { path: "/legal/terms", priority: 0.3, changeFrequency: "yearly" },
];

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const now = new Date();

  const entries: MetadataRoute.Sitemap = STATIC_ROUTES.map((route) => ({
    url: siteUrl(route.path),
    lastModified: now,
    changeFrequency: route.changeFrequency,
    priority: route.priority,
  }));

  const supabase = createPublicClient();
  if (!supabase) return entries;

  const [unitsRes, newsRes] = await Promise.all([
    supabase
      .from("business_units")
      .select("slug, updated_at")
      .eq("public_visible", true)
      .eq("is_active", true)
      .is("deleted_at", null)
      .order("sort_order", { ascending: true }),
    supabase
      .from("news_posts")
      .select("slug, published_at, updated_at")
      .eq("status", "published")
      .is("deleted_at", null)
      .order("published_at", { ascending: false }),
  ]);

  for (const unit of unitsRes.data ?? []) {
    if (!unit.slug) continue;
    entries.push({
      url: siteUrl(`/businesses/${unit.slug}`),
      lastModified: unit.updated_at ? new Date(unit.updated_at) : now,
      changeFrequency: "monthly",
      priority: 0.7,
    });
  }

  for (const post of newsRes.data ?? []) {
    if (!post.slug) continue;
    entries.push({
      url: siteUrl(`/news/${post.slug}`),
      lastModified: post.updated_at
        ? new Date(post.updated_at)
        : post.published_at
          ? new Date(post.published_at)
          : now,
      changeFrequency: "yearly",
      priority: 0.5,
    });
  }

  return entries;
}
