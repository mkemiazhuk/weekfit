"use client";

import { useId } from "react";

/** Apple Health–style heart mark (pink gradient, not WeekFit pillar blue). */
export default function AppleHealthMark({
  size = 20,
  className,
}: {
  size?: number;
  className?: string;
}) {
  const gradientId = useId();

  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      className={className}
      aria-hidden
    >
      <defs>
        <linearGradient id={gradientId} x1="12" y1="4" x2="12" y2="22" gradientUnits="userSpaceOnUse">
          <stop stopColor="#FF6BAA" />
          <stop offset="1" stopColor="#FF2D55" />
        </linearGradient>
      </defs>
      <path
        fill={`url(#${gradientId})`}
        d="M12 20.5s-6.2-3.85-6.2-8.55C5.8 9.35 8.55 7 12 9.1c3.45-2.1 6.2 0.25 6.2 2.85 0 4.7-6.2 8.55-6.2 8.55z"
      />
    </svg>
  );
}
