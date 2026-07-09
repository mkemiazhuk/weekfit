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

  const body = document.querySelector(".blog-article-body");
  if (body) {
    const bodyBottom = body.getBoundingClientRect().bottom;
    if (bodyBottom <= window.innerHeight + 48) {
      return items[items.length - 1].id;
    }
  }

  let closestId = items[0].id;
  let closestDist = Infinity;

  for (const item of items) {
    const top = headingTop(item.id);
    if (top === null) continue;

    const dist = Math.abs(top - READ_LINE);
    if (dist < closestDist) {
      closestDist = dist;
      closestId = item.id;
    }
  }

  return closestId;
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
