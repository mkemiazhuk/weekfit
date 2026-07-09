"use client";

import Image from "next/image";
import clsx from "clsx";
import { useI18n } from "@/lib/i18n";

const sizes = {
  nav: { icon: 36, text: "text-[17px]", gap: "gap-3" },
  navMobile: { icon: 30, text: "text-[15px]", gap: "gap-2" },
  lg: { icon: 42, text: "text-[19px]", gap: "gap-3.5" },
  footer: { icon: 36, text: "text-[17px]", gap: "gap-2.5" },
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

  return (
    <a
      href={localePath("/")}
      className={clsx(
        "group wordmark-lockup inline-flex min-w-0 max-w-full items-center transition-opacity hover:opacity-95",
        s.gap,
        className
      )}
    >
      <span
        className={clsx(
          "relative shrink-0",
          iconVariant === "app" ? "wordmark-icon-app" : "wordmark-icon-subtle"
        )}
      >
        <span className={iconVariant === "app" ? "wordmark-icon-app-inner block" : "block overflow-hidden rounded-[22%]"}>
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
      <span className={clsx("display min-w-0 truncate leading-none tracking-[-0.03em]", s.text)}>
        <span className="text-white">Week</span>
        <span className="text-brand">Fit</span>
      </span>
    </a>
  );
}
