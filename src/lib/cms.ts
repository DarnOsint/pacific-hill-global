import "server-only";

import { cache } from "react";

import { createPublicClient } from "@/lib/supabase/server";
import type {
  BusinessUnitRow,
  CompanyStatisticRow,
  Json,
  NewsPostRow,
  TestimonialRow,
  WebsitePageRow,
  WebsiteSectionRow,
} from "@/types/database";

/**
 * Read side of the public website.
 *
 * Every string a visitor sees on the marketing site comes from the database, not
 * from a component. That is deliberate: the group edits copy, section order and
 * visibility from the admin surface, and a deploy should never be required to
 * change a headline.
 *
 * Two rules govern everything here:
 *
 * 1. **Degrade, never crash.** `createPublicClient()` returns null when Supabase
 *    is not configured. This module must therefore be able to answer "no content"
 *    so that a clean checkout still builds and renders. It never throws.
 *
 * 2. **Only published, non-deleted rows.** Filtering happens in the query rather
 *    than in JS so that a draft can never reach a visitor even if a caller
 *    forgets to filter. RLS backs this up, but the anon role is granted read
 *    access to the published CMS tables, so the predicate has to be explicit.
 */

export type SectionContent = Record<string, unknown>;

/** A section as the renderer needs it: row fields plus a guaranteed object. */
export type CmsSection = WebsiteSectionRow & {
  content: SectionContent;
};

/**
 * Publishable contact/branding details, projected by `public.public_contact`.
 *
 * Sourced from a dedicated view rather than `company_settings` because that
 * table also holds the tax number, registration number, base currency and
 * feature flags, and is permission-gated to `settings.view` — so the anon key
 * cannot read it at all.
 */
export type PublicContact = {
  company_name: string | null;
  legal_name: string | null;
  tagline: string | null;
  description: string | null;
  founded_year: number | null;
  email: string | null;
  phone: string | null;
  whatsapp: string | null;
  address: string | null;
  city: string | null;
  country: string | null;
  logo_url: string | null;
  social_links: Json;
};

/** A department as published on the public org chart. */
export type PublicOrgUnit = {
  id: string;
  code: string;
  name: string;
  description: string | null;
  parent_code: string | null;
  sort_order: number;
};

export type HomeContent = {
  page: WebsitePageRow | null;
  sections: CmsSection[];
  businessUnits: BusinessUnitRow[];
  statistics: CompanyStatisticRow[];
  testimonials: TestimonialRow[];
  news: NewsPostRow[];
  contact: PublicContact | null;
  orgUnits: PublicOrgUnit[];
  /** True when the database could not be reached, so callers can say so. */
  unavailable: boolean;
};

/**
 * Content shared by every marketing page: the sector rail, public statistics,
 * testimonials and the latest news.
 *
 * Split out from `getHomeContent` because the header, the footer and inner pages
 * all need it, and `cache()` means it is still one set of queries per render
 * pass no matter how many components ask.
 */
export type SharedContent = Pick<
  HomeContent,
  "businessUnits" | "statistics" | "testimonials" | "news" | "contact" | "orgUnits"
>;

const EMPTY: SharedContent = {
  businessUnits: [],
  statistics: [],
  testimonials: [],
  news: [],
  contact: null,
  orgUnits: [],
};

