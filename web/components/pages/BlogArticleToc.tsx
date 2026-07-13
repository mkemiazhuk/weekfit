"use client";

import { useCallback, useEffect, useState } from "react";
import clsx from "clsx";
import { useReducedMotion } from "framer-motion";
import type { TocItem } from "@/components/DocLayout";
import {
  publishTocReadOffset,
  resolveActiveTocItem,
  scrollToTocHeading,
} from "@/lib/blogTocSpy";

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
      const readLine = publishTocReadOffset();
      const next = resolveActiveTocItem(items, readLine);
      if (next) setActive(next);
    };

    const onScroll = () => {
      if (!ticking) {
        ticking = true;
        requestAnimationFrame(update);
      }
    };

    update();

    const header = document.querySelector("header");
    const ro = header ? new ResizeObserver(update) : null;
    ro?.observe(header!);

    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
    return () => {
      ro?.disconnect();
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
    };
  }, [items]);

  const scrollTo = useCallback(
    (id: string) => {
      setActive(id);
      scrollToTocHeading(id, reduce ? "auto" : "smooth");
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
