"use client";

import React from "react";
import clsx from "clsx";

type Variant = "primary" | "ghost";

interface ButtonProps {
  href?: string;
  children: React.ReactNode;
  variant?: Variant;
  className?: string;
  icon?: React.ReactNode;
  external?: boolean;
}

export default function Button({
  href,
  children,
  variant = "primary",
  className,
  icon,
  external,
}: ButtonProps) {
  const base =
    "group relative inline-flex items-center justify-center gap-2 rounded-[14px] px-6 py-3.5 text-[15px] font-semibold transition-all duration-300 will-change-transform hover:-translate-y-0.5 active:translate-y-0 active:scale-[0.98]";

  const styles: Record<Variant, string> = {
    primary:
      "text-[#04240f] shadow-[0_14px_40px_-8px_rgba(102,188,135,0.5)] hover:shadow-[0_18px_48px_-6px_rgba(102,188,135,0.55)] hover:brightness-[1.04]",
    ghost:
      "glass text-white/90 hover:text-white hover:border-white/20 hover:bg-white/[0.06]",
  };

  const content = (
    <>
      {variant === "primary" && (
        <span
          aria-hidden
          className="absolute inset-0 rounded-[14px]"
          style={{
            background:
              "linear-gradient(150deg, #7fdca0, #4f9e6f 55%, #35634d)",
          }}
        />
      )}
      {variant === "primary" && (
        <span
          aria-hidden
          className="absolute inset-0 rounded-[14px] opacity-60"
          style={{
            background:
              "linear-gradient(160deg, rgba(255,255,255,0.28), rgba(245,191,92,0.05) 40%, transparent 70%)",
          }}
        />
      )}
      <span className="relative z-10 inline-flex items-center gap-2">
        {children}
        {icon}
      </span>
    </>
  );

  const cls = clsx(base, styles[variant], className);

  if (href) {
    return (
      <a
        href={href}
        className={cls}
        {...(external ? { target: "_blank", rel: "noreferrer" } : {})}
      >
        {content}
      </a>
    );
  }
  return (
    <button type="button" className={cls}>
      {content}
    </button>
  );
}
