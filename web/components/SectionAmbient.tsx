"use client";

import clsx from "clsx";

type AmbientTone = "morning" | "recovery" | "activity" | "nutrition" | "privacy" | "coach";

const tones: Record<AmbientTone, string> = {
  morning:
    "radial-gradient(ellipse 80% 50% at 50% 0%, rgba(46,219,250,0.07), transparent 70%)",
  recovery:
    "radial-gradient(ellipse 70% 45% at 30% 20%, rgba(46,219,250,0.07), transparent 65%)",
  activity:
    "radial-gradient(ellipse 75% 50% at 70% 30%, rgba(102,240,112,0.06), transparent 68%)",
  nutrition:
    "radial-gradient(ellipse 70% 45% at 50% 40%, rgba(255,148,36,0.06), transparent 65%)",
  privacy:
    "radial-gradient(ellipse 90% 60% at 50% 50%, rgba(0,0,0,0.35), transparent 80%)",
  coach:
    "radial-gradient(ellipse 85% 55% at 50% 0%, rgba(140,102,217,0.09), transparent 72%)",
};

export default function SectionAmbient({
  tone,
  className,
}: {
  tone: AmbientTone;
  className?: string;
}) {
  return (
    <div
      aria-hidden
      className={clsx("pointer-events-none absolute inset-0 -z-10", className)}
      style={{ background: tones[tone] }}
    />
  );
}
