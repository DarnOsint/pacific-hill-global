import type { Metadata, Viewport } from "next";
import { Inter, JetBrains_Mono, Newsreader } from "next/font/google";

import "./globals.css";

/**
 * Root layout.
 *
 * Fonts are self-hosted by `next/font`, which means no render-blocking request
 * to a third party and no layout shift when they arrive. The CSS custom property
 * names are referenced by `@theme` in globals.css, so the type scale in the
 * design system resolves to these families.
 */
const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

const newsreader = Newsreader({
  subsets: ["latin"],
  variable: "--font-newsreader",
  display: "swap",
  // The display face is used at large sizes with tight tracking; a little extra
  // weight range keeps headings from looking thin on low-DPI screens.
  weight: ["300", "400", "500", "600"],
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-mono-jet",
  display: "swap",
  weight: ["400", "500"],
});

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000";
const companyName = process.env.NEXT_PUBLIC_COMPANY_NAME ?? "Pacific Hill Global";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: `${companyName} — Diversified business. Enduring value.`,
    template: `%s | ${companyName}`,
  },
  description:
    "Pacific Hill Global is a diversified business group operating across Africa and beyond: automobile trading, real estate and land, agriculture, mining, logistics and freight forwarding, and importation and general trading.",
  applicationName: companyName,
  manifest: "/manifest.webmanifest",
  appleWebApp: {
    capable: true,
    title: "PHG Staff",
    statusBarStyle: "black-translucent",
  },
  formatDetection: {
    telephone: false,
  },
  openGraph: {
    type: "website",
    siteName: companyName,
    locale: "en_GB",
  },
  twitter: {
    card: "summary_large_image",
  },
  robots: {
    index: true,
    follow: true,
  },
  alternates: {
    canonical: "/",
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#ffffff" },
    { media: "(prefers-color-scheme: dark)", color: "#081322" },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html
      lang="en"
      className={`${inter.variable} ${newsreader.variable} ${jetbrainsMono.variable}`}
    >
      <body className="min-h-dvh antialiased">{children}</body>
    </html>
  );
}
