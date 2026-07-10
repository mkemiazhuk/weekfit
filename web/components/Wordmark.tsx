"use client";

import clsx from "clsx";
import { useI18n } from "@/lib/i18n";
import WordmarkMark from "./WordmarkMark";

const sizes = {
  nav: { markHeight: 29, fontSize: 14, gap: 8 },
  navMobile: { markHeight: 23, fontSize: 13, gap: 7 },
  lg: { markHeight: 32, fontSize: 15, gap: 8 },
  footer: { markHeight: 29, fontSize: 14, gap: 8 },
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
  const { markHeight, fontSize, gap } = sizes[size];

  return (
    <a
      href={localePath("/")}
      style={{ gap, fontSize }}
      className={clsx(
        "group wordmark-lockup inline-flex min-w-0 max-w-full items-center transition-opacity hover:opacity-95",
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
      <span className="wordmark-lockup__text min-w-0 truncate">
        <span className="wordmark-lockup__week">Week</span>
        <span className="wordmark-lockup__fit">Fit</span>
      </span>
    </a>
  );
}
