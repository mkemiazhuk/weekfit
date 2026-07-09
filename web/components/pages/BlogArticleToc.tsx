"use client";

import { useCallback, useEffect, useState } from "react";
import clsx from "clsx";
import { useReducedMotion } from "framer-motion";
import type { TocItem } from "@/components/DocLayout";

/** Fixed nav height + breathing room — matches scroll-margin on .prose-blog h2 */
const READ_LINE = 104;

function headingTop(id: string): number | null {
  const el = document.getElementById(id);
  if (!el) return null;
  return el.getBoundingClientRect().top;
}

function resolveActiveSection(items: TocItem[]): string | undefined {
  if (!items.length) return undefined;

  const line = READ_LINE;
  const body = document.querySelector(".blog-article-body");
  const bodyBottom = body?.getBoundingClientRect().bottom ?? Infinity;

  // Active when the reading line sits between this H2 and the next one
  for (let i = 0; i < items.length; i++) {
    const top = headingTop(items[i].id);
    if (top === null) continue;

    const end =
      i < items.length - 1
        ? headingTop(items[i + 1].id) ?? bodyBottom
        : bodyBottom;

    if (top <= line + 1 && end > line + 1) {
      return items[i].id;
    }
  }

  // Fallback: last H2 that has scrolled past the reading line
  let active = items[0].id;
  for (const item of items) {
    const top = headingTop(item.id);
    if (top !== null && top <= line + 1) {
      active = item.id;
    }
  }

  // Final section: page ends before its H2 reaches the read line
  const last = items[items.length - 1];
  const lastTop = headingTop(last.id);
  const prevTop =
    items.length > 1 ? headingTop(items[items.length - 2].id) : null;
  const scrollBottom = window.innerHeight + window.scrollY;
  const nearEnd = document.documentElement.scrollHeight - scrollBottom < 160;

  if (
    nearEnd &&
    lastTop !== null &&
    lastTop > line + 1 &&
    prevTop !== null &&
    prevTop <= line + 1 &&
    lastTop < window.innerHeight
  ) {
    active = last.id;
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
      const top = el.getBoundingClientRect().top + window.scrollY - READ_LINE;
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
