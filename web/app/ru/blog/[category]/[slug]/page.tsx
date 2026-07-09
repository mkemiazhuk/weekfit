import {
  BlogArticleRoute,
  buildArticleMetadata,
  generateStaticParams,
} from "@/lib/blog-page";

export { generateStaticParams };

export function generateMetadata({
  params,
}: {
  params: { category: string; slug: string };
}) {
  return buildArticleMetadata("ru", params);
}

export default function Page({
  params,
}: {
  params: { category: string; slug: string };
}) {
  return <BlogArticleRoute locale="ru" params={params} />;
}
