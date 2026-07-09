"use client";

import { useEffect, useMemo, useState } from "react";
import { useI18n } from "@/lib/i18n";
import { support } from "@/lib/content";
import PageHero from "../PageHero";
import Icon from "../Icon";
import FAQAccordion, { QA } from "../FAQAccordion";
import Button from "../Button";

export default function SupportView() {
  const { lang } = useI18n();
  const c = support[lang];
  const [query, setQuery] = useState("");

  // Honor ?q= deep links for shareable filtered FAQ views.
  useEffect(() => {
    const q = new URLSearchParams(window.location.search).get("q");
    if (q) setQuery(q);
  }, []);

  const matches: QA[] = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return [];
    const all = c.categories.flatMap((cat) => cat.faqs);
    return all.filter(
      (f) => f.q.toLowerCase().includes(q) || f.a.toLowerCase().includes(q)
    );
  }, [query, c]);

  return (
    <>
      <PageHero kicker={c.kicker} title={c.title} lead={c.lead}>
        <div className="mx-auto max-w-xl">
          <div className="flex items-center gap-3 rounded-full glass px-5 py-3.5">
            <svg viewBox="0 0 24 24" className="h-5 w-5 flex-none fill-none stroke-white/50" strokeWidth={1.8} aria-hidden>
              <circle cx="11" cy="11" r="7" />
              <path d="M20 20l-3.5-3.5" strokeLinecap="round" />
            </svg>
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={c.search}
              className="w-full bg-transparent text-[15px] text-white placeholder:text-white/40 focus:outline-none"
              aria-label={c.search}
            />
          </div>
        </div>
      </PageHero>

      <div className="mx-auto max-w-3xl section-x page-pb">
        {query.trim() ? (
          matches.length ? (
            <FAQAccordion items={matches} />
          ) : (
            <p className="py-10 text-center text-white/50">{c.noResults}</p>
          )
        ) : (
          <>
            <h2 className="kicker mb-8 text-white/40">
              {c.browse}
            </h2>
            <div className="space-y-12">
              {c.categories.map((cat) => (
                <section key={cat.title}>
                  <div className="mb-4 flex items-center gap-3">
                    <span
                      className="icon-tile"
                      style={{ background: `${cat.color}1f`, border: `1px solid ${cat.color}33` }}
                    >
                      <Icon name={cat.icon} color={cat.color} size={20} />
                    </span>
                    <h3 className="text-[18px] font-semibold text-white">
                      {cat.title}
                    </h3>
                  </div>
                  <FAQAccordion items={cat.faqs} />
                </section>
              ))}
            </div>
          </>
        )}

        <div className="card-panel mt-16 glass text-center">
          <h3 className="text-[20px] font-semibold text-white">
            {c.contactTitle}
          </h3>
          <p className="mx-auto mt-2 max-w-[40ch] text-white/60">
            {c.contactBody}
          </p>
          <div className="mt-6 flex justify-center">
            <Button href="mailto:support@weekfit.app">{c.contactCta}</Button>
          </div>
        </div>
      </div>
    </>
  );
}
