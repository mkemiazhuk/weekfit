"use client";

import { useI18n } from "@/lib/i18n";
import PageHero from "../PageHero";
import Icon from "../Icon";
import Reveal from "../Reveal";
import { blogCategories, blogCopy } from "@/lib/blog";

export default function BlogView() {
  const { lang } = useI18n();
  const c = blogCopy[lang];

  return (
    <>
      <PageHero kicker={c.kicker} kickerColor="#66bc87" title={c.title} lead={c.lead} />

      <div className="mx-auto max-w-5xl px-6 pb-28">
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
