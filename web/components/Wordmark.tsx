"use client";

import Image from "next/image";
import clsx from "clsx";
import { useI18n } from "@/lib/i18n";

const sizes = {
  nav: { icon: 36, text: "text-[17px]", gap: "gap-3" },
  lg: { icon: 42, text: "text-[19px]", gap: "gap-3.5" },
} as const;

export default function Wordmark({
  className,
  size = "nav",
}: {
  className?: string;
  size?: keyof typeof sizes;
}) {
  const { localePath } = useI18n();
  const s = sizes[size];

  return (
    <a
      href={localePath("/")}
      className={clsx(
        "group inline-flex items-center transition-opacity hover:opacity-95",
        s.gap,
        className
      )}
    >
      <span className="wordmark-icon relative shrink-0 transition-shadow duration-300">
        <span className="wordmark-icon-inner block">
          <Image
            src="/brand/icon-192.png"
            alt=""
            width={s.icon}
            height={s.icon}
            className="block"
            aria-hidden
          />
        </span>
      </span>
      <span
        className={clsx(
          "display leading-none tracking-[-0.03em]",
          s.text
        )}
      >
        <span className="text-white">Week</span>
        <span className="text-brand">Fit</span>
      </span>
    </a>
  );
}