export const getSharedContent = cache(async (): Promise<SharedContent> => {
  const supabase = createPublicClient();
  if (!supabase) return EMPTY;

  const [unitsRes, statsRes, testimonialsRes, newsRes, contactRes, orgRes] = await Promise.all([
    supabase
      .from("business_units")
      .select("*")
      .eq("public_visible", true)
      .eq("is_active", true)
      .is("deleted_at", null)
      .order("sort_order", { ascending: true }),
    supabase
      .from("company_statistics")
      .select("*")
      .eq("is_public", true)
      .is("deleted_at", null)
      .order("sort_order", { ascending: true }),
    supabase
      .from("testimonials")
      .select("*")
      .eq("status", "published")
      .is("deleted_at", null)
      .order("sort_order", { ascending: true }),
    supabase
      .from("news_posts")
      .select("*")
      .eq("status", "published")
      .is("deleted_at", null)
      .order("published_at", { ascending: false })
      .limit(3),
    // `public_contact` is a single-row projection; `.limit(1)` keeps the
    // loader's shape identical to every other content source above.
    supabase.from("public_contact").select("*").limit(1).maybeSingle(),
    supabase.from("public_org_units").select("*").order("sort_order", { ascending: true }),
  ]);

  return {
    businessUnits: unitsRes.data ?? [],
    statistics: statsRes.data ?? [],
    testimonials: testimonialsRes.data ?? [],
    news: newsRes.data ?? [],
    contact: contactRes.data,
    orgUnits: orgRes.data ?? [],
  };
});

/**
 * WhatsApp digits in the form `wa.me` expects: digits only, no `+`, no spaces.
 *
 * The number is published with spaces for legibility, so it cannot be pasted
 * into a URL unchanged. Returns null when there is no usable number, which lets
 * callers omit the channel entirely rather than render a dead link.
 */
export function whatsappDigits(whatsapp: string | null | undefined): string | null {
  if (!whatsapp) return null;
  const digits = whatsapp.replace(/\D/g, "");
  return digits.length >= 8 && digits.length <= 15 ? digits : null;
}

/* -------------------------------------------------------------------------- */
/* Narrowing helpers                                                           */
/* -------------------------------------------------------------------------- */

function str(v: unknown): string | undefined {
  return typeof v === "string" && v.length > 0 ? v : undefined;
}

function num(v: unknown): number | undefined {
  return typeof v === "number" && Number.isFinite(v) ? v : undefined;
}

function arr(v: unknown): unknown[] {
  return Array.isArray(v) ? v : [];
}

function obj(v: unknown): SectionContent {
  return v && typeof v === "object" && !Array.isArray(v)
    ? (v as SectionContent)
    : {};
}

/**
 * `content` is jsonb, so normalise the case where the driver hands back null.
 *
 * The cast is needed because `CmsSection` intersects the row type (whose
 * `content` is the recursive `Json` union) with a guaranteed-object shape. The
 * value has already been through `obj()`, so it really is a plain object; the
 * union is only imprecise at the type level.
 */
function toSection(row: WebsiteSectionRow): CmsSection {
  return { ...row, content: obj(row.content) as CmsSection["content"] };
}

/* -------------------------------------------------------------------------- */
/* Queries                                                                     */
/* -------------------------------------------------------------------------- */

/**
 * Everything the marketing homepage renders, in one round trip.
 *
 * `cache()` deduplicates this across a single render pass, so calling
 * `getHomeContent()` from the page, the header and the footer costs one set of
 * queries rather than three.
 */
export const getHomeContent = cache(async (): Promise<HomeContent> => {
  const supabase = createPublicClient();

  if (!supabase) {
    return { page: null, sections: [], ...EMPTY, unavailable: true };
  }

  const [shared, pageRes] = await Promise.all([
    getSharedContent(),
    supabase
      .from("website_pages")
      .select("*")
      .eq("slug", "homepage")
      .eq("status", "published")
      .is("deleted_at", null)
      .maybeSingle(),
  ]);

  // A failed lookup must not take the page down with it: the remaining sections
  // still render, and the caller decides whether an absent page is a 404.
  const page = pageRes.error ? null : pageRes.data;
  if (!page) return { page: null, sections: [], ...shared, unavailable: false };

  return {
    page,
    sections: await loadSections(supabase, page.id),
    ...shared,
    unavailable: false,
  };
});

/**
 * A CMS page and its ordered, visible sections.
 *
 * Returns null when the page does not exist or is not published. The caller
 * decides whether that is a 404 or an unconfigured-deployment notice.
 */
