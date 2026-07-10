"use client";

import { useEffect, useRef, useState } from "react";
import clsx from "clsx";
import { useI18n } from "@/lib/i18n";
import { journeySpotlightSteps } from "@/lib/journeySpotlight";
import SectionAmbient from "../SectionAmbient";
import JourneySpotlightPhone from "./JourneySpotlightPhone";

export default function JourneyStage() {
  const { t } = useI18n();
  const steps = journeySpotlightSteps;
  const copy = t.journeySteps;

  const [active, setActive] = useState(0);
  const panelRefs = useRef<(HTMLDivElement | null)[]>([]);
  const ratios = useRef<number[]>(steps.map(() => 0));

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          const idx = Number((e.target as HTMLElement).dataset.idx);
          ratios.current[idx] = e.isIntersecting ? e.intersectionRatio : 0;
        }
        let best = 0;
        let bestRatio = -1;
        ratios.current.forEach((r, i) => {
          if (r > bestRatio) {
            bestRatio = r;
            best = i;
          }
        });
        setActive(best);
      },
      { rootMargin: "-42% 0px -42% 0px", threshold: [0, 0.25, 0.5, 0.75, 1] }
    );
    panelRefs.current.forEach((el) => el && observer.observe(el));
    return () => observer.disconnect();
  }, [steps.length]);

  const current = steps[active];

  return (
    <section id="experience" className="relative z-[1] section-x section-y-inset-top">
      <SectionAmbient tone={current.ambient} />

      <div className="mx-auto max-w-6xl">
        <div className="journey-spotlight-phone-mobile sticky top-[4.75rem] z-10 mx-auto mb-8 max-w-[240px] md:hidden">
          <JourneySpotlightPhone steps={steps} activeIndex={active} sizes="240px" />
        </div>

        <div className="md:grid md:grid-cols-2 md:gap-14 lg:gap-16">
          <div className="hidden md:flex md:sticky md:top-0 md:h-screen md:items-center md:justify-center">
            <JourneySpotlightPhone
              steps={steps}
              activeIndex={active}
              className="max-w-[320px]"
              sizes="320px"
            />
          </div>

          <div>
            {steps.map((step, i) => {
              const stepCopy = copy[step.contentKey];
              const isActive = i === active;

              return (
                <div
                  key={step.id}
                  ref={(el) => {
                    panelRefs.current[i] = el;
                  }}
                  data-idx={i}
                  className="relative flex min-h-[52vh] flex-col justify-center py-10 md:min-h-[84vh] md:py-[4.5rem]"
                >
                  <div
                    className={clsx(
                      "journey-walkthrough-copy text-center transition-opacity duration-500 md:text-left",
                      isActive ? "opacity-100" : "opacity-38 md:opacity-42"
                    )}
                  >
                    <span className="kicker" style={{ color: step.accent }}>
                      {stepCopy.label}
                    </span>
                    <h2 className="display section-title text-balance mt-4 text-white">
                      {stepCopy.signal}
                    </h2>
                    <p className="body-lg mt-4 max-w-[var(--measure-prose)] mx-auto md:mx-0">
                      {stepCopy.tip}
                    </p>
                    <p className="body-md mt-3 max-w-[var(--measure-prose)] mx-auto md:mx-0">
                      {stepCopy.detail}
                    </p>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}
