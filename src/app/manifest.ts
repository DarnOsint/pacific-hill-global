import type { MetadataRoute } from "next";

import { siteUrl } from "@/lib/env";

/**
 * Web app manifest.
 *
 * `start_url` is `/login` on purpose: installing this app is a staff action, so
 * launching it should land on sign-in rather than the public marketing site.
 * `scope` stays at `/` because the portal it eventually opens lives under the
 * same origin, and narrowing the scope would make the installed app navigate out
 * to the browser once a session exists.
 */
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Pacific Hill Global — Staff Portal",
    short_name: "PHG Staff",
    description:
      "Secure staff sign-in for the Pacific Hill Global operations portal: documents, messages, finance and workforce tools.",
    start_url: "/login",
    scope: "/",
    id: "/login",
    display: "standalone",
    orientation: "portrait-primary",
    background_color: "#050d18",
    theme_color: "#081322",
    categories: ["business", "productivity", "utilities"],
    icons: [
      {
        src: siteUrl("/icons/icon-192.png"),
        sizes: "192x192",
        type: "image/png",
        purpose: "any",
      },
      {
        src: siteUrl("/icons/icon-512.png"),
        sizes: "512x512",
        type: "image/png",
        purpose: "any",
      },
      {
        src: siteUrl("/icons/icon-maskable-192.png"),
        sizes: "192x192",
        type: "image/png",
        purpose: "maskable",
      },
      {
        src: siteUrl("/icons/icon-maskable-512.png"),
        sizes: "512x512",
        type: "image/png",
        purpose: "maskable",
      },
    ],
    shortcuts: [
      {
        name: "Staff sign in",
        short_name: "Sign in",
        description: "Sign in to the Pacific Hill Global staff portal.",
        url: "/login",
        icons: [{ src: siteUrl("/icons/icon-192.png"), sizes: "192x192" }],
      },
      {
        name: "Operations portal",
        short_name: "Portal",
        description: "Open the operations portal (requires an active session).",
        url: "/portal",
        icons: [{ src: siteUrl("/icons/icon-192.png"), sizes: "192x192" }],
      },
    ],
  };
}
