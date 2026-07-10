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
        "signal-overlay-card card relative overflow-hidden p-4 md:p-[1.125rem]",
        floating && "coach-float",
        className
      )}
      style={{ "--accent-color": accent } as React.CSSProperties}
    >
      <div className="relative flex items-start gap-3">
        <span
          aria-hidden
          className="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full"
          style={{
            color: accent,
            background: `${accent}22`,
            border: `1px solid ${accent}44`,
          }}
        >
          <span className="h-1.5 w-1.5 rounded-full" style={{ background: accent }} />
        </span>
        <div className="min-w-0">
          <p className="signal-overlay-card__title">{signal}</p>
          <p className="signal-overlay-card__tip">{tip}</p>
          {detail ? <p className="signal-overlay-card__detail">{detail}</p> : null}
        </div>
      </div>
    </div>
  );
}
