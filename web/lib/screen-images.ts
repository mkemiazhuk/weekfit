/** Photographic screenshots — WebP with JPG fallback paths. */
export const SCREEN_IMAGES = {
  today: { webp: "/img/today.webp", jpg: "/img/today.jpg", width: 900, height: 1950 },
  meals: { webp: "/img/meals.webp", jpg: "/img/meals.jpg", width: 900, height: 1950 },
  activity: { webp: "/img/activity.webp", jpg: "/img/activity.jpg", width: 900, height: 1950 },
  recovery: { webp: "/img/recovery.webp", jpg: "/img/recovery.jpg", width: 900, height: 1950 },
  coach: { webp: "/img/coach.webp", jpg: "/img/coach.jpg", width: 900, height: 1950 },
} as const;

export type ScreenImageKey = keyof typeof SCREEN_IMAGES;

export function screenImagePath(key: ScreenImageKey): string {
  return SCREEN_IMAGES[key].webp;
}
