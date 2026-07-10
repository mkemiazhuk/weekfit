"use client";

import clsx from "clsx";

interface JourneySignalCardProps {
  accent: string;
  signal: string;
  tip: string;
  detail?: string;
  className?: string;
}

export default function JourneySignalCard({
  accent,
  signal,
  tip,
  detail,
  className,
}: JourneySignalCardProps) {
  return (
    <div
      className={clsx("journey-signal-card card relative overflow-hidden", className)}
      style={{ "--accent-color": accent } as React.CSSProperties}
    >
      <div
        aria-hidden
        className="journey-signal-card__accent-bar"
        style={{ background: accent }}
      />
      <div className="relative px-4 py-4 md:px-[1.125rem] md:py-[1.125rem]">
        <p className="journey-signal-card__title">{signal}</p>
        <p className="journey-signal-card__tip">{tip}</p>
        {detail ? <p className="journey-signal-card__detail">{detail}</p> : null}
      </div>
    </div>
  );
}
