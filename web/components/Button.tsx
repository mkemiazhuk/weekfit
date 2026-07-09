"use client";

import React from "react";
import clsx from "clsx";

type Variant = "primary" | "ghost";
type Size = "sm" | "md";

interface ButtonProps {
  href?: string;
  children: React.ReactNode;
  variant?: Variant;
  size?: Size;
  className?: string;
  icon?: React.ReactNode;
  external?: boolean;
  onClick?: () => void;
}

const sizes: Record<Size, string> = {
  sm: "rounded-button px-4 py-2 text-[13px]",
  md: "rounded-button px-6 py-3.5 text-[15px]",
};

export default function Button({
  href,
  children,
  variant = "primary",
  size = "md",
  className,
  icon,
  external,
  onClick,
}: ButtonProps) {
  const base = clsx(
    "group relative inline-flex items-center justify-center gap-2 font-semibold",
    "transition-all duration-300 will-change-transform",
    "hover:-translate-y-0.5 active:translate-y-0 active:scale-[0.98]",
    sizes[size]
  );

  const styles: Record<Variant, string> = {
    primary: clsx(
      "text-[var(--color-btn-text)]",
      "shadow-[0_14px_40px_-8px_rgba(102,188,135,0.5)]",
      "hover:shadow-[0_18px_48px_-6px_rgba(102,188,135,0.55)]",
      "hover:brightness-[1.04]"
    ),
    ghost: "glass text-white/90 hover:text-white hover:border-white/20 hover:bg-white/[0.06]",
  };

  const content = (
    <>
      {variant === "primary" && (
        <>
          <span aria-hidden className="absolute inset-0 rounded-button btn-primary-bg" />
          <span
            aria-hidden
            className="absolute inset-0 rounded-button opacity-60 btn-primary-shine"
          />
        </>
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
        onClick={onClick}
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
