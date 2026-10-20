"use client";

import Image from "next/image";
import { motion, useReducedMotion } from "framer-motion";
import { useI18n } from "@/lib/i18n";
import { SITE } from "@/lib/site";
import { accents } from "@/lib/tokens";
import { easeReveal, durationReveal, stagger } from "@/lib/motion";
import Button from "../Button";
import Reveal from "../Reveal";
import SectionAmbient from "../SectionAmbient";
import PhoneMockup from "../PhoneMockup";

export default function AiNutrition() {
  const { t } = useI18n();
  const a = t.aiNutrition;
  const reduce = useReducedMotion();

  return (
    <section
      id="ai-nutrition"
      aria-labelledby="ai-nutrition-heading"
      className="relative z-[1] section-x section-y"
    >
      <SectionAmbient tone="activity" />
      <div className="mx-auto grid max-w-6xl items-center gap-10 md:grid-cols-[1.05fr_0.95fr] md:gap-14">
        <Reveal>
          <div className="max-w-xl">
            <p className="kicker" style={{ color: accents.gold }}>
              {a.kicker}
            </p>
            <h2
              id="ai-nutrition-heading"
              className="display section-title mt-4 text-balance text-white"
            >
              {a.title}
            </h2>
            <p className="body-md section-lead mt-5">{a.lead}</p>

            <ul className="mt-7 space-y-3">
              {a.points.map((point, i) => (
                <motion.li
                  key={point}
                  className="flex items-start gap-3 text-[15px] text-white/72"
                  initial={reduce ? false : { opacity: 0, y: 8 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true, margin: "-10% 0px" }}
                  transition={{
                    duration: durationReveal,
                    ease: easeReveal,
                    delay: i * stagger,
                  }}
                >
                  <span
                    aria-hidden
                    className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full"
                    style={{ background: accents.gold, boxShadow: `0 0 10px ${accents.gold}66` }}
                  />
                  {point}
                </motion.li>
              ))}
            </ul>

            <div className="mt-8 flex flex-wrap items-center gap-3">
              <Button href={SITE.appInstallUrl} external className="btn-hero-primary min-h-[44px]">
                {a.cta}
              </Button>
              <span
                className="inline-flex items-center rounded-full px-3 py-1.5 text-[11px] font-bold uppercase tracking-[0.12em]"
                style={{
                  color: accents.gold,
                  background: `${accents.gold}18`,
                  border: `1px solid ${accents.gold}33`,
                }}
              >
                {a.badge}
              </span>
            </div>
          </div>
        </Reveal>

        <Reveal delay={0.08}>
          <div className="relative mx-auto w-full max-w-[280px] md:max-w-[300px]">
            <div
              aria-hidden
              className="pointer-events-none absolute -inset-8 rounded-[40%] opacity-70 blur-3xl"
              style={{
                background: `radial-gradient(circle at 50% 40%, ${accents.gold}28, transparent 68%)`,
              }}
            />
            <PhoneMockup width={280} depth alt={a.imageAlt} className="relative mx-auto">
              <Image
                src="/img/ai-nutrition-assistant.webp"
                alt={a.imageAlt}
                width={553}
                height={1200}
                sizes="280px"
                className="h-full w-full object-cover object-top"
              />
            </PhoneMockup>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
