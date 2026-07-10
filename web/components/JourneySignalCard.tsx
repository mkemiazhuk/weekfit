"use client";

import clsx from "clsx";

interface JourneySignalCardProps {
  accent: string;
  signal: string;
  tip: string;
  detail?: string;
  className?: string;
  floating?: boolean;
}

export default function JourneySignalCard({
  accent,
  signal,
  tip,
  detail,
  className,
  floating,
}: JourneySignalCardProps) {
  return (
    <div
      className={clsx(
        "premium-card card card-accent relative overflow-hidden p-5",
        floating && "coach-float",
        className
      )}
      style={{ "--accent-color": accent } as React.CSSProperties}
    >
      <div className="relative flex items-start gap-2.5">
        <span
          aria-hidden
          className="mt-1.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full"
          style={{
            color: accent,
            background: `${accent}1a`,
            border: `1px solid ${accent}33`,
          }}
        >
          <span
            className="signal-dot-pulse h-1.5 w-1.5 rounded-full"
            style={{ background: accent, boxShadow: `0 0 8px ${accent}` }}
          />
        </span>
        <div className="min-w-0">
          <p className="text-[14px] font-semibold leading-snug text-white">{signal}</p>
          <p className="mt-1 text-[12.5px] leading-snug text-white/58">{tip}</p>
          {detail ? (
            <p className="mt-1 text-[11.5px] leading-snug text-white/42">{detail}</p>
          ) : null}
        </div>
      </div>
    </div>
  );
}
