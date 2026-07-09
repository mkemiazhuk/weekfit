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
  return buildArticleMetadata("en", params);
}

export default function Page({
  params,
}: {
  params: { category: string; slug: string };
}) {
  return <BlogArticleRoute locale="en" params={params} />;
}
