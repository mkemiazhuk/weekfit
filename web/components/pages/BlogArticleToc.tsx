"use client";

import { useCallback, useEffect, useState } from "react";
import clsx from "clsx";
import { useReducedMotion } from "framer-motion";
import type { TocItem } from "@/components/DocLayout";

const SCROLL_OFFSET = 96;

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

    const onScroll = () => {
      const marker = window.scrollY + SCROLL_OFFSET + 8;
      let current = items[0]?.id;

      for (const item of items) {
        const el = document.getElementById(item.id);
        if (el && el.offsetTop <= marker) {
          current = item.id;
        }
      }

      setActive(current);
    };

    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, [items]);

  const scrollTo = useCallback(
    (id: string) => {
      const el = document.getElementById(id);
      if (!el) return;
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
