import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { SiteFooter, SiteHeader } from "@/components/marketing/site-chrome";
import { getNavPages, getSharedContent, type PublicContact } from "@/lib/cms";
import { createPublicClient } from "@/lib/supabase/server";

export const revalidate = 300;

export async function generateStaticParams() {
  const supabase = createPublicClient();
  if (!supabase) return [];
  const { data } = await supabase
    .from("business_units")
    .select("slug")
    .eq("public_visible", true)
    .eq("is_active", true)
    .is("deleted_at", null);
  return (data ?? []).map((u) => ({ slug: u.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const supabase = createPublicClient();
  if (!supabase) return { title: "Our businesses" };

  const { data } = await supabase
    .from("business_units")
    .select("name, short_name, tagline, summary")
    .eq("slug", slug)
    .eq("public_visible", true)
    .is("deleted_at", null)
    .maybeSingle();

  if (!data) return { title: "Our businesses" };

  return {
    title: data.short_name ?? data.name,
    description: data.tagline ?? data.summary ?? undefined,
  };
}

export default async function BusinessUnitPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const supabase = createPublicClient();

  if (!supabase) {
    const [navPages, shared] = await Promise.all([getNavPages(), getSharedContent()]);
    return (
      <Shell navPages={navPages} units={shared.businessUnits} contact={shared.contact}>
        <p className="eyebrow">Not configured</p>
        <h1 className="display-section mt-4 text-ink-950">Database not connected</h1>
      </Shell>
    );
  }

  const { data: unit } = await supabase
    .from("business_units")
    .select("*")
    .eq("slug", slug)
    .eq("public_visible", true)
    .eq("is_active", true)
    .is("deleted_at", null)
    .maybeSingle();

  if (!unit) notFound();

  const [{ data: page }, navPages, shared] = await Promise.all([
    supabase
      .from("website_pages")
      .select("*")
      .eq("slug", `businesses/${unit.slug}`)
      .eq("status", "published")
      .is("deleted_at", null)
      .maybeSingle(),
    getNavPages(),
    getSharedContent(),
  ]);

  const accent = unit.accent_color ?? "var(--color-bronze-500)";

  return (
    <Shell navPages={navPages} units={shared.businessUnits} contact={shared.contact}>
      {/* Sector page header. The accent is the unit's own colour from the
          database, applied only here — it never overrides the brand palette. */}
      <section className="relative overflow-hidden border-b border-hairline bg-ink-950 text-canvas">
        <div
          aria-hidden
          className="absolute inset-y-0 left-0 w-1.5"
          style={{ backgroundColor: accent }}
        />
        <div className="container-page py-20 md:py-28">
          <p className="eyebrow eyebrow-on-dark">{unit.code}</p>
          <h1 className="display-hero mt-5 max-w-3xl text-canvas">{unit.name}</h1>
          {unit.tagline && (
            <p className="mt-6 max-w-2xl font-display text-xl leading-snug text-bronze-200">
              {unit.tagline}
            </p>
          )}
          <div className="mt-9 flex flex-wrap gap-3">
            <Link href="/contact" className="btn btn-accent btn-lg">
              Enquire about this business
            </Link>
            <Link href="/businesses" className="btn btn-outline-on-dark btn-lg">
              All businesses
            </Link>
          </div>
        </div>
      </section>

      {unit.summary && (
        <section className="section-y">
          <div className="container-page">
            <div className="grid gap-12 lg:grid-cols-12 lg:gap-20">
              <div className="lg:col-span-7">
                <h2 className="display-section text-ink-950">Overview</h2>
                <div className="prose-phg mt-7">
                  {(unit.description ?? unit.summary)
                    .split(/\n{2,}/)
                    .map((para, i) => (
                      <p key={i}>{para}</p>
                    ))}
                </div>
              </div>

              <aside className="lg:col-span-5">
                <dl className="surface-card divide-y divide-hairline">
                  {unit.legal_entity && (
                    <Row label="Legal entity" value={unit.legal_entity} />
                  )}
                  {unit.registration_number && (
                    <Row label="Registration" value={unit.registration_number} />
                  )}
                  {unit.established_on && (
                    <Row
                      label="Established"
                      value={new Date(unit.established_on).getFullYear().toString()}
                    />
                  )}
                  <Row label="Reference" value={unit.code} />
                </dl>

                <div className="mt-8 rounded-lg border border-hairline bg-surface-muted p-6">
                  <p className="text-sm leading-relaxed text-ink-600">
                    Enquiries for this business are handled by the group relationship
                    team. One point of contact, rather than a queue of departments.
                  </p>
                  <Link href="/contact" className="btn btn-outline btn-md mt-5">
                    Start a conversation
                  </Link>
                </div>
              </aside>
            </div>
          </div>
        </section>
      )}

      {page?.subtitle && (
        <section className="border-t border-hairline bg-surface-muted py-12">
          <div className="container-page">
            <p className="lede max-w-3xl">{page.subtitle}</p>
          </div>
        </section>
      )}
    </Shell>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4 p-4">
      <dt className="text-2xs font-semibold uppercase tracking-[0.14em] text-ink-500">
        {label}
      </dt>
      <dd className="tabular text-right text-sm text-ink-900">{value}</dd>
    </div>
  );
}

function Shell({
  navPages,
  units,
  contact,
  children,
}: {
  navPages: Awaited<ReturnType<typeof getNavPages>>;
  units: Awaited<ReturnType<typeof getSharedContent>>["businessUnits"];
  contact?: PublicContact | null;
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-dvh flex-col bg-canvas">
      <SiteHeader navPages={navPages} businessUnits={units} />
      <main className="flex-1">{children}</main>
      <SiteFooter businessUnits={units} contact={contact} />
    </div>
  );
}
