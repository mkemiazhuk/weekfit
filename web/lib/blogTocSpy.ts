import type { TocItem } from "@/components/DocLayout";

const OFFSET_GAP = 16;

/** Measure live read line from the fixed site header. */
export function measureTocReadOffset(): number {
  const header = document.querySelector("header");
  const headerHeight = header?.getBoundingClientRect().height ?? 0;
  return Math.round(headerHeight + OFFSET_GAP);
}

/** Sync CSS anchor offset used by heading scroll-margin and sticky TOC. */
export function publishTocReadOffset(): number {
  const offset = measureTocReadOffset();
  document.documentElement.style.setProperty("--toc-read-offset", `${offset}px`);
  return offset;
}

function headingTop(id: string): number | null {
  const el = document.getElementById(id);
  if (!el) return null;
  return el.getBoundingClientRect().top;
}

export function isDocumentScrollEnd(): boolean {
  return (
    window.innerHeight + window.scrollY >=
    document.documentElement.scrollHeight - 2
  );
}

/**
 * Resolve the active TOC entry from heading positions in the viewport.
 *
 * 1. Last heading whose top has crossed the dynamic read line
 * 2. At true document bottom → last section (short final sections may never cross the line)
 */
export function resolveActiveTocItem(
  items: TocItem[],
  readLine = measureTocReadOffset()
): string | undefined {
  if (!items.length) return undefined;

  if (isDocumentScrollEnd()) {
    return items[items.length - 1].id;
  }

  let active = items[0].id;
  for (const item of items) {
    const top = headingTop(item.id);
    if (top !== null && top <= readLine) {
      active = item.id;
    }
  }

  return active;
}

export function scrollToTocHeading(
  id: string,
  behavior: ScrollBehavior = "smooth"
): void {
  const el = document.getElementById(id);
  if (!el) return;
  const offset = measureTocReadOffset();
  const top = el.getBoundingClientRect().top + window.scrollY - offset;
  window.scrollTo({ top, behavior });
}
