import { notFound } from "next/navigation";
import BlogCategoryView from "@/components/pages/BlogCategoryView";
import JsonLd from "@/components/JsonLd";
import {
  blogCategoryPath,
  blogCategoryStaticParams,
  getBlogCategory,
  getBlogPostsByCategory,
} from "@/lib/blog";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbSchema, webPageSchema } from "@/lib/schema";
import { breadcrumbHome } from "@/lib/page-factory";
import type { Locale } from "@/lib/locale";

export type BlogCategoryParams = { category: string };

export function generateBlogCategoryStaticParams() {
  return blogCategoryStaticParams();
}

export async function resolveBlogCategoryParams(
  params: BlogCategoryParams | Promise<BlogCategoryParams>
): Promise<BlogCategoryParams> {
  return Promise.resolve(params);
}

function buildCategoryPage(locale: Locale, params: BlogCategoryParams) {
  const category = getBlogCategory(params.category);
  if (!category) notFound();

  const path = blogCategoryPath(category.slug);
  const name = category.name[locale];
  const description = category.desc[locale];
  const posts = getBlogPostsByCategory(category.slug);

  return (
    <>
      <JsonLd
        data={[
          webPageSchema({
            path,
            name: `${name} — WeekFit Blog`,
            description,
            type: "CollectionPage",
            locale,
          }),
          breadcrumbSchema(
            [
              { name: breadcrumbHome(locale), path: "/" },
              { name: locale === "ru" ? "Блог" : "Blog", path: "/blog" },
              { name, path },
            ],
            locale
          ),
        ]}
      />
      <BlogCategoryView category={category} posts={posts} />
    </>
  );
}

export function buildCategoryMetadata(locale: Locale, params: BlogCategoryParams) {
  const category = getBlogCategory(params.category);
  if (!category) return {};
  return pageMetadata({
    path: blogCategoryPath(category.slug),
    locale,
    title: category.name[locale],
    description: category.desc[locale],
  });
}

export function BlogCategoryRoute({
  locale,
  params,
}: {
  locale: Locale;
  params: BlogCategoryParams;
}) {
  return buildCategoryPage(locale, params);
}
