"use client";

import { useCallback, useEffect, useState } from "react";
import clsx from "clsx";
import { useReducedMotion } from "framer-motion";
import type { TocItem } from "@/components/DocLayout";

/** Fixed nav height + breathing room — matches scroll-margin on .prose-blog h2 */
const SCROLL_OFFSET = 104;

function resolveActiveSection(items: TocItem[]): string | undefined {
  if (!items.length) return undefined;

  const marker = window.scrollY + SCROLL_OFFSET;
  let active = items[0].id;

  for (const item of items) {
    const el = document.getElementById(item.id);
    if (!el) continue;

    const top = el.getBoundingClientRect().top + window.scrollY;
    if (top <= marker + 2) {
      active = item.id;
    }
  }

  return active;
}

export default function BlogArticleToc({
  items,
  title,
}: {
  items: TocItem[];
  title: string;
}) {
  const reduce = useReducedMotion();
  const [active, setActive] = useState(items[0]?.id);

  useEffect(() => {
    if (!items.length) return;

    let ticking = false;

    const update = () => {
      ticking = false;
      const next = resolveActiveSection(items);
      if (next) setActive(next);
    };

    const onScroll = () => {
      if (!ticking) {
        ticking = true;
        requestAnimationFrame(update);
      }
    };

    update();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
    return () => {
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
    };
  }, [items]);

  const scrollTo = useCallback(
    (id: string) => {
      const el = document.getElementById(id);
      if (!el) return;
      setActive(id);
      const top = el.getBoundingClientRect().top + window.scrollY - SCROLL_OFFSET;
      window.scrollTo({ top, behavior: reduce ? "auto" : "smooth" });
    },
    [reduce]
  );

  return (
    <aside className="blog-article-toc hidden lg:block" aria-label={title}>
      <div className="blog-article-toc__inner">
        <p className="blog-toc-kicker">{title}</p>
        <nav>
          <ul className="blog-toc-list">
            {items.map((item, index) => (
              <li key={item.id}>
                <a
                  href={`#${item.id}`}
                  onClick={(e) => {
                    e.preventDefault();
                    scrollTo(item.id);
                  }}
                  className={clsx(
                    "blog-toc-link",
                    active === item.id && "blog-toc-link--active"
                  )}
                  aria-current={active === item.id ? "location" : undefined}
                >
                  <span className="blog-toc-index">
                    {String(index + 1).padStart(2, "0")}
                  </span>
                  <span className="blog-toc-label">{item.label}</span>
                </a>
              </li>
            ))}
          </ul>
        </nav>
      </div>
    </aside>
  );
}
