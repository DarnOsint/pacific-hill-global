import Link from "next/link";

import {
  type CmsSection,
  type SharedContent,
  type StatValue,
  readHero,
  readItems,
  readPillars,
  readProse,
  readStatValue,
} from "@/lib/cms";
import { whatsappDigits } from "@/lib/cms";
import { cmsHref } from "@/lib/utils";
import type { BusinessUnitRow, NewsPostRow, TestimonialRow } from "@/types/database";

/**
 * Marketing section renderers.
 *
 * Each `website_sections.section_type` maps to exactly one component. The page
 * itself knows nothing about layout — it iterates rows in `sort_order` and hands
 * each to this registry. That is what lets the CMS reorder or hide a section
 * without a deploy.
 *
 * Unknown section types render nothing rather than throwing: an editor can add a
 * section type ahead of its renderer, and a missing renderer should degrade the
 * page, not break it.
 */

/* -------------------------------------------------------------------------- */
/* Shared pieces                                                               */
/* -------------------------------------------------------------------------- */

function Eyebrow({ children, onDark }: { children: string; onDark?: boolean }) {
  return (
    <p className={`eyebrow ${onDark ? "eyebrow-on-dark" : ""}`}>{children}</p>
  );
}

/** Paragraph text stored in jsonb, with blank-line separation preserved. */
function Prose({ text, className = "" }: { text?: string; className?: string }) {
  if (!text) return null;
  return (
    <div className={`prose-phg ${className}`}>
      {text.split(/\n{2,}/).map((para, i) => (
        <p key={i}>{para}</p>
      ))}
    </div>
  );
}

function SectionHeading({
  eyebrow,
  heading,
  subheading,
  onDark,
  align = "left",
}: {
  eyebrow?: string | null;
  heading?: string | null;
  subheading?: string | null;
  onDark?: boolean;
  align?: "left" | "center";
}) {
  if (!eyebrow && !heading && !subheading) return null;
  return (
    <div className={align === "center" ? "mx-auto max-w-2xl text-center" : "max-w-2xl"}>
      {eyebrow && (
        <div className={align === "center" ? "flex justify-center" : ""}>
          <Eyebrow onDark={onDark}>{eyebrow}</Eyebrow>
        </div>
      )}
      {heading && (
        <h2 className={`display-section mt-4 ${onDark ? "text-canvas" : "text-ink-950"}`}>
          {heading}
        </h2>
      )}
      {subheading && (
        <p
          className={`lede mt-4 ${onDark ? "text-ink-200" : ""} ${
            align === "center" ? "mx-auto" : ""
          }`}
        >
          {subheading}
        </p>
      )}
    </div>
  );
}

function Actions({
  primary,
  secondary,
  onDark,
}: {
  primary?: { label?: string | null; href?: string | null } | null;
  secondary?: { label?: string | null; href?: string | null } | null;
  onDark?: boolean;
}) {
  const pLabel = primary?.label;
  const sLabel = secondary?.label;
  if (!pLabel && !sLabel) return null;

  return (
    <div className="mt-9 flex flex-wrap items-center gap-3">
      {pLabel && (
        <Link
          href={cmsHref(primary?.href, "/contact")}
          className={`btn btn-lg ${onDark ? "btn-accent" : "btn-primary"}`}
        >
          {pLabel}
        </Link>
      )}
      {sLabel && (
        <Link
          href={cmsHref(secondary?.href, "/contact")}
          className={`btn btn-lg ${onDark ? "btn-outline-on-dark" : "btn-outline"}`}
        >
          {sLabel}
        </Link>
      )}
    </div>
  );
}

function SectionShell({
  section,
  onDark,
  children,
  className = "",
}: {
  section: CmsSection;
  onDark?: boolean;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <section
      className={`section-y ${onDark ? "bg-ink-950 text-canvas" : ""} ${className}`}
      aria-labelledby={section.heading ? `${section.section_key}-heading` : undefined}
    >
      <div className="container-page">{children}</div>
    </section>
  );
}

/* -------------------------------------------------------------------------- */
/* 1. Hero                                                                     */
/* -------------------------------------------------------------------------- */

