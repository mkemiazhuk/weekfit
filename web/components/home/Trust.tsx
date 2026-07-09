"use client";

import Reveal from "../Reveal";
import { pillars } from "@/lib/tokens";
import { useI18n } from "@/lib/i18n";
import SectionAmbient from "../SectionAmbient";

function Glyph({ name, color }: { name: string; color: string }) {
  const paths: Record<string, React.ReactNode> = {
    device: <rect x="7" y="2.5" width="10" height="19" rx="2.5" />,
    health: (
      <path d="M12 21s-7-4.35-7-9.5A3.5 3.5 0 0 1 12 8a3.5 3.5 0 0 1 7 3.5C19 16.65 12 21 12 21z" />
    ),
    noads: (
      <>
        <circle cx="12" cy="12" r="9" fill="none" stroke={color} strokeWidth="2" />
        <line x1="6" y1="6" x2="18" y2="18" stroke={color} strokeWidth="2" />
      </>
    ),
    notrack: (
      <>
        <circle cx="12" cy="12" r="3.2" />
        <circle cx="12" cy="12" r="8" fill="none" stroke={color} strokeWidth="2" />
      </>
    ),
  };
  return (
    <svg viewBox="0 0 24 24" className="h-6 w-6" fill={color} stroke="none">
      {paths[name]}
    </svg>
  );
}

export default function Trust() {
  const { t, localePath } = useI18n();

  const items = [
    { key: "device", color: pillars.recovery, ...t.trust.items.device },
    { key: "health", color: pillars.nutrition, ...t.trust.items.health },
    { key: "noads", color: pillars.activity, ...t.trust.items.noads },
    { key: "notrack", color: pillars.hydration, ...t.trust.items.notrack },
  ];

  return (
    <section id="privacy-teaser" className="relative z-[1] px-6 py-24 md:py-32">
      <SectionAmbient tone="privacy" />
      <div className="mx-auto max-w-6xl">
        <div className="grid gap-12 md:grid-cols-[0.85fr_1.15fr] md:items-start">
          <div className="md:sticky md:top-28">
            <Reveal>
              <span className="text-[13px] font-bold uppercase tracking-[0.18em] text-hydration">
                {t.trust.kicker}
              </span>
            </Reveal>
            <Reveal delay={0.05}>
              <h2 className="display mt-3 text-[clamp(2.2rem,5vw,3.4rem)] text-white">
                {t.trust.title}
              </h2>
            </Reveal>
            <Reveal delay={0.1}>
              <p className="mt-4 max-w-[36ch] text-[16px] leading-relaxed text-white/50">
                {t.trust.lead}
              </p>
            </Reveal>
            <Reveal delay={0.15}>
              <a
                href={localePath("/privacy")}
                className="premium-link mt-6 inline-flex items-center gap-2 text-[15px] font-semibold text-white/85"
              >
                {t.trust.link}
                <span aria-hidden>→</span>
              </a>
            </Reveal>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            {items.map((it, i) => (
              <Reveal key={it.key} delay={0.05 * i}>
                <div className="premium-card glass h-full rounded-[22px] p-5">
                  <div
                    className="flex h-10 w-10 items-center justify-center rounded-[12px]"
                    style={{
                      background: `${it.color}1f`,
                      border: `1px solid ${it.color}33`,
                    }}
                  >
                    <Glyph name={it.key} color={it.color} />
                  </div>
                  <h3 className="mt-4 text-[16px] font-semibold text-white">{it.name}</h3>
                  <p className="mt-1 text-[13px] leading-relaxed text-white/50">{it.desc}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
