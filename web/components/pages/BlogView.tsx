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
      <PageHero kicker={c.kicker} kickerColor="#66bc87" title={c.title} lead={c.lead} />

      <div className="mx-auto max-w-5xl px-6 pb-28">
        {sorted.length > 0 && (
          <section className="mb-12">
            <h2 className="mb-5 text-[13px] font-semibold uppercase tracking-[0.14em] text-white/40">
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

        <h2 className="mb-6 text-[13px] font-semibold uppercase tracking-[0.14em] text-white/40">
          {c.categoriesTitle}
        </h2>

        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {blogCategories.map((cat, i) => (
            <Reveal key={cat.slug} delay={i * 0.04}>
              <article
                className="h-full rounded-[20px] border border-white/[0.08] bg-white/[0.03] p-6"
                style={{ boxShadow: `inset 0 1px 0 rgba(255,255,255,0.05)` }}
              >
                <span
                  className="mb-4 flex h-11 w-11 items-center justify-center rounded-[13px]"
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
        className="premium-card group block rounded-[20px] border border-white/[0.08] bg-white/[0.03] p-6 transition-colors hover:border-white/[0.14]"
      >
        <div className="flex flex-wrap items-center gap-2 text-[12px] font-medium uppercase tracking-[0.12em] text-white/40">
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
        <h3 className="mt-3 text-[20px] font-semibold text-white transition-colors group-hover:text-brand">
          {post.title[lang]}
        </h3>
        <p className="mt-2 text-[15px] leading-relaxed text-white/55">{post.excerpt[lang]}</p>
        <span className="mt-4 inline-flex items-center gap-1 text-[14px] font-semibold text-white/70 group-hover:text-white">
          {lang === "ru" ? "Читать" : "Read"}
          <span aria-hidden className="transition-transform group-hover:translate-x-0.5">
            →
          </span>
        </span>
      </Link>
    </Reveal>
  );
}
