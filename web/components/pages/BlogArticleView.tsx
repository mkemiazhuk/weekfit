"use client";

import Link from "next/link";
import clsx from "clsx";
import { useI18n } from "@/lib/i18n";
import {
  blogCategories,
  blogCopy,
  blogSectionsToc,
  BLOG_TOC_MIN_SECTIONS,
  type BlogPost,
} from "@/lib/blog";
import BlogArticleBody from "./BlogArticleBody";
import BlogArticleToc from "./BlogArticleToc";
import BlogArticleFooter from "./BlogArticleFooter";

function formatDate(iso: string, lang: "en" | "ru") {
  return new Intl.DateTimeFormat(lang === "ru" ? "ru-RU" : "en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  }).format(new Date(iso));
}

export default function BlogArticleView({ post }: { post: BlogPost }) {
  const { lang, localePath } = useI18n();
  const c = blogCopy[lang];
  const cat = blogCategories.find((item) => item.slug === post.category);
  const sections = post.sections[lang];
  const toc = blogSectionsToc(sections);
  const showToc = toc.length >= BLOG_TOC_MIN_SECTIONS;

  return (
    <article
      className={clsx(
        "blog-article relative z-[1] mx-auto section-x pb-16 pt-28 md:pb-20 md:pt-32",
        showToc && "blog-article--with-toc"
      )}
    >
      <div className={clsx("blog-article-grid", showToc && "blog-article-grid--toc")}>
        <header className="blog-article-header">
          <Link
            href={localePath("/blog")}
            className="blog-article-back text-[14px] font-medium text-white/50 transition-colors hover:text-white/88"
          >
            ← {c.kicker}
          </Link>

          <div className="blog-article-meta flex flex-wrap items-center gap-x-2 gap-y-1 text-[12px] font-semibold uppercase tracking-[0.12em] text-white/40">
            {cat && <span style={{ color: cat.color }}>{cat.name[lang]}</span>}
            <span aria-hidden>·</span>
            <time dateTime={post.date}>{formatDate(post.date, lang)}</time>
            <span aria-hidden>·</span>
            <span>
              {post.readMinutes} {c.readMin}
            </span>
          </div>

          <h1 className="blog-article-title display text-[clamp(2.125rem,4.8vw,2.9375rem)] leading-[1.05] tracking-[-0.034em] text-white">
            {post.title[lang]}
          </h1>
          <p className="blog-article-deck">{post.excerpt[lang]}</p>
        </header>

        {showToc && (
          <div className="blog-article-toc-slot">
            <BlogArticleToc items={toc} title={c.tocTitle} />
          </div>
        )}

        <div className="prose prose-blog blog-article-body">
          <BlogArticleBody sections={sections} />
          <BlogArticleFooter post={post} />
        </div>
      </div>
    </article>
  );
}
