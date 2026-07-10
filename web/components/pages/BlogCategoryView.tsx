"use client";

import Link from "next/link";
import { useI18n } from "@/lib/i18n";
import { blogCopy, type BlogCategory, type BlogPost } from "@/lib/blog";
import PageHero from "../PageHero";
import TopicIcon, { topicIconTileClassName, topicIconTileStyle } from "../TopicIcon";
import { PostCard } from "./BlogView";

export default function BlogCategoryView({
  category,
  posts,
}: {
  category: BlogCategory;
  posts: BlogPost[];
}) {
  const { lang, localePath } = useI18n();
  const c = blogCopy[lang];

  return (
    <>
      <PageHero
        kicker={c.kicker}
        kickerColor={category.color}
        title={category.name[lang]}
        lead={category.desc[lang]}
      />

      <div className="mx-auto max-w-5xl section-x page-pb">
        <Link
          href={localePath("/blog")}
          className="premium-link mb-8 inline-flex items-center gap-2 text-[14px] font-medium text-white/55"
        >
          <span aria-hidden>←</span>
          {c.categoryBack}
        </Link>

        <div className="mb-8 flex items-center gap-3">
          <span
            className={topicIconTileClassName(category.icon, "h-11 w-11 overflow-visible")}
            style={topicIconTileStyle(category.icon, category.color)}
          >
            <TopicIcon icon={category.icon} color={category.color} size={22} />
          </span>
          <p className="text-[14px] text-white/45">
            {posts.length}{" "}
            {lang === "ru"
              ? posts.length === 1
                ? "статья"
                : posts.length < 5
                  ? "статьи"
                  : "статей"
              : posts.length === 1
                ? "article"
                : "articles"}
          </p>
        </div>

        {posts.length > 0 ? (
          <section>
            <h2 className="sr-only">{c.categoryPostsTitle}</h2>
            <div className="grid gap-4">
              {posts.map((post, i) => (
                <PostCard
                  key={post.slug}
                  post={post}
                  lang={lang}
                  href={localePath(`/blog/${post.category}/${post.slug}`)}
                  delay={i * 0.04}
                  readLabel={c.readMin}
                  localePath={localePath}
                />
              ))}
            </div>
          </section>
        ) : (
          <p className="text-[15px] leading-relaxed text-white/55">{c.categoryEmpty}</p>
        )}
      </div>
    </>
  );
}
