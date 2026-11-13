"use client";

import clsx from "clsx";

/** Square WeekFit mark. */
export const WORDMARK_MARK_ASPECT = 1;

export default function WordmarkMark({
  height,
  className,
}: {
  height: number;
  className?: string;
}) {
  const width = Math.round(height * WORDMARK_MARK_ASPECT);

  return (
    // eslint-disable-next-line @next/next/no-img-element -- manual 1x/2x srcSet; next/image omits srcSet
    <img
      src="/brand/weekfit-icon.png"
      alt=""
      width={width}
      height={height}
      className={clsx("wordmark-mark block shrink-0", className)}
      aria-hidden
      decoding="async"
    />
  );
}
