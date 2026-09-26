import Link from "next/link";

import { SiteFooter, SiteHeader } from "@/components/marketing/site-chrome";
import { getNavPages, getSharedContent } from "@/lib/cms";
import { createPublicClient } from "@/lib/supabase/server";

export const revalidate = 300;

type Row = {
  id: string;
  slug: string;
  title: string;
  excerpt: string | null;
  category: string | null;
  published_at: string | null;
  read_minutes: number | null;
};

export default async function NewsPage() {
  const supabase = createPublicClient();
  const [navPages, shared] = await Promise.all([getNavPages(), getSharedContent()]);

  const { data } = supabase
    ? await supabase
        .from("news_posts")
        .select("id, slug, title, excerpt, category, published_at, read_minutes")
        .eq("status", "published")
        .is("deleted_at", null)
        .order("published_at", { ascending: false })
    : { data: null };

  const posts = (data ?? []) as Row[];

  return (
    <div className="flex min-h-dvh flex-col bg-canvas">
      <SiteHeader navPages={navPages} businessUnits={shared.businessUnits} />

      <main className="flex-1">
        <section className="border-b border-hairline bg-surface-muted">
          <div className="container-page section-y">
            <p className="eyebrow">News &amp; updates</p>
            <h1 className="display-hero mt-5 max-w-3xl text-ink-950">
              Recent from the group
            </h1>
            <p className="lede mt-6 max-w-2xl">
              Announcements and updates from across our operating businesses.
            </p>
          </div>
        </section>

        {posts.length === 0 ? (
          <section className="section-y">
            <div className="container-page">
              <p className="lede">Nothing published yet. Please check back shortly.</p>
            </div>
          </section>
        ) : (
          <ul className="container-page divide-y divide-hairline">
            {posts.map((post) => (
              <li key={post.id}>
                <Link
                  href={`/news/${post.slug}`}
                  className="group grid gap-4 py-10 transition-colors md:grid-cols-12 md:gap-10"
                >
                  <div className="md:col-span-3">
                    <div className="flex items-center gap-3 text-2xs font-semibold uppercase tracking-[0.14em] text-ink-500">
                      {post.category && <span className="text-bronze-700">{post.category}</span>}
                    </div>
                    {post.published_at && (
                      <time
                        dateTime={post.published_at}
                        className="tabular mt-2 block text-xs text-ink-500"
                      >
                        {new Date(post.published_at).toLocaleDateString("en-GB", {
                          day: "numeric",
                          month: "short",
                          year: "numeric",
                        })}
                      </time>
                    )}
                  </div>

                  <div className="md:col-span-8">
                    <h2 className="font-display text-2xl leading-snug text-ink-950 transition-colors group-hover:text-bronze-700">
                      {post.title}
                    </h2>
                    {post.excerpt && (
                      <p className="mt-3 text-sm leading-relaxed text-ink-600">
                        {post.excerpt}
                      </p>
                    )}
                  </div>

                  <div className="md:col-span-1 md:text-right">
                    <span
                      aria-hidden
                      className="inline-block text-bronze-600 transition-transform duration-200 group-hover:translate-x-1"
                    >
                      →
                    </span>
                  </div>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </main>

      <SiteFooter businessUnits={shared.businessUnits} contact={shared.contact} />
    </div>
  );
}
