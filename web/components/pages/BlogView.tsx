"use client";

import Link from "next/link";
import { useI18n } from "@/lib/i18n";
import {
  blogCategories,
  blogCopy,
  blogPosts,
  blogPostPath,
  type BlogPost,
} from "@/lib/blog";
import PageHero from "../PageHero";
import Icon from "../Icon";
import Reveal from "../Reveal";

function formatDate(iso: string, lang: "en" | "ru") {
  return new Intl.DateTimeFormat(lang === "ru" ? "ru-RU" : "en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  }).format(new Date(iso));
}

export default function BlogView() {
  const { lang, localePath } = useI18n();
  const c = blogCopy[lang];
  const sorted = [...blogPosts].sort(
    (a, b) => new Date(b.date).getTime() - new Date(a.date).getTime()
  );

  return (
    <>
      <PageHero kicker={c.kicker} title={c.title} lead={c.lead} />

      <div className="mx-auto max-w-5xl section-x page-pb">
        {sorted.length > 0 && (
          <section className="mb-12">
            <h2 className="kicker mb-5 text-white/40">
              {c.latestTitle}
            </h2>
            <div className="grid gap-4">
              {sorted.map((post, i) => (
                <PostCard
                  key={post.slug}
                  post={post}
                  lang={lang}
                  href={localePath(blogPostPath(post))}
                  delay={i * 0.04}
                  readLabel={c.readMin}
                />
              ))}
            </div>
          </section>
        )}

        <p className="mb-8 text-[15px] text-white/50">{c.empty}</p>

        <h2 className="kicker mb-6 text-white/40">
          {c.categoriesTitle}
        </h2>

        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {blogCategories.map((cat, i) => (
            <Reveal key={cat.slug} delay={i * 0.04}>
              <article className="surface-subtle h-full p-6">
                <span
                  className="icon-tile mb-4 h-11 w-11"
                  style={{ background: `${cat.color}1f`, border: `1px solid ${cat.color}33` }}
                >
                  <Icon name={cat.icon} color={cat.color} size={22} />
                </span>
                <h3 className="text-[17px] font-semibold text-white">{cat.name[lang]}</h3>
                <p className="mt-2 text-[14px] leading-relaxed text-white/55">
                  {cat.desc[lang]}
                </p>
              </article>
            </Reveal>
          ))}
        </div>
      </div>
    </>
  );
}

function PostCard({
  post,
  lang,
  href,
  delay,
  readLabel,
}: {
  post: BlogPost;
  lang: "en" | "ru";
  href: string;
  delay: number;
  readLabel: string;
}) {
  const cat = blogCategories.find((c) => c.slug === post.category);
  return (
    <Reveal delay={delay}>
      <Link
        href={href}
        className="blog-post-card group block"
      >
        <div className="flex flex-wrap items-center gap-2 text-[12px] font-medium uppercase tracking-[0.1em] text-white/38">
          {cat && (
            <span style={{ color: cat.color }}>{cat.name[lang]}</span>
          )}
          <span aria-hidden>·</span>
          <time dateTime={post.date}>{formatDate(post.date, lang)}</time>
          <span aria-hidden>·</span>
          <span>
            {post.readMinutes} {readLabel}
          </span>
        </div>
        <h3 className="mt-3 text-[19px] font-semibold leading-snug text-white transition-colors group-hover:text-white/92">
          {post.title[lang]}
        </h3>
        <p className="mt-2.5 text-[15px] leading-relaxed text-white/52">{post.excerpt[lang]}</p>
        <span className="mt-4 inline-flex items-center gap-1 text-[14px] font-medium text-white/58 group-hover:text-white/78">
          {lang === "ru" ? "Читать" : "Read"}
          <span aria-hidden className="transition-transform group-hover:translate-x-0.5">
            →
          </span>
        </span>
      </Link>
    </Reveal>
  );
}
