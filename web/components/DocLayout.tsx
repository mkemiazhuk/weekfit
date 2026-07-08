"use client";

import { useEffect, useState } from "react";
import clsx from "clsx";

export interface TocItem {
  id: string;
  label: string;
}

export default function DocLayout({
  toc,
  tocTitle = "On this page",
  children,
}: {
  toc: TocItem[];
  tocTitle?: string;
  children: React.ReactNode;
}) {
  const [active, setActive] = useState(toc[0]?.id);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) setActive(e.target.id);
        }
      },
      { rootMargin: "-96px 0px -70% 0px", threshold: 0 }
    );
    toc.forEach((t) => {
      const el = document.getElementById(t.id);
      if (el) observer.observe(el);
    });
    return () => observer.disconnect();
  }, [toc]);

  return (
    <div className="mx-auto max-w-5xl px-6 pb-32">
      <div className="gap-12 md:grid md:grid-cols-[220px_1fr]">
        <aside className="hidden md:block">
          <div className="sticky top-28">
            <p className="mb-4 text-[12px] font-semibold uppercase tracking-[0.14em] text-white/40">
              {tocTitle}
            </p>
            <nav className="space-y-1 border-l border-white/10">
              {toc.map((t) => (
                <a
                  key={t.id}
                  href={`#${t.id}`}
                  className={clsx(
                    "-ml-px block border-l-2 py-1.5 pl-4 text-[13.5px] transition-colors",
                    active === t.id
                      ? "border-brand text-white"
                      : "border-transparent text-white/45 hover:text-white/80"
                  )}
                >
                  {t.label}
                </a>
              ))}
            </nav>
          </div>
        </aside>
        <article className="prose min-w-0">{children}</article>
      </div>
    </div>
  );
}