function HeroSection({ section }: { section: CmsSection }) {
  const hero = readHero(section.content);

  return (
    <section className="relative overflow-hidden bg-ink-950 text-canvas">
      {/* Hairline grid: depth from structure, not from a gradient wash. */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 opacity-[0.07]"
        style={{
          backgroundImage:
            "linear-gradient(to right, #fff 1px, transparent 1px), linear-gradient(to bottom, #fff 1px, transparent 1px)",
          backgroundSize: "72px 72px",
        }}
      />

      <div className="container-page relative">
        <div className="grid items-center gap-14 py-24 md:py-32 lg:grid-cols-12 lg:gap-16 lg:py-40">
          <div className="lg:col-span-7">
            {hero.kicker && <Eyebrow onDark>{hero.kicker}</Eyebrow>}

            <h1 className="display-hero mt-6 text-canvas">{section.heading}</h1>

            {section.subheading && (
              <p className="mt-6 max-w-2xl font-display text-xl leading-snug text-bronze-200 sm:text-2xl">
                {section.subheading}
              </p>
            )}

            {hero.lead && (
              <p className="lede mt-6 max-w-xl text-ink-300">{hero.lead}</p>
            )}

            <Actions
              onDark
              primary={{ label: section.cta_label, href: section.cta_href }}
              secondary={{
                label: section.secondary_cta_label,
                href: section.secondary_cta_href,
              }}
            />
          </div>

          {hero.stats.length > 0 && (
            <div className="lg:col-span-5 lg:pl-8">
              <dl className="grid grid-cols-2 gap-px overflow-hidden rounded-lg border border-white/10 bg-white/10">
                {hero.stats.map((stat) => (
                  <div key={stat.label} className="bg-ink-950 p-6">
                    <dt className="text-2xs font-semibold uppercase tracking-[0.14em] text-ink-400">
                      {stat.label}
                    </dt>
                    <dd className="tabular mt-2.5 font-display text-3xl text-canvas sm:text-4xl">
                      {stat.value}
                    </dd>
                  </div>
                ))}
              </dl>
            </div>
          )}
        </div>
      </div>
    </section>
  );
}

/* -------------------------------------------------------------------------- */
/* 2. Prose / introduction                                                     */
/* -------------------------------------------------------------------------- */

function ProseSection({ section, onDark }: { section: CmsSection; onDark?: boolean }) {
  const prose = readProse(section.content);
  const pillars = readPillars(section.content);

  return (
    <SectionShell section={section} onDark={onDark}>
      <div className="grid gap-14 lg:grid-cols-12 lg:gap-20">
        <div className="lg:col-span-5">
          <SectionHeading
            eyebrow={section.eyebrow}
            heading={section.heading}
            subheading={section.subheading}
            onDark={onDark}
          />
          <Actions
            onDark={onDark}
            secondary={{
              label: section.secondary_cta_label,
              href: section.secondary_cta_href,
            }}
            primary={{ label: section.cta_label, href: section.cta_href }}
          />
        </div>

        <div className="lg:col-span-7">
          {prose.lead && (
            <p
              className={`font-display text-xl leading-relaxed sm:text-2xl ${
                onDark ? "text-canvas" : "text-ink-900"
              }`}
            >
              {prose.lead}
            </p>
          )}
          <Prose
            text={prose.body}
            className={`mt-7 ${onDark ? "text-ink-300" : ""}`}
          />

          {pillars.length > 0 && (
            <dl className="mt-12 grid gap-8 sm:grid-cols-3">
              {pillars.map((pillar) => (
                <div key={pillar.title} className="border-t-2 border-bronze-500 pt-5">
                  <dt
                    className={`font-display text-lg ${onDark ? "text-canvas" : "text-ink-950"}`}
                  >
                    {pillar.title}
                  </dt>
                  <dd
                    className={`mt-2.5 text-sm leading-relaxed ${
                      onDark ? "text-ink-300" : "text-ink-600"
                    }`}
                  >
                    {pillar.body}
                  </dd>
                </div>
              ))}
            </dl>
          )}
        </div>
      </div>
    </SectionShell>
  );
}

/* -------------------------------------------------------------------------- */
/* 3. Business grid                                                            */
/* -------------------------------------------------------------------------- */

function BusinessGridSection({
  section,
  units,
  onDark,
}: {
  section: CmsSection;
  units: BusinessUnitRow[];
  onDark?: boolean;
}) {
  if (units.length === 0) return null;

  return (
    <SectionShell section={section} onDark={onDark}>
      <div className="flex flex-col gap-8 md:flex-row md:items-end md:justify-between">
        <SectionHeading
          eyebrow={section.eyebrow}
          heading={section.heading}
          subheading={section.subheading}
          onDark={onDark}
        />
        {section.cta_label && (
          <Link
            href={cmsHref(section.cta_href, "/businesses")}
            className={`btn shrink-0 ${onDark ? "btn-outline-on-dark" : "btn-outline"}`}
          >
            {section.cta_label}
          </Link>
        )}
      </div>

      <ul className="mt-14 grid gap-px overflow-hidden rounded-lg border border-hairline bg-hairline sm:grid-cols-2 lg:grid-cols-3">
        {units.map((unit) => (
          <li key={unit.id} className="group bg-surface">
            <Link
              href={cmsHref(`/businesses/${unit.slug}`)}
              className="flex h-full flex-col p-7 transition-colors hover:bg-surface-muted"
            >
              <span
                aria-hidden
                className="size-9 rounded-full"
                style={{
                  backgroundColor: unit.accent_color ?? "var(--color-bronze-500)",
                }}
              />
              <h3 className="mt-6 font-display text-xl text-ink-950">{unit.short_name}</h3>
              <p className="mt-2.5 flex-1 text-sm leading-relaxed text-ink-600">
                {unit.tagline ?? unit.summary}
              </p>
              <span className="mt-6 inline-flex items-center gap-1.5 text-xs font-semibold text-ink-900">
                Learn more
                <span
                  aria-hidden
                  className="transition-transform duration-200 group-hover:translate-x-0.5"
                >
                  →
                </span>
              </span>
            </Link>
          </li>
        ))}
      </ul>
    </SectionShell>
  );
}

/* -------------------------------------------------------------------------- */
/* 4. Feature list ("why work with us")                                        */
/* -------------------------------------------------------------------------- */

function FeatureListSection({ section, onDark }: { section: CmsSection; onDark?: boolean }) {
  const items = readItems(section.content);
  if (items.length === 0) return null;

  return (
    <SectionShell section={section} onDark={onDark}>
      <SectionHeading
        eyebrow={section.eyebrow}
        heading={section.heading}
        subheading={section.subheading}
        onDark={onDark}
      />

      <ul className="mt-14 grid gap-x-12 gap-y-11 sm:grid-cols-2">
        {items.map((item, i) => (
          <li key={item.title} className="flex gap-5">
            <span
              aria-hidden
              className={`tabular mt-1 shrink-0 font-mono text-xs ${
                onDark ? "text-bronze-300" : "text-bronze-600"
              }`}
            >
              {String(i + 1).padStart(2, "0")}
            </span>
            <div>
              <h3 className={`font-display text-xl ${onDark ? "text-canvas" : "text-ink-950"}`}>
                {item.title}
              </h3>
              <p
                className={`mt-2.5 text-sm leading-relaxed ${
                  onDark ? "text-ink-300" : "text-ink-600"
                }`}
              >
                {item.body}
              </p>
            </div>
          </li>
        ))}
      </ul>
    </SectionShell>
  );
}

/* -------------------------------------------------------------------------- */
/* 5. Sector cards                                                             */
/* -------------------------------------------------------------------------- */

function SectorCardsSection({
  section,
  units,
  onDark,
}: {
  section: CmsSection;
  units: BusinessUnitRow[];
  onDark?: boolean;
}) {
  if (units.length === 0) return null;

  return (
    <SectionShell section={section} onDark={onDark}>
      <SectionHeading
        eyebrow={section.eyebrow}
        heading={section.heading}
        subheading={section.subheading}
        onDark={onDark}
      />

      <ul className="mt-14 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        {units.map((unit) => (
          <li key={unit.id}>
            <Link
              href={cmsHref(`/businesses/${unit.slug}`)}
              className={`group flex h-full flex-col border-t-2 pt-6 transition-colors ${
                onDark ? "border-white/15 hover:border-bronze-400" : "border-hairline hover:border-bronze-500"
              }`}
            >
              <div className="flex items-center gap-3">
                <span
                  aria-hidden
                  className="size-2.5 rounded-full"
                  style={{
                    backgroundColor: unit.accent_color ?? "var(--color-bronze-500)",
                  }}
                />
                <span className="text-2xs font-semibold uppercase tracking-[0.14em] text-ink-500">
                  {unit.code}
                </span>
              </div>
              <h3
                className={`mt-4 font-display text-xl ${onDark ? "text-canvas" : "text-ink-950"}`}
              >
                {unit.name}
              </h3>
              <p
                className={`mt-3 flex-1 text-sm leading-relaxed ${
                  onDark ? "text-ink-300" : "text-ink-600"
                }`}
              >
                {unit.summary ?? unit.description}
              </p>
            </Link>
          </li>
        ))}
      </ul>
    </SectionShell>
  );
}

