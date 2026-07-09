import {
  BlogArticleRoute,
  buildArticleMetadata,
  generateStaticParams,
  resolveBlogArticleParams,
} from "@/lib/blog-page";

export { generateStaticParams };

export async function generateMetadata({
  params,
}: {
  params: Promise<{ category: string; slug: string }>;
}) {
  const resolved = await resolveBlogArticleParams(params);
  return buildArticleMetadata("ru", resolved);
}

export default async function Page({
  params,
}: {
  params: Promise<{ category: string; slug: string }>;
}) {
  const resolved = await resolveBlogArticleParams(params);
  return <BlogArticleRoute locale="ru" params={resolved} />;
}
