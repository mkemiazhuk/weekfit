"use client";

import Link from "next/link";
import { useI18n } from "@/lib/i18n";
import { blogCategories, blogCopy, type BlogPost } from "@/lib/blog";
import DocArticle from "./DocArticle";

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
    <article className="mx-auto max-w-3xl px-6 pb-28 pt-32 md:pt-36">
      <Link
        href={localePath("/blog")}
        className="text-[14px] font-medium text-white/50 transition-colors hover:text-white"
      >
        ← {c.kicker}
      </Link>

      <div className="mt-6 flex flex-wrap items-center gap-2 text-[12px] font-semibold uppercase tracking-[0.12em] text-white/40">
        {cat && <span style={{ color: cat.color }}>{cat.name[lang]}</span>}
        <span aria-hidden>·</span>
        <time dateTime={post.date}>{formatDate(post.date, lang)}</time>
        <span aria-hidden>·</span>
        <span>
          {post.readMinutes} {c.readMin}
        </span>
      </div>

      <h1 className="display mt-5 text-[clamp(2rem,5vw,2.75rem)] leading-[1.08] text-white">
        {post.title[lang]}
      </h1>
      <p className="mt-4 text-[17px] leading-relaxed text-white/60">{post.excerpt[lang]}</p>

      <div className="prose mt-10">
        <DocArticle sections={post.sections[lang]} />
      </div>
    </article>
  );
}
