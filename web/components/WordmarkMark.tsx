"use client";

import Image from "next/image";
import clsx from "clsx";

/** Trimmed WF monogram aspect from logo-gold-tab (821×929). */
export const WORDMARK_MARK_ASPECT = 821 / 929;

export default function WordmarkMark({
  height,
  className,
}: {
  height: number;
  className?: string;
}) {
  const width = Math.round(height * WORDMARK_MARK_ASPECT);

  return (
    <Image
      src="/brand/logo-wf-mark.png"
      alt=""
      width={width}
      height={height}
      className={clsx("wordmark-mark block shrink-0", className)}
      aria-hidden
    />
  );
}
