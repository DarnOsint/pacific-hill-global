import Link from "next/link";

import { SiteFooter, SiteHeader } from "@/components/marketing/site-chrome";
import { getNavPages, getSharedContent } from "@/lib/cms";

export const revalidate = 300;

/**
 * Businesses index.
 *
 * The grid is generated from `business_units`, so enabling or retiring a sector
 * is a database edit. There is no hardcoded list of the six businesses anywhere
 * in the codebase.
 */
export default async function BusinessesPage() {
  const [navPages, shared] = await Promise.all([getNavPages(), getSharedContent()]);

  const units = shared.businessUnits;

  return (
    <div className="flex min-h-dvh flex-col bg-canvas">
      <SiteHeader navPages={navPages} businessUnits={units} />

      <main className="flex-1">
        <section className="border-b border-hairline bg-surface-muted">
          <div className="container-page section-y">
            <p className="eyebrow">Our businesses</p>
            <h1 className="display-hero mt-5 max-w-3xl text-ink-950">
              Six operating sectors, one accountable group
            </h1>
            <p className="lede mt-6 max-w-2xl">
              Each sector runs as a distinct operation with its own management, targets
              and reporting — held together by a common set of financial controls and
              governance that reports to the Director.
            </p>
          </div>
        </section>

        {units.length === 0 ? (
          <section className="section-y">
            <div className="container-page">
              <p className="lede">No public businesses are published yet.</p>
            </div>
          </section>
        ) : (
          <ul className="divide-y divide-hairline">
            {units.map((unit, i) => (
              <li key={unit.id}>
                <Link
                  href={`/businesses/${unit.slug}`}
                  className="group block transition-colors hover:bg-surface-muted"
                >
                  <div className="container-page grid gap-6 py-12 md:grid-cols-12 md:items-baseline md:gap-10">
                    <div className="md:col-span-1">
                      <span
                        aria-hidden
                        className="tabular block font-mono text-xs text-ink-400"
                      >
                        {String(i + 1).padStart(2, "0")}
                      </span>
                    </div>

                    <div className="md:col-span-4">
                      <div className="flex items-center gap-2.5">
                        <span
                          aria-hidden
                          className="size-2.5 rounded-full"
                          style={{
                            backgroundColor:
                              unit.accent_color ?? "var(--color-bronze-500)",
                          }}
                        />
                        <h2 className="font-display text-2xl text-ink-950">
                          {unit.short_name}
                        </h2>
                      </div>
                    </div>

                    <div className="md:col-span-6">
                      <p className="text-sm leading-relaxed text-ink-600">
                        {unit.tagline ?? unit.summary}
                      </p>
                    </div>

                    <div className="md:col-span-1 md:text-right">
                      <span
                        aria-hidden
                        className="inline-block text-bronze-600 transition-transform duration-200 group-hover:translate-x-1"
                      >
                        →
                      </span>
                    </div>
                  </div>
                </Link>
              </li>
            ))}
          </ul>
        )}

        <section className="section-y bg-ink-950 text-canvas">
          <div className="container-page">
            <h2 className="display-section max-w-2xl text-canvas">
              One relationship manager across every sector
            </h2>
            <p className="lede mt-5 max-w-2xl text-ink-300">
              A single point of contact rather than a queue of departments. Tell us what
              you are looking to do and we will route it.
            </p>
            <Link href="/contact" className="btn btn-accent btn-lg mt-9">
              Contact the group
            </Link>
          </div>
        </section>
      </main>

      <SiteFooter businessUnits={units} contact={shared.contact} />
    </div>
  );
}