/* -------------------------------------------------------------------------- */
/* 6. Stat strip                                                               */
/* -------------------------------------------------------------------------- */

function StatStripSection({ section, content }: { section: CmsSection; content: SharedContent }) {
  // Prefer the database statistics table: it is editable without a deploy. Fall
  // back to the numbers embedded in the section's own content.
  const fromDb = content.statistics.map(readStatValue).filter((s) => s !== null);
  const fromContent: StatValue[] = readHero(section.content).stats.map((s) => ({
    label: s.label,
    value: s.value,
  }));

  const stats = fromDb.length > 0 ? fromDb : fromContent;
  if (stats.length === 0) return null;

  return (
    <section className="bg-ink-900 py-20 text-canvas">
      <div className="container-page">
        <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div className="max-w-2xl">
            {section.eyebrow && <Eyebrow onDark>{section.eyebrow}</Eyebrow>}
            {section.heading && (
              <h2 className="display-section mt-4 text-canvas">{section.heading}</h2>
            )}
          </div>
          {section.subheading && <p className="lede text-ink-300">{section.subheading}</p>}
        </div>

        <dl className="mt-14 grid gap-10 sm:grid-cols-2 lg:grid-cols-4">
          {stats.map((stat) => (
            <div key={stat.label} className="border-t border-white/15 pt-6">
              <dd className="tabular font-display text-4xl text-canvas sm:text-5xl">
                {stat.prefix}
                {stat.value}
                {stat.suffix}
              </dd>
              <dt className="mt-3 text-2xs font-semibold uppercase tracking-[0.14em] text-ink-400">
                {stat.label}
              </dt>
            </div>
          ))}
        </dl>
      </div>
    </section>
  );
}

