"use client";

import clsx from "clsx";
import CoachAdviceList, { type CoachAdvice, type CoachAdviceLabels } from "./CoachAdviceList";

interface CoachCardProps {
  accent: string;
  state: string;
  title: string;
  body?: string;
  coachLabel?: string;
  advice?: CoachAdvice;
  adviceLabels?: CoachAdviceLabels;
  className?: string;
  floating?: boolean;
}

export default function CoachCard({
  accent,
  state,
  title,
  body,
  coachLabel = "Coach",
  advice,
  adviceLabels,
  className,
  floating,
}: CoachCardProps) {
  return (
    <div
      className={clsx(
        "premium-card card card-accent relative overflow-hidden p-5",
        floating && "coach-float",
        className
      )}
      style={{ "--accent-color": accent } as React.CSSProperties}
    >
      <svg
        aria-hidden
        viewBox="0 0 24 24"
        className="absolute -bottom-3 -left-2 h-24 w-24"
        style={{ color: accent, opacity: 0.08 }}
        fill="currentColor"
      >
        <path d="M12 2c1.1 0 2 .9 2 2 1.66 0 3 1.34 3 3 1.1 0 2 .9 2 2 0 .74-.4 1.38-1 1.72V13c0 3.31-2.69 6-6 6s-6-2.69-6-6v-.28C5.4 12.38 5 11.74 5 11c0-1.1.9-2 2-2 0-1.66 1.34-3 3-3 0-1.1.9-2 2-2z" />
      </svg>

      <div className="relative">
        <span
          className="inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[10px] font-bold uppercase tracking-[0.14em]"
          style={{
            color: accent,
            background: `${accent}1f`,
            border: `1px solid ${accent}38`,
          }}
        >
          <span
            className="h-1.5 w-1.5 rounded-full"
            style={{ background: accent }}
          />
          {state}
        </span>
        <p className="kicker-sm mt-3">{coachLabel}</p>
        <p className="mt-1 text-[15px] font-semibold leading-snug text-white">{title}</p>
        {advice && adviceLabels ? (
          <CoachAdviceList advice={advice} labels={adviceLabels} compact />
        ) : body ? (
          <p className="body-sm mt-1.5 text-[12.5px]">{body}</p>
        ) : null}
      </div>
    </div>
  );
}
