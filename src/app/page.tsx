import { notFound } from "next/navigation";

import { MarketingSection } from "@/components/marketing/sections";
import { SiteFooter, SiteHeader } from "@/components/marketing/site-chrome";
import { getHomeContent, getNavPages } from "@/lib/cms";

/**
 * Marketing homepage.
 *
 * The page is a thin assembly: it loads the published `homepage` row and its
 * ordered sections, then hands each section to the renderer registry. No copy,
 * no ordering and no visibility decision lives in this file — all of it is CMS
 * data — so the site can be reorganised from the admin surface without a deploy.
 *
 * `revalidate` is 60s. Public marketing copy changes on the order of days, not
 * seconds, and a short window keeps the page fast without serving stale content
 * for long.
 */
export const revalidate = 60;

export default async function HomePage() {
  const content = await getHomeContent();

  // Only a *configured* database with no homepage row is an error. An
  // unconfigured checkout renders the notice below and still builds, which is
  // what keeps CI and a fresh clone working without secrets.
  if (!content.unavailable && !content.page) {
    notFound();
  }

  const navPages = await getNavPages();

  return (
    <div className="flex min-h-dvh flex-col bg-canvas">
      <SiteHeader navPages={navPages} businessUnits={content.businessUnits} />

      <main id="main" className="flex-1">
        {content.unavailable ? (
          <UnconfiguredNotice />
        ) : content.sections.length > 0 ? (
          content.sections.map((section) => (
            <MarketingSection key={section.id} section={section} content={content} />
          ))
        ) : (
          <EmptyNotice />
        )}
      </main>

      <SiteFooter businessUnits={content.businessUnits} contact={content.contact} />
    </div>
  );
}

/**
 * Shown when Supabase is not configured. This is a developer-facing state, not a
 * visitor-facing one, so it says exactly what is missing and how to fix it
 * instead of pretending to be a real page.
 */
function UnconfiguredNotice() {
  return (
    <section className="section-y bg-surface-muted">
      <div className="container-page">
        <p className="eyebrow">Not configured</p>
        <h1 className="display-section mt-4 text-ink-950">
          The platform database is not connected
        </h1>
        <p className="lede mt-5 max-w-2xl">
          This deployment has no Supabase credentials, so there is no content to
          show. Copy <code className="font-mono text-sm">.env.example</code> to{" "}
          <code className="font-mono text-sm">.env.local</code> and set{" "}
          <code className="font-mono text-sm">NEXT_PUBLIC_SUPABASE_URL</code> and{" "}
          <code className="font-mono text-sm">NEXT_PUBLIC_SUPABASE_ANON_KEY</code>.
        </p>
      </div>
    </section>
  );
}

/** Configured, but the homepage row is missing or unpublished. */
function EmptyNotice() {
  return (
    <section className="section-y">
      <div className="container-page">
        <p className="eyebrow">No content yet</p>
        <h1 className="display-section mt-4 text-ink-950">The homepage is empty</h1>
        <p className="lede mt-5 max-w-2xl">
          The database is connected but the <code className="font-mono text-sm">homepage</code>{" "}
          page has no visible sections. Publish it from the admin surface, or run{" "}
          <code className="font-mono text-sm">npm run db:seed</code>.
        </p>
      </div>
    </section>
  );
}
