import { notFound } from "next/navigation";

import { MarketingSection } from "@/components/marketing/sections";
import { SiteFooter, SiteHeader } from "@/components/marketing/site-chrome";
import {
  getCmsPage,
  getNavPages,
  getSharedContent,
  type SharedContent,
} from "@/lib/cms";
import { createPublicClient } from "@/lib/supabase/server";

/**
 * Generic renderer for every CMS-driven page: `/about`, `/contact`,
 * `/legal/privacy`, and anything added later.
 *
 * The site deliberately has no hand-written page component per slug. A page is a
 * row in `website_pages` plus ordered rows in `website_sections`, so one
 * implementation covers all of them and publishing a new page is a database
 * insert rather than a pull request.
 */

/** Shown when Supabase is not configured — a developer state, not a visitor one. */
export async function NotConfigured() {
  const navPages = await getNavPages();
  const { businessUnits } = await getSharedContent();

  return (
    <div className="flex min-h-dvh flex-col bg-canvas">
      <SiteHeader navPages={navPages} businessUnits={businessUnits} />
      <main className="section-y flex-1">
        <div className="container-page">
          <p className="eyebrow">Not configured</p>
          <h1 className="display-section mt-4 text-ink-950">
            The platform database is not connected
          </h1>
          <p className="lede mt-5 max-w-2xl">
            This deployment has no Supabase credentials. Set{" "}
            <code className="font-mono text-sm">NEXT_PUBLIC_SUPABASE_URL</code> and{" "}
            <code className="font-mono text-sm">NEXT_PUBLIC_SUPABASE_ANON_KEY</code>, then
            reload.
          </p>
        </div>
      </main>
      <SiteFooter businessUnits={businessUnits} />
    </div>
  );
}

/**
 * Render the page at `slug`.
 *
 * Distinguishes "no database configured" from "no such page", because only the
 * second is a 404 — collapsing them would make every missing page look like a
 * broken deployment.
 */
export async function CmsPage({ slug }: { slug: string }) {
  const supabase = createPublicClient();
  const page = await getCmsPage(slug);

  if (!page) {
    if (!supabase) return <NotConfigured />;
    notFound();
  }

  const [navPages, shared] = await Promise.all([getNavPages(), getSharedContent()]);
  const content: SharedContent = shared;

  return (
    <div className="flex min-h-dvh flex-col bg-canvas">
      <SiteHeader navPages={navPages} businessUnits={shared.businessUnits} />
      <main className="flex-1">
        {page.sections.length === 0 ? (
          <section className="section-y">
            <div className="container-page">
              <p className="eyebrow">Coming soon</p>
              <h1 className="display-section mt-4 text-ink-950">{page.page.title}</h1>
              {page.page.subtitle && (
                <p className="lede mt-5 max-w-2xl">{page.page.subtitle}</p>
              )}
            </div>
          </section>
        ) : (
          page.sections.map((section) => (
            <MarketingSection key={section.id} section={section} content={content} />
          ))
        )}
      </main>
      <SiteFooter businessUnits={shared.businessUnits} contact={shared.contact} />
    </div>
  );
}
