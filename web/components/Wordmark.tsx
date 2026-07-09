"use client";

import Image from "next/image";
import clsx from "clsx";
import { useI18n } from "@/lib/i18n";
import WebMarkIcon from "./WebMarkIcon";

const sizes = {
  nav: { icon: 36, text: "text-[17px]", gap: "gap-3" },
  navMobile: { icon: 30, text: "text-[15px]", gap: "gap-2" },
  lg: { icon: 42, text: "text-[19px]", gap: "gap-3.5" },
  footer: { icon: 44, text: "text-[20px]", gap: "gap-3" },
} as const;

export default function Wordmark({
  className,
  size = "nav",
  iconVariant = "web",
}: {
  className?: string;
  size?: keyof typeof sizes;
  /** Web: flat mark for site chrome. App: full App Store icon for press/download. */
  iconVariant?: "web" | "app";
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
      {iconVariant === "app" ? (
        <span className="wordmark-icon-app relative shrink-0 transition-shadow duration-300">
          <span className="wordmark-icon-app-inner block">
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
      ) : (
        <WebMarkIcon size={s.icon} />
      )}
      <span className={clsx("display leading-none tracking-[-0.03em]", s.text)}>
        <span className="text-white">Week</span>
        <span className="text-brand">Fit</span>
      </span>
    </a>
  );
}
