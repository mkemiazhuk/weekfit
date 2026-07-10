import {
  BlogCategoryRoute,
  buildCategoryMetadata,
  generateBlogCategoryStaticParams,
  resolveBlogCategoryParams,
} from "@/lib/blog-category-page";

export function generateStaticParams() {
  return generateBlogCategoryStaticParams();
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ category: string }>;
}) {
  const resolved = await resolveBlogCategoryParams(params);
  return buildCategoryMetadata("ru", resolved);
}

export default async function Page({
  params,
}: {
  params: Promise<{ category: string }>;
}) {
  const resolved = await resolveBlogCategoryParams(params);
  return <BlogCategoryRoute locale="ru" params={resolved} />;
}
