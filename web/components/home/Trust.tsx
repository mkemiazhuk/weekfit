"use client";

import Reveal from "../Reveal";
import AppleHealthMark from "../AppleHealthMark";
import { pillars } from "@/lib/tokens";
import { useI18n } from "@/lib/i18n";
import SectionAmbient from "../SectionAmbient";

function Glyph({ name, color }: { name: string; color: string }) {
  const paths: Record<string, React.ReactNode> = {
    device: <rect x="7" y="2.5" width="10" height="19" rx="2.5" />,
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
    <section id="privacy-teaser" className="relative z-[1] section-x section-y-lg">
      <SectionAmbient tone="privacy" />
      <div className="mx-auto max-w-6xl">
        <div className="grid gap-14 md:grid-cols-[0.85fr_1.15fr] md:items-start md:gap-16">
          <div className="md:sticky md:top-32">
            <Reveal>
              <span className="kicker text-hydration">{t.trust.kicker}</span>
            </Reveal>
            <Reveal delay={0.05}>
              <h2 className="display section-title-lg text-balance mt-4 text-white">
                {t.trust.title}
              </h2>
            </Reveal>
            <Reveal delay={0.1}>
              <p className="body-md section-lead text-balance mt-5">{t.trust.lead}</p>
            </Reveal>
            <Reveal delay={0.15}>
              <a
                href={localePath("/privacy")}
                className="premium-link mt-7 inline-flex items-center gap-2 text-[15px] font-semibold text-white/72"
              >
                {t.trust.link}
                <span aria-hidden>→</span>
              </a>
            </Reveal>
          </div>

          <div className="grid gap-3.5 sm:grid-cols-2">
            {items.map((it, i) => (
              <Reveal key={it.key} delay={0.05 * i}>
                <div className="premium-card surface-quiet h-full p-5">
                  {it.key === "health" ? (
                    <div className="icon-tile apple-health-tile">
                      <AppleHealthMark size={24} />
                    </div>
                  ) : (
                    <div
                      className="icon-tile icon-tile-accent"
                      style={{ "--accent-color": it.color } as React.CSSProperties}
                    >
                      <Glyph name={it.key} color={it.color} />
                    </div>
                  )}
                  <h3 className="mt-4 text-[16px] font-semibold text-white/92">{it.name}</h3>
                  <p className="body-sm mt-1.5">{it.desc}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
