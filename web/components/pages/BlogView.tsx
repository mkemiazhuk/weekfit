"use client";

import Link from "next/link";
import { useI18n } from "@/lib/i18n";
import {
  blogCategories,
  blogCategoriesWithPosts,
  blogCopy,
  blogPosts,
  blogPostPath,
  type BlogPost,
} from "@/lib/blog";
import PageHero from "../PageHero";
import TopicIcon, { topicIconTileClassName, topicIconTileStyle } from "../TopicIcon";
import Reveal from "../Reveal";

function formatDate(iso: string, lang: "en" | "ru") {
  return new Intl.DateTimeFormat(lang === "ru" ? "ru-RU" : "en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  }).format(new Date(iso));
}

export function PostCard({
  post,
  lang,
  href,
  delay,
  readLabel,
  localePath,
}: {
  post: BlogPost;
  lang: "en" | "ru";
  href: string;
  delay: number;
  readLabel: string;
  localePath: (path: string) => string;
}) {
  const cat = blogCategories.find((c) => c.slug === post.category);
  return (
    <Reveal delay={delay}>
      <article className="premium-card surface-subtle p-6 transition-colors hover:border-white/[0.14]">
        <div className="flex flex-wrap items-center gap-2 text-[12px] font-medium uppercase tracking-[0.12em] text-white/40">
          {cat && (
            <Link
              href={localePath(`/blog/${cat.slug}`)}
              className="rounded-sm transition-colors hover:text-white"
              style={{ color: cat.color }}
            >
              {cat.name[lang]}
            </Link>
          )}
          <span aria-hidden>·</span>
          <time dateTime={post.date}>{formatDate(post.date, lang)}</time>
          <span aria-hidden>·</span>
          <span>
            {post.readMinutes} {readLabel}
          </span>
        </div>
        <Link href={href} className="group mt-3 block">
          <h3 className="text-[20px] font-semibold text-white transition-colors group-hover:text-brand">
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
      </article>
    </Reveal>
  );
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
            <h2 className="kicker mb-5 text-white/40">{c.latestTitle}</h2>
            <div className="grid gap-4">
              {sorted.map((post, i) => (
                <PostCard
                  key={post.slug}
                  post={post}
                  lang={lang}
                  href={localePath(blogPostPath(post))}
                  delay={i * 0.04}
                  readLabel={c.readMin}
                  localePath={localePath}
                />
              ))}
            </div>
          </section>
        )}

        {sorted.length === 0 && (
          <p className="mb-8 text-[15px] text-white/50">{c.empty}</p>
        )}

        <h2 className="kicker mb-6 text-white/40">{c.categoriesTitle}</h2>

        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {blogCategoriesWithPosts().map((cat, i) => {
            const count = blogPosts.filter((p) => p.category === cat.slug).length;
            return (
              <Reveal key={cat.slug} delay={i * 0.04}>
                <Link
                  href={localePath(`/blog/${cat.slug}`)}
                  className="premium-card surface-subtle group block h-full p-6 transition-colors hover:border-white/[0.14]"
                >
                  <span
                    className={topicIconTileClassName(cat.icon, "mb-4 flex h-11 w-11 overflow-visible")}
                    style={topicIconTileStyle(cat.icon, cat.color)}
                  >
                    <TopicIcon icon={cat.icon} color={cat.color} size={22} />
                  </span>
                  <h3 className="text-[17px] font-semibold text-white transition-colors group-hover:text-brand">
                    {cat.name[lang]}
                  </h3>
                  <p className="mt-2 text-[14px] leading-relaxed text-white/55">{cat.desc[lang]}</p>
                  <span className="mt-4 inline-flex items-center gap-1 text-[13px] font-medium text-white/45 group-hover:text-white/72">
                    {count > 0 ? c.viewTopic : c.categoryEmpty}
                    {count > 0 && (
                      <span aria-hidden className="transition-transform group-hover:translate-x-0.5">
                        →
                      </span>
                    )}
                  </span>
                </Link>
              </Reveal>
            );
          })}
        </div>
      </div>
    </>
  );
}
