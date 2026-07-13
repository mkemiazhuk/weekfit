/** Photographic screenshots — WebP with JPG fallback paths. */
import {
  screenVariantForPhoneWidth,
  screenVariantPath,
  type ScreenVariantWidth,
} from "./responsive-images";

export const SCREEN_IMAGES = {
  today: { webp: "/img/today.webp", jpg: "/img/today.jpg", width: 900, height: 1950 },
  meals: { webp: "/img/meals.webp", jpg: "/img/meals.jpg", width: 900, height: 1950 },
  activity: { webp: "/img/activity.webp", jpg: "/img/activity.jpg", width: 900, height: 1950 },
  recovery: { webp: "/img/recovery.webp", jpg: "/img/recovery.jpg", width: 900, height: 1950 },
  coach: { webp: "/img/coach.webp", jpg: "/img/coach.jpg", width: 900, height: 1950 },
  nutrition: { webp: "/img/nutrition.webp", jpg: "/img/nutrition.jpg", width: 900, height: 1950 },
} as const;

export type ScreenImageKey = keyof typeof SCREEN_IMAGES;

/** Default path for metadata / Open Graph (760w variant). */
export function screenImagePath(key: ScreenImageKey, phoneWidthPx = 380): string {
  return screenVariantPath(key, screenVariantForPhoneWidth(phoneWidthPx));
}

export function screenImageVariant(
  key: ScreenImageKey,
  variant: ScreenVariantWidth
): string {
  return screenVariantPath(key, variant);
}
