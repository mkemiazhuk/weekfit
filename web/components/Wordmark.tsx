"use client";

import clsx from "clsx";
import { useI18n } from "@/lib/i18n";
import WordmarkMark from "./WordmarkMark";

const sizes = {
  nav: { fontSize: 17, markScale: 1.52, gap: 16 },
  navMobile: { fontSize: 15, markScale: 1.38, gap: 15 },
  lg: { fontSize: 19, markScale: 1.5, gap: 16 },
  footer: { fontSize: 17, markScale: 1.52, gap: 16 },
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
  const s = sizes[size];
  const markHeight = Math.round(s.fontSize * s.markScale);

  return (
    <a
      href={localePath("/")}
      style={{ gap: s.gap, fontSize: s.fontSize }}
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
