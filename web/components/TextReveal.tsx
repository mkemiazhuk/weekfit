"use client";

import clsx from "clsx";
import { useReducedMotion } from "@/lib/use-reduced-motion";

interface TextRevealProps {
  children: React.ReactNode;
  className?: string;
  delay?: number;
  as?: "h1" | "h2" | "p" | "span";
}

export default function TextReveal({
  children,
  className,
  delay = 0,
  as: Tag = "span",
}: TextRevealProps) {
  const reduce = useReducedMotion();

  if (reduce) {
    return <Tag className={className}>{children}</Tag>;
  }

  return (
    <Tag className={clsx("block overflow-hidden", className)}>
      <span
        className="motion-text-reveal block"
        style={{ animationDelay: `${delay}s` }}
      >
        {children}
      </span>
    </Tag>
  );
}
