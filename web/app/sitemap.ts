import type { MetadataRoute } from "next";
import { abs } from "@/lib/site";

export const dynamic = "force-static";

type Freq = "monthly" | "yearly" | "weekly";

const routes: [string, number, Freq][] = [
  ["/", 1.0, "monthly"],
  ["/download", 0.9, "monthly"],
  ["/support", 0.8, "monthly"],
  ["/faq", 0.7, "monthly"],
  ["/changelog", 0.6, "weekly"],
  ["/blog", 0.6, "weekly"],
  ["/press", 0.5, "monthly"],
  ["/contact", 0.5, "yearly"],
  ["/privacy", 0.4, "yearly"],
  ["/terms", 0.4, "yearly"],
];

export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date();
  return routes.map(([path, priority, changeFrequency]) => ({
    url: abs(path),
    lastModified: now,
    changeFrequency,
    priority,
  }));
}
