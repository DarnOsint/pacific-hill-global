import type { Route } from "next";
import Link from "next/link";

import { LogoLockup } from "@/components/brand/logo";
import { type PublicContact, whatsappDigits } from "@/lib/cms";
import { cmsHref } from "@/lib/utils";
import type { BusinessUnitRow, WebsitePageRow } from "@/types/database";

/**
 * Public site header.
 *
 * Navigation is built from `website_pages` rows where `show_in_nav` is true, so
 * adding a page to the menu is a database edit rather than a code change.
 */

/** Typed as `Route` so `typedRoutes` checks these at compile time. */
const FOOTER_LINKS = [
  { href: "/about", label: "About" },
  { href: "/businesses", label: "Businesses" },
  { href: "/news", label: "News" },
  { href: "/contact", label: "Contact" },
] as const satisfies ReadonlyArray<{ href: Route; label: string }>;

export function SiteHeader({
  navPages,
  businessUnits,
}: {
  navPages: WebsitePageRow[];
  businessUnits: BusinessUnitRow[];
}) {
  return (
    <header className="sticky top-0 z-50 border-b border-hairline bg-canvas/85 backdrop-blur-md">
      <div className="container-page">
        <div className="flex h-16 items-center justify-between gap-6">
          <Link
            href="/"
            className="shrink-0 text-ink-900 transition-opacity hover:opacity-70"
            aria-label="Pacific Hill Global — home"
          >
            <LogoLockup />
          </Link>

          <nav aria-label="Primary" className="hidden items-center gap-7 lg:flex">
            {navPages.map((page) => (
              <Link
                key={page.id}
                href={cmsHref(page.slug === "homepage" ? "/" : `/${page.slug}`)}
                className="text-sm font-medium text-ink-700 transition-colors hover:text-ink-950"
              >
                {page.nav_label ?? page.title}
              </Link>
            ))}
          </nav>

          <div className="flex items-center gap-2">
            <Link href="/contact" className="btn btn-primary btn-sm">
              Contact us
            </Link>
          </div>
        </div>
      </div>

      {/* Sector rail: the six operating businesses, one glance away. */}
      {businessUnits.length > 0 && (
        <div className="border-t border-hairline bg-surface-muted">
          <div className="container-page">
            <ul className="no-scrollbar -mx-1 flex items-center gap-6 overflow-x-auto py-2.5">
              {businessUnits.map((unit) => (
                <li key={unit.id} className="shrink-0">
                  <Link
                    href={cmsHref(`/businesses/${unit.slug}`)}
                    className="group flex items-center gap-2 text-xs font-medium text-ink-600 transition-colors hover:text-ink-950"
                  >
                    <span
                      aria-hidden
                      className="size-2 rounded-full"
                      style={{ backgroundColor: unit.accent_color ?? "var(--color-bronze-500)" }}
                    />
                    {unit.short_name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}
    </header>
  );
}

export function SiteFooter({
  businessUnits,
  contact,
}: {
  businessUnits: BusinessUnitRow[];
  /** Publishable contact details from `public.public_contact`. */
  contact?: PublicContact | null;
}) {
  // Database first, environment second. The fallback is read here rather than
  // accepted as a prop so that no call site can forget it and silently render a
  // footer with no way to make contact.
  //
  // There is deliberately no `tel:` link: the group is WhatsApp-only, so a phone
  // link must not be reintroduced here.
  const email = contact?.email ?? process.env.NEXT_PUBLIC_CONTACT_EMAIL ?? null;
  const whatsapp = contact?.whatsapp ?? process.env.NEXT_PUBLIC_WHATSAPP_NUMBER ?? null;
  const whatsappNumber = whatsappDigits(whatsapp);
  const year = new Date().getFullYear();

  return (
    <footer className="border-t border-hairline bg-ink-950 text-ink-200">
      <div className="container-page section-y">
        <div className="grid gap-12 md:grid-cols-12">
          <div className="md:col-span-5">
            <LogoLockup tone="light" markClassName="h-10 w-10" />
            <p className="mt-5 max-w-sm text-sm leading-relaxed text-ink-300">
              A diversified business group operating across Africa and beyond.
              Long horizons, local knowledge, and a single accountable standard.
            </p>
            <div className="mt-6 space-y-1.5 text-sm">
              {email ? (
                <a
                  href={`mailto:${email}`}
                  className="block text-ink-200 transition-colors hover:text-canvas"
                >
                  {email}
                </a>
              ) : null}
              {whatsappNumber ? (
                <a
                  href={`https://wa.me/${whatsappNumber}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="block tabular text-ink-200 transition-colors hover:text-canvas"
                >
                  WhatsApp {whatsapp}
                </a>
              ) : null}
            </div>
          </div>

          <div className="md:col-span-4">
            <h2 className="text-2xs font-semibold uppercase tracking-[0.16em] text-bronze-300">
              Our businesses
            </h2>
            <ul className="mt-5 space-y-2.5 text-sm">
              {businessUnits.map((unit) => (
                <li key={unit.id}>
                  <Link
                    href={cmsHref(`/businesses/${unit.slug}`)}
                    className="text-ink-300 transition-colors hover:text-canvas"
                  >
                    {unit.short_name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          <div className="md:col-span-3">
            <h2 className="text-2xs font-semibold uppercase tracking-[0.16em] text-bronze-300">
              Company
            </h2>
            <ul className="mt-5 space-y-2.5 text-sm">
              {FOOTER_LINKS.map((l) => (
                <li key={l.href}>
                  <Link
                    href={l.href}
                    className="text-ink-300 transition-colors hover:text-canvas"
                  >
                    {l.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </div>

        <div className="mt-14 flex flex-col gap-4 border-t border-white/10 pt-8 text-xs text-ink-400 sm:flex-row sm:items-center sm:justify-between">
          <p>
            © {year} Pacific Hill Global. All rights reserved.
          </p>
          <div className="flex gap-6">
            <Link href="/legal/privacy" className="transition-colors hover:text-ink-200">
              Privacy
            </Link>
            <Link href="/legal/terms" className="transition-colors hover:text-ink-200">
              Terms
            </Link>
          </div>
        </div>
      </div>
    </footer>
  );
}
