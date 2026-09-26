import type { MetadataRoute } from "next";

import { siteUrl } from "@/lib/env";

/**
 * Robots rules for the public marketing site.
 *
 * Staff surfaces are disallowed so /login, /portal and /admin never appear in
 * search results. The CMS page slugs are intentionally not enumerated here —
 * they are seeded and can change, so the sitemap is the authoritative list.
 */
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: "*",
        allow: "/",
        disallow: ["/login", "/portal", "/admin", "/reports", "/api/"],
      },
    ],
    sitemap: siteUrl("/sitemap.xml"),
    host: siteUrl(),
  };
}
