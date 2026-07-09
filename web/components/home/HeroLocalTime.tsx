"use client";

import { useEffect, useRef, useState } from "react";
import { useReducedMotion } from "framer-motion";

function formatLocalTime(): string {
  return new Intl.DateTimeFormat(undefined, {
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date());
}

function msUntilNextMinute(): number {
  const now = new Date();
  return (60 - now.getSeconds()) * 1000 - now.getMilliseconds() + 50;
}

type Props = {
  fallback?: string;
};

export default function HeroLocalTime({ fallback = "7:04" }: Props) {
  const reduce = useReducedMotion();
  const [current, setCurrent] = useState(fallback);
  const [outgoing, setOutgoing] = useState<string | null>(null);
  const hasSynced = useRef(false);
  const currentRef = useRef(current);
  currentRef.current = current;

  useEffect(() => {
    let fadeTimer: ReturnType<typeof setTimeout> | undefined;
    let minuteTimer: ReturnType<typeof setTimeout> | undefined;

    const setNext = (next: string, animate: boolean) => {
      if (next === currentRef.current) return;

      if (animate && hasSynced.current && !reduce) {
        setOutgoing(currentRef.current);
        setCurrent(next);
        fadeTimer = setTimeout(() => setOutgoing(null), 200);
      } else {
        setOutgoing(null);
        setCurrent(next);
      }

      hasSynced.current = true;
    };

    setNext(formatLocalTime(), false);

    const schedule = () => {
      minuteTimer = setTimeout(() => {
        setNext(formatLocalTime(), true);
        schedule();
      }, msUntilNextMinute());
    };

    schedule();

    return () => {
      clearTimeout(fadeTimer);
      clearTimeout(minuteTimer);
    };
  }, [reduce]);

  return (
    <span className="hero-time__clock" suppressHydrationWarning>
      {outgoing !== null && (
        <span className="hero-time__layer hero-time__layer--out" aria-hidden>
          {outgoing}
        </span>
      )}
      <span
        className={
          outgoing !== null && !reduce
            ? "hero-time__layer hero-time__layer--in hero-time__layer--entering"
            : "hero-time__layer hero-time__layer--in"
        }
      >
        {current}
      </span>
    </span>
  );
}
