"use client";

import Image from "next/image";
import clsx from "clsx";
import { useI18n } from "@/lib/i18n";

const sizes = {
  nav: { text: "text-[17px]", icon: 34, gap: "gap-2.5", nudge: "1px" },
  navMobile: { text: "text-[15px]", icon: 30, gap: "gap-2", nudge: "1px" },
  lg: { text: "text-[19px]", icon: 38, gap: "gap-3", nudge: "1px" },
  footer: { text: "text-[17px]", icon: 34, gap: "gap-2.5", nudge: "1px" },
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
        s.text,
        s.gap,
        className
      )}
    >
      <span
        className={clsx(
          "wordmark-lockup__icon relative shrink-0",
          iconVariant === "app" ? "wordmark-icon-app" : "wordmark-icon-subtle"
        )}
        style={{ width: s.icon, height: s.icon, transform: `translateY(${s.nudge})` }}
      >
        <Image
          src="/brand/logo-gold-lockup.png"
          alt=""
          width={s.icon}
          height={s.icon}
          className="block size-full object-contain object-center"
          aria-hidden
        />
      </span>
      <span className="wordmark-lockup__text display min-w-0 truncate leading-none tracking-[-0.03em]">
        <span className="text-white">Week</span>
        <span className="text-brand">Fit</span>
      </span>
    </a>
  );
}
