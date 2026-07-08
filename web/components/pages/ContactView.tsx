"use client";

import { useI18n } from "@/lib/i18n";
import { contact } from "@/lib/content";
import PageHero from "../PageHero";
import Button from "../Button";
import Icon from "../Icon";
import { pillars } from "@/lib/tokens";

export default function ContactView() {
  const { lang } = useI18n();
  const c = contact[lang];
  return (
    <>
      <PageHero kicker={c.kicker} kickerColor={pillars.hydration} title={c.title} lead={c.lead} />
      <div className="mx-auto max-w-xl px-6 pb-32">
        <div className="rounded-[26px] glass p-8 text-center">
          <span
            className="mx-auto flex h-12 w-12 items-center justify-center rounded-[14px]"
            style={{ background: `${pillars.hydration}1f`, border: `1px solid ${pillars.hydration}33` }}
          >
            <Icon name="mail" color={pillars.hydration} size={24} />
          </span>
          <h2 className="mt-5 text-[20px] font-semibold text-white">{c.cardTitle}</h2>
          <p className="mt-2 text-white/60">{c.response}</p>
          <div className="mt-6 flex justify-center">
            <Button href="mailto:support@weekfit.app">{c.cta}</Button>
          </div>
        </div>

        <div className="mt-8 rounded-[22px] border border-white/[0.08] p-6">
          <h3 className="text-[14px] font-semibold text-white">{c.includeTitle}</h3>
          <ul className="mt-3 space-y-2">
            {c.include.map((it) => (
              <li key={it} className="flex items-start gap-2 text-[14px] text-white/60">
                <span className="mt-2 h-1.5 w-1.5 flex-none rounded-full" style={{ background: pillars.activity }} />
                {it}
              </li>
            ))}
          </ul>
        </div>
      </div>
    </>
  );
}
