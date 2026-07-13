/** Max mockify frame CSS width on site × 2 for retina. */
export const MOCKIFY_FRAME_PX = 760;

export const SCREEN_WIDTHS = [560, 760] as const;
export type ScreenVariantWidth = (typeof SCREEN_WIDTHS)[number];

export const WATCH_OVERLAY_WIDTHS = [272, 368] as const;
export type WatchOverlayWidth = (typeof WATCH_OVERLAY_WIDTHS)[number];

export const WATCH_OVERLAY_VERSION = 11;

export function screenVariantPath(name: string, width: ScreenVariantWidth): string {
  return `/img/${name}-${width}.webp`;
}

export function screenVariantForPhoneWidth(phoneWidthPx: number): ScreenVariantWidth {
  return phoneWidthPx <= 280 ? 560 : 760;
}

export function screenVariantDimensions(width: ScreenVariantWidth) {
  return { width, height: Math.round(width * (1950 / 900)) };
}

export function watchOverlayPath(width: WatchOverlayWidth): string {
  return `/img/hero-watch-ultra-overlay-${width}.webp`;
}

export function watchVariantForWidth(watchPx: number): WatchOverlayWidth {
  return watchPx <= 150 ? 272 : 368;
}

export function watchOverlayDimensions(width: WatchOverlayWidth) {
  return { width, height: Math.round(width * (716 / 434)) };
}

export function wordmarkSrcSet(): string {
  return "/brand/logo-wf-mark-36.webp 1x, /brand/logo-wf-mark-72.webp 2x";
}

export function screenKeyFromPath(path: string): string | null {
  const match = path.match(/\/img\/(\w+?)(?:-\d+)?\.webp$/);
  return match?.[1] ?? null;
}
