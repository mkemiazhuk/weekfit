"use client";

import { useI18n } from "@/lib/i18n";
import { changelog } from "@/lib/content";
import PageHero from "../PageHero";
import Reveal from "../Reveal";
import { pillars } from "@/lib/tokens";

export default function ChangelogView() {
  const { lang } = useI18n();
  const c = changelog[lang];

  const groups = (r: (typeof c.releases)[number]) =>
    [
      { label: c.labels.added, items: r.added, color: pillars.activity },
      { label: c.labels.improved, items: r.improved, color: pillars.hydration },
      { label: c.labels.fixed, items: r.fixed, color: pillars.nutrition },
    ].filter((g) => g.items && g.items.length);

  return (
    <>
      <PageHero kicker={c.kicker} title={c.title} lead={c.lead} />
      <div className="mx-auto max-w-3xl section-x page-pb">
        <div className="relative border-l border-white/10 pl-8">
          {c.releases.map((r) => (
            <Reveal key={r.version}>
              <div className="relative pb-14">
                <span
                  className="absolute -left-[38px] top-1 flex h-5 w-5 items-center justify-center rounded-full"
                  style={{ background: pillars.activity, boxShadow: `0 0 14px ${pillars.activity}88` }}
                />
                <div className="flex flex-wrap items-baseline gap-3">
                  <h2 className="display text-[2rem] text-white">v{r.version}</h2>
                  <span className="text-[13px] text-white/40">{r.date}</span>
                  <span
                    className="rounded-full px-2.5 py-1 text-[11px] font-semibold uppercase tracking-[0.1em]"
                    style={{ background: `${pillars.activity}1f`, color: pillars.activity }}
                  >
                    {r.tag}
                  </span>
                </div>
                <div className="mt-6 space-y-6">
                  {groups(r).map((g) => (
                    <div key={g.label}>
                      <p className="text-[12px] font-bold uppercase tracking-[0.14em]" style={{ color: g.color }}>
                        {g.label}
                      </p>
                      <ul className="mt-2 space-y-1.5">
                        {g.items!.map((it) => (
                          <li key={it} className="flex items-start gap-2.5 text-[15px] text-white/70">
                            <span className="mt-2 h-1.5 w-1.5 flex-none rounded-full" style={{ background: g.color }} />
                            {it}
                          </li>
                        ))}
                      </ul>
                    </div>
                  ))}
                </div>
              </div>
            </Reveal>
          ))}
          <div className="relative">
            <span className="absolute -left-[34px] top-1 h-3 w-3 rounded-full border border-white/20" />
            <p className="text-[15px] italic text-white/45">{c.roadmap}</p>
          </div>
        </div>
      </div>
    </>
  );
}
