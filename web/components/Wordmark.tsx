"use client";

import clsx from "clsx";
import { useI18n } from "@/lib/i18n";
import WordmarkMark from "./WordmarkMark";

const sizes = {
  nav: { markHeight: 40 },
  navMobile: { markHeight: 36 },
  lg: { markHeight: 44 },
  footer: { markHeight: 38 },
} as const;

export default function Wordmark({
  className,
  size = "nav",
  iconVariant = "subtle",
}: {
  className?: string;
  size?: keyof typeof sizes;
  /** subtle: site chrome. app: gold frame for press kit only. */
  iconVariant?: "subtle" | "app";
}) {
  const { localePath } = useI18n();
  const { markHeight } = sizes[size];

  return (
    <a
      href={localePath("/")}
      aria-label="WeekFit"
      className={clsx(
        "group wordmark-lockup wordmark-lockup--mark-only inline-flex min-w-0 max-w-full items-center transition-opacity hover:opacity-95",
        className
      )}
    >
      {iconVariant === "app" ? (
        <span className="wordmark-icon-app w-fit p-1">
          <span className="wordmark-icon-app-inner">
            <WordmarkMark height={markHeight} />
          </span>
        </span>
      ) : (
        <WordmarkMark height={markHeight} />
      )}
    </a>
  );
}