/* -------------------------------------------------------------------------- */
/* 7. News list                                                                */
/* -------------------------------------------------------------------------- */

function NewsListSection({ section, content, onDark }: { section: CmsSection; content: SharedContent; onDark?: boolean }) {
  const posts = content.news;
  if (posts.length === 0) return null;

  return (
    <SectionShell section={section} onDark={onDark}>
      <div className="flex flex-col gap-8 md:flex-row md:items-end md:justify-between">
        <SectionHeading
          eyebrow={section.eyebrow}
          heading={section.heading}
          subheading={section.subheading}
          onDark={onDark}
        />
        {section.cta_label && (
          <Link
            href={cmsHref(section.cta_href, "/news")}
            className={`btn shrink-0 ${onDark ? "btn-outline-on-dark" : "btn-outline"}`}
          >
            {section.cta_label}
          </Link>
        )}
      </div>

      <ul className="mt-14 grid gap-10 md:grid-cols-3">
        {posts.map((post) => (
          <NewsCard key={post.id} post={post} onDark={onDark} />
        ))}
      </ul>
    </SectionShell>
  );
}

function NewsCard({ post, onDark }: { post: NewsPostRow; onDark?: boolean }) {
  return (
    <li className="group flex flex-col border-t border-hairline pt-6">
      <div className="flex items-center gap-3 text-2xs font-semibold uppercase tracking-[0.14em] text-ink-500">
        {post.category && <span>{post.category}</span>}
        {post.published_at && (
          <>
            <span aria-hidden className="text-bronze-500">/</span>
            <time dateTime={post.published_at} className="tabular">
              {new Date(post.published_at).toLocaleDateString("en-GB", {
                day: "numeric",
                month: "short",
                year: "numeric",
              })}
            </time>
          </>
        )}
      </div>

      <h3
        className={`mt-4 font-display text-xl leading-snug ${
          onDark ? "text-canvas" : "text-ink-950"
        }`}
      >
        <Link href={cmsHref(`/news/${post.slug}`)} className="transition-colors hover:text-bronze-700">
          {post.title}
        </Link>
      </h3>

      {post.excerpt && (
        <p
          className={`mt-3 flex-1 text-sm leading-relaxed ${
            onDark ? "text-ink-300" : "text-ink-600"
          }`}
        >
          {post.excerpt}
        </p>
      )}

      {post.read_minutes ? (
        <p className="mt-5 text-xs text-ink-500 tabular">{post.read_minutes} min read</p>
      ) : null}
    </li>
  );
}

/* -------------------------------------------------------------------------- */
/* 8. Testimonials                                                             */
/* -------------------------------------------------------------------------- */

