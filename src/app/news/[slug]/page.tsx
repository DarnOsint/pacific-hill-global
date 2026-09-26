import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { SiteFooter, SiteHeader } from "@/components/marketing/site-chrome";
import { getNavPages, getSharedContent } from "@/lib/cms";
import { createPublicClient } from "@/lib/supabase/server";

export const revalidate = 300;

type Post = {
  id: string;
  slug: string;
  title: string;
  excerpt: string | null;
  body: string | null;
  category: string | null;
  published_at: string | null;
  author_name: string | null;
  read_minutes: number | null;
};

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const supabase = createPublicClient();
  if (!supabase) return { title: "News" };

  const { data } = await supabase
    .from("news_posts")
    .select("title, excerpt")
    .eq("slug", slug)
    .eq("status", "published")
    .is("deleted_at", null)
    .maybeSingle();

  if (!data) return { title: "News" };
  return { title: data.title, description: data.excerpt ?? undefined };
}

export default async function NewsPostPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const supabase = createPublicClient();
  const [navPages, shared] = await Promise.all([getNavPages(), getSharedContent()]);

  const { data } = supabase
    ? await supabase
        .from("news_posts")
        .select("*")
        .eq("slug", slug)
        .eq("status", "published")
        .is("deleted_at", null)
        .maybeSingle()
    : { data: null };

  if (!supabase || !data) notFound();

  const post = data as Post;

  return (
    <div className="flex min-h-dvh flex-col bg-canvas">
      <SiteHeader navPages={navPages} businessUnits={shared.businessUnits} />

      <main className="flex-1">
        <article className="section-y">
          <div className="container-narrow">
            <Link
              href="/news"
              className="text-xs font-semibold uppercase tracking-[0.14em] text-ink-500 transition-colors hover:text-ink-900"
            >
              ← All updates
            </Link>

            <div className="mt-8 flex flex-wrap items-center gap-3 text-2xs font-semibold uppercase tracking-[0.14em] text-ink-500">
              {post.category && <span className="text-bronze-700">{post.category}</span>}
              {post.published_at && (
                <time dateTime={post.published_at} className="tabular">
                  {new Date(post.published_at).toLocaleDateString("en-GB", {
                    day: "numeric",
                    month: "long",
                    year: "numeric",
                  })}
                </time>
              )}
            </div>

            <h1 className="display-hero mt-5 text-ink-950">{post.title}</h1>

            {post.excerpt && <p className="lede mt-6">{post.excerpt}</p>}

            <div className="mt-8 flex items-center gap-4 border-y border-hairline py-4 text-xs text-ink-500">
              {post.author_name && <span>By {post.author_name}</span>}
              {post.read_minutes ? (
                <span className="tabular">{post.read_minutes} min read</span>
              ) : null}
            </div>

            {post.body && (
              <div className="prose-phg mt-10 text-base">
                {post.body.split(/\n{2,}/).map((para, i) => (
                  <p key={i}>{para}</p>
                ))}
              </div>
            )}
          </div>
        </article>
      </main>

      <SiteFooter businessUnits={shared.businessUnits} contact={shared.contact} />
    </div>
  );
}
