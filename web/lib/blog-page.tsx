import { notFound } from "next/navigation";
import BlogArticleView from "@/components/pages/BlogArticleView";
import JsonLd from "@/components/JsonLd";
import {
  blogPostPath,
  blogStaticParams,
  getBlogPost,
} from "@/lib/blog";
import { pageMetadata } from "@/lib/seo";
import { blogPostingSchema, breadcrumbSchema } from "@/lib/schema";
import { breadcrumbHome } from "@/lib/page-factory";
import type { Locale } from "@/lib/locale";

export function generateStaticParams() {
  return blogStaticParams();
}

function buildArticlePage(locale: Locale, params: { category: string; slug: string }) {
  const post = getBlogPost(params.category, params.slug);
  if (!post) notFound();

  const path = blogPostPath(post);
  const title = post.title[locale];

  return (
    <>
      <JsonLd
        data={[
          blogPostingSchema({
            path,
            headline: title,
            description: post.excerpt[locale],
            datePublished: post.date,
            locale,
          }),
          breadcrumbSchema(
            [
              { name: breadcrumbHome(locale), path: "/" },
              { name: locale === "ru" ? "Блог" : "Blog", path: "/blog" },
              { name: title, path },
            ],
            locale
          ),
        ]}
      />
      <BlogArticleView post={post} />
    </>
  );
}

export function buildArticleMetadata(
  locale: Locale,
  params: { category: string; slug: string }
) {
  const post = getBlogPost(params.category, params.slug);
  if (!post) return {};
  return pageMetadata({
    path: blogPostPath(post),
    locale,
    title: post.title[locale],
    description: post.excerpt[locale],
  });
}

export function BlogArticleRoute({
  locale,
  params,
}: {
  locale: Locale;
  params: { category: string; slug: string };
}) {
  return buildArticlePage(locale, params);
}
