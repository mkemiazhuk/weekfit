"use client";

import Image from "next/image";

type Variant = "today" | "food" | "meals" | "activity" | "recovery" | "coach";

const SCREENS: Record<Variant, { src: string; alt: string }> = {
  today: { src: "/img/app/today.png", alt: "WeekFit Today" },
  activity: { src: "/img/app/today.png", alt: "WeekFit Today" },
  food: { src: "/img/app/food.png", alt: "WeekFit food recognition" },
  meals: { src: "/img/app/food.png", alt: "WeekFit food recognition" },
  recovery: { src: "/img/app/recovery.png", alt: "WeekFit Recovery" },
  coach: { src: "/img/app/maya.png", alt: "Maya, the WeekFit voice coach" },
};

export default function AppScreen({
  variant = "today",
  priority = false,
}: {
  variant?: Variant;
  priority?: boolean;
}) {
  const screen = SCREENS[variant];
  return (
    <Image
      src={screen.src}
      alt={screen.alt}
      width={472}
      height={1024}
      priority={priority}
      sizes="(max-width: 767px) 280px, 380px"
      className="h-full w-full object-cover object-top"
    />
  );
}

export function appScreenForKey(key: string): Variant {
  switch (key) {
    case "meals":
    case "prep":
    case "nutrition":
    case "food":
      return "food";
    case "recovery":
      return "recovery";
    case "coach":
    case "night":
      return "coach";
    default:
      return "today";
  }
}

export function appScreenForJourney(key: string): Variant {
  switch (key) {
    case "prep":
      return "food";
    case "recovery":
      return "recovery";
    case "night":
      return "coach";
    default:
      return "today";
  }
}
