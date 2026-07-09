"use client";

import clsx from "clsx";
import { useId } from "react";

export default function WebMarkIcon({
  size = 36,
  className,
}: {
  size?: number;
  className?: string;
}) {
  const gradId = useId();

  return (
    <svg
      viewBox="0 0 40 40"
      width={size}
      height={size}
      className={clsx("wordmark-mark-web shrink-0", className)}
      aria-hidden
    >
      <rect
        x="0.5"
        y="0.5"
        width="39"
        height="39"
        rx="9.5"
        fill="#08090c"
        stroke="rgba(46, 219, 250, 0.24)"
      />
      <path
        d="M11 27V13l2.8 5.6L16.6 13l2.8 5.6L22.2 13v14"
        fill="none"
        stroke={`url(#${gradId})`}
        strokeWidth="2.15"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M25.5 13H31v2.8h-4.2v2.4H30.5V21H25.5z"
        fill={`url(#${gradId})`}
      />
      <defs>
        <linearGradient id={gradId} x1="11" y1="13" x2="31" y2="27" gradientUnits="userSpaceOnUse">
          <stop stopColor="#2edbfa" />
          <stop offset="1" stopColor="#66bc87" />
        </linearGradient>
      </defs>
    </svg>
  );
}
