"use client";

import clsx from "clsx";

type AmbientTone = "morning" | "recovery" | "activity" | "nutrition" | "privacy" | "coach";

const tones: Record<AmbientTone, string> = {
  morning:
    "radial-gradient(ellipse 80% 50% at 50% 0%, rgba(234,160,107,0.16), transparent 70%)",
  recovery:
    "radial-gradient(ellipse 70% 45% at 30% 20%, rgba(155,138,203,0.16), transparent 65%)",
  activity:
    "radial-gradient(ellipse 75% 50% at 70% 30%, rgba(114,173,138,0.16), transparent 68%)",
  nutrition:
    "radial-gradient(ellipse 70% 45% at 50% 40%, rgba(234,160,107,0.18), transparent 65%)",
  privacy:
    "radial-gradient(ellipse 90% 60% at 50% 50%, rgba(114,173,138,0.08), transparent 80%)",
  coach:
    "radial-gradient(ellipse 85% 55% at 50% 0%, rgba(155,138,203,0.14), transparent 72%)",
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