function TestimonialsSection({
  section,
  content,
  onDark,
}: {
  section: CmsSection;
  content: SharedContent;
  onDark?: boolean;
}) {
  if (content.testimonials.length === 0) return null;

  return (
    <SectionShell section={section} onDark={onDark}>
      <SectionHeading
        eyebrow={section.eyebrow}
        heading={section.heading}
        subheading={section.subheading}
        onDark={onDark}
      />

      <ul className="mt-14 grid gap-6 md:grid-cols-3">
        {content.testimonials.map((t) => (
          <Testimonial key={t.id} testimonial={t} onDark={onDark} />
        ))}
      </ul>
    </SectionShell>
  );
}

function Testimonial({ testimonial, onDark }: { testimonial: TestimonialRow; onDark?: boolean }) {
  return (
    <li
      className={`flex h-full flex-col border p-7 ${
        onDark ? "border-white/15 bg-white/[0.03]" : "border-hairline bg-surface"
      }`}
    >
      <span aria-hidden className="font-display text-4xl leading-none text-bronze-500">
        &ldquo;
      </span>
      <blockquote
        className={`mt-4 flex-1 font-display text-lg leading-relaxed ${
          onDark ? "text-canvas" : "text-ink-900"
        }`}
      >
        {testimonial.quote}
      </blockquote>
      <footer
        className={`mt-7 border-t pt-4 text-sm ${
          onDark ? "border-white/15" : "border-hairline"
        }`}
      >
        <p className={onDark ? "text-canvas" : "text-ink-950"}>{testimonial.author_name}</p>
        {(testimonial.author_title || testimonial.author_company) && (
          <p className={`mt-1 text-xs ${onDark ? "text-ink-400" : "text-ink-500"}`}>
            {[testimonial.author_title, testimonial.author_company]
              .filter(Boolean)
              .join(" · ")}
          </p>
        )}
      </footer>
    </li>
  );
}

/* -------------------------------------------------------------------------- */
/* 9. Contact call to action                                                   */
/* -------------------------------------------------------------------------- */

function ContactSection({ section, content }: { section: CmsSection; content: SharedContent }) {
  // `content` is the page-wide shared content; the section's own jsonb document
  // is read from `section.content`. The two are different things, hence the
  // explicit names.
  const doc = section.content;
  const channels = Array.isArray(doc.showChannels) ? (doc.showChannels as boolean[]) : [];
  const showChannels = channels.includes(true) || doc.showChannels === true;

  return (
    <section className="section-y bg-ink-950 text-canvas">
      <div className="container-page">
        <div className="grid gap-14 lg:grid-cols-12 lg:gap-20">
          <div className="lg:col-span-7">
            {section.eyebrow && <Eyebrow onDark>{section.eyebrow}</Eyebrow>}
            <h2 className="display-section mt-4 text-canvas">{section.heading}</h2>
            {section.subheading && (
              <p className="mt-5 font-display text-xl leading-snug text-bronze-200">
                {section.subheading}
              </p>
            )}
            {typeof doc.summary === "string" && (
              <p className="lede mt-6 max-w-xl text-ink-300">{doc.summary}</p>
            )}

            <Actions
              onDark
              primary={{ label: section.cta_label, href: section.cta_href ?? "/contact" }}
            />
          </div>

          {showChannels && (
            <div className="lg:col-span-5">
              <ContactChannels content={content} />
            </div>
          )}
        </div>
      </div>
    </section>
  );
}

/**
 * Direct contact channels.
 *
 * WhatsApp is the only phone route: the group does not answer calls, so a
 * `tel:` link is intentionally absent rather than pointing at an unanswered
 * number. The digits are normalised to the form wa.me expects (no spaces, no
 * `+`), which is why the number is written here and not passed through blindly.
 */
