"use client";

import Link from "next/link";
import { useI18n } from "@/lib/i18n";
import { blogCategories, blogCopy, type BlogPost } from "@/lib/blog";
import BlogArticleBody from "./BlogArticleBody";

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

  return (
    <article className="blog-article relative z-[1] mx-auto max-w-[47.5rem] section-x pb-16 pt-28 md:pb-20 md:pt-32">
      <header className="blog-article-header">
        <Link
          href={localePath("/blog")}
          className="blog-article-back text-[14px] font-medium text-white/50 transition-colors hover:text-white/88"
        >
          ← {c.kicker}
        </Link>

        <div className="blog-article-meta mt-4 flex flex-wrap items-center gap-x-2 gap-y-1 text-[12px] font-semibold uppercase tracking-[0.12em] text-white/40">
          {cat && <span style={{ color: cat.color }}>{cat.name[lang]}</span>}
          <span aria-hidden>·</span>
          <time dateTime={post.date}>{formatDate(post.date, lang)}</time>
          <span aria-hidden>·</span>
          <span>
            {post.readMinutes} {c.readMin}
          </span>
        </div>

        <h1 className="blog-article-title display mt-4 text-[clamp(2.125rem,4.8vw,2.875rem)] leading-[1.06] tracking-[-0.032em] text-white">
          {post.title[lang]}
        </h1>
        <p className="blog-article-deck mt-3">{post.excerpt[lang]}</p>
      </header>

      <div className="prose prose-blog mt-8 md:mt-9">
        <BlogArticleBody sections={post.sections[lang]} />
      </div>
    </article>
  );
}
