"use client";

import clsx from "clsx";
import React, { useEffect, useRef, useState } from "react";
import { useReducedMotion } from "@/lib/use-reduced-motion";

interface RevealProps {
  children: React.ReactNode;
  className?: string;
  delay?: number;
  y?: number;
  as?: "div" | "span" | "section" | "li";
}

export default function Reveal({
  children,
  className,
  delay = 0,
  y = 20,
  as: Tag = "div",
}: RevealProps) {
  const reduce = useReducedMotion();
  const ref = useRef<HTMLElement | null>(null);
  const [visible, setVisible] = useState(reduce);

  useEffect(() => {
    if (reduce) return;

    const el = ref.current;
    if (!el) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setVisible(true);
          observer.disconnect();
        }
      },
      { rootMargin: "-10% 0px -10% 0px", threshold: 0 }
    );

    observer.observe(el);
    return () => observer.disconnect();
  }, [reduce]);

  return (
    <Tag
      ref={(el: HTMLElement | null) => {
        ref.current = el;
      }}
      className={clsx("motion-reveal", className)}
      style={{
        opacity: visible ? 1 : 0,
        transform: visible ? "translateY(0)" : `translateY(${y}px)`,
        transitionDelay: visible ? `${delay}s` : "0s",
      }}
    >
      {children}
    </Tag>
  );
}