function ContactChannels({ content }: { content: SharedContent }) {
  // The database is authoritative; the env var is a build-time fallback so a
  // fresh checkout still shows a working address before the CMS is populated.
  // Hardcoding the number here would silently go stale the first time the
  // Director changed it in settings.
  const email = content.contact?.email ?? process.env.NEXT_PUBLIC_CONTACT_EMAIL ?? null;
  const whatsappDisplay =
    content.contact?.whatsapp ?? process.env.NEXT_PUBLIC_WHATSAPP_NUMBER ?? null;
  const whatsappNumber = whatsappDigits(whatsappDisplay);

  if (!email && !whatsappNumber) return null;

  return (
    <div className="space-y-px overflow-hidden rounded-lg border border-white/10 bg-white/10">
      {email ? (
        <a
          href={`mailto:${email}`}
          className="flex items-center justify-between gap-4 bg-ink-950 p-6 transition-colors hover:bg-ink-900"
        >
          <div>
            <p className="text-2xs font-semibold uppercase tracking-[0.14em] text-ink-400">
              Email
            </p>
            <p className="mt-1.5 text-sm text-canvas">{email}</p>
          </div>
          <span aria-hidden className="text-bronze-400">
            →
          </span>
        </a>
      ) : null}

      {whatsappNumber ? (
        <a
          href={`https://wa.me/${whatsappNumber}`}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center justify-between gap-4 bg-ink-950 p-6 transition-colors hover:bg-ink-900"
        >
          <div>
            <p className="text-2xs font-semibold uppercase tracking-[0.14em] text-ink-400">
              WhatsApp
            </p>
            <p className="tabular mt-1.5 text-sm text-canvas">{whatsappDisplay}</p>
          </div>
          <span aria-hidden className="text-bronze-400">
            →
          </span>
        </a>
      ) : null}
    </div>
  );
}

/**
 * The public org chart, driven by `public.public_org_units`.
 *
 * The seed row for this section carries only a summary, so the structure itself
 * comes from the database rather than being duplicated into jsonb. That keeps
 * the chart correct when a department is renamed in the org module instead of
 * silently disagreeing with the About page.
 */
function OrgStructureSection({ section, content }: { section: CmsSection; content: SharedContent }) {
  const units = content.orgUnits;
  const roots = units.filter((u) => !u.parent_code);
  const childrenOf = (code: string) => units.filter((u) => u.parent_code === code);

  if (roots.length === 0) return null;

  return (
    <SectionShell section={section} className="bg-surface-muted">
      <SectionHeading
        eyebrow={section.eyebrow}
        heading={section.heading}
        subheading={section.subheading}
      />

      <ul className="mt-14 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {roots.map((unit) => (
          <li
            key={unit.id}
            className="rounded-lg border border-hairline bg-surface p-6 transition-colors hover:border-bronze-400"
          >
            <p className="text-2xs font-semibold uppercase tracking-[0.14em] text-bronze-700">
              {unit.code}
            </p>
            <h3 className="mt-2 font-display text-lg text-ink-950">{unit.name}</h3>
            {unit.description ? (
              <p className="mt-2.5 text-sm leading-relaxed text-ink-600">{unit.description}</p>
            ) : null}

            {childrenOf(unit.code).length > 0 ? (
              <ul className="mt-4 space-y-1.5 border-t border-hairline pt-4">
                {childrenOf(unit.code).map((child) => (
                  <li key={child.id} className="flex items-baseline gap-2.5 text-sm text-ink-700">
                    <span aria-hidden className="text-bronze-600">
                      ↳
                    </span>
                    {child.name}
                  </li>
                ))}
              </ul>
            ) : null}
          </li>
        ))}
      </ul>
    </SectionShell>
  );
}

/* -------------------------------------------------------------------------- */
/* Registry                                                                    */
/* -------------------------------------------------------------------------- */

export function MarketingSection({
  section,
  content,
}: {
  section: CmsSection;
  content: SharedContent;
}) {
  const onDark = section.background === "dark";

  switch (section.section_type) {
    case "hero":
      return <HeroSection section={section} />;

    case "prose":
    case "page-hero":
      return <ProseSection section={section} onDark={onDark} />;

    case "business-grid":
      return (
        <BusinessGridSection section={section} units={content.businessUnits} onDark={onDark} />
      );

    case "feature-list":
    // `value-grid` is the same {title, body} list under a different editorial
    // name (it is used on the About page for the values). Sharing the renderer
    // keeps the two visually identical instead of forking the markup.
    case "value-grid":
      return <FeatureListSection section={section} onDark={onDark} />;

    case "sector-cards":
      return (
        <SectorCardsSection section={section} units={content.businessUnits} onDark={onDark} />
      );

    case "stat-strip":
      return <StatStripSection section={section} content={content} />;

    case "news-list":
      return <NewsListSection section={section} content={content} onDark={onDark} />;

    case "testimonials":
      return <TestimonialsSection section={section} content={content} onDark={onDark} />;

    case "org-structure":
      return <OrgStructureSection section={section} content={content} />;

    case "contact":
      return <ContactSection section={section} content={content} />;

    default:
      // An unrecognised section type is a content problem, not a crash. Render
      // nothing and let the rest of the page stand.
      return null;
  }
}