export const getCmsPage = cache(
  async (slug: string): Promise<{ page: WebsitePageRow; sections: CmsSection[] } | null> => {
    const supabase = createPublicClient();
    if (!supabase) return null;

    const { data: page, error } = await supabase
      .from("website_pages")
      .select("*")
      .eq("slug", slug)
      .eq("status", "published")
      .is("deleted_at", null)
      .maybeSingle();

    if (error || !page) return null;

    return { page, sections: await loadSections(supabase, page.id) };
  },
);

/** Published pages that opted into the primary navigation. */
export const getNavPages = cache(async (): Promise<WebsitePageRow[]> => {
  const supabase = createPublicClient();
  if (!supabase) return [];

  const { data } = await supabase
    .from("website_pages")
    .select("*")
    .eq("status", "published")
    .eq("show_in_nav", true)
    .is("deleted_at", null)
    .order("nav_order", { ascending: true });

  return data ?? [];
});

type Supabase = NonNullable<ReturnType<typeof createPublicClient>>;

async function loadSections(supabase: Supabase, pageId: string): Promise<CmsSection[]> {
  const { data } = await supabase
    .from("website_sections")
    .select("*")
    .eq("page_id", pageId)
    .eq("is_visible", true)
    .is("deleted_at", null)
    .order("sort_order", { ascending: true });

  return (data ?? []).map(toSection);
}

/* -------------------------------------------------------------------------- */
/* Typed accessors for individual section shapes                               */
/* -------------------------------------------------------------------------- */

export type HeroContent = {
  kicker?: string;
  lead?: string;
  image?: string;
  imageAlt?: string;
  summary?: string;
  stats: Array<{ label: string; value: string }>;
};

export function readHero(content: SectionContent): HeroContent {
  return {
    kicker: str(content.kicker),
    lead: str(content.lead),
    image: str(content.image),
    imageAlt: str(content.imageAlt),
    summary: str(content.summary),
    stats: arr(content.stats)
      .map((s) => {
        const o = obj(s);
        const label = str(o.label);
        const value = str(o.value);
        return label && value ? { label, value } : null;
      })
      .filter((s): s is { label: string; value: string } => s !== null),
  };
}

export type FeatureItem = { title: string; body: string };

/** Parse a list of `{title, body}` objects out of an unknown jsonb value. */
function readList(value: unknown): FeatureItem[] {
  return arr(value)
    .map((s) => {
      const o = obj(s);
      const title = str(o.title);
      const body = str(o.body);
      return title && body ? { title, body } : null;
    })
    .filter((s): s is FeatureItem => s !== null);
}

export function readItems(content: SectionContent): FeatureItem[] {
  return readList(content.items);
}

export type Pillar = FeatureItem;

/**
 * The introduction section stores its three principles under `pillars`, not
 * `items` (which belongs to the feature list). Reading the wrong key silently
 * rendered the block empty, so the key is asserted here.
 */
export function readPillars(content: SectionContent): Pillar[] {
  return readList(content.pillars);
}

export type ProseContent = {
  lead?: string;
  body?: string;
  summary?: string;
};

export function readProse(content: SectionContent): ProseContent {
  return {
    lead: str(content.lead),
    body: str(content.body),
    summary: str(content.summary),
  };
}

export type StatValue = {
  label: string;
  value: string;
  prefix?: string;
  suffix?: string;
};

export function readStatValue(
  stat: CompanyStatisticRow | undefined,
): StatValue | null {
  if (!stat) return null;
  const label = str(stat.label);
  if (!label) return null;
  return {
    label,
    value: str(stat.value) ?? "—",
    prefix: str(stat.prefix),
    suffix: str(stat.suffix),
  };
}

export function newsLimit(content: SectionContent, fallback = 3): number {
  return num(content.limit) ?? fallback;
}
