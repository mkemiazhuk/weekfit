import type { MetadataRoute } from "next";

export const dynamic = "force-static";

const base = "https://weekfit.app";

export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date();
  const page = (
    path: string,
    priority: number,
    changeFrequency: "monthly" | "yearly" | "weekly"
  ) => ({ url: `${base}${path}`, lastModified: now, changeFrequency, priority });
  return [
    page("/", 1, "monthly"),
    page("/download", 0.9, "monthly"),
    page("/support", 0.7, "monthly"),
    page("/faq", 0.6, "monthly"),
    page("/changelog", 0.6, "weekly"),
    page("/press", 0.5, "monthly"),
    page("/privacy", 0.5, "yearly"),
    page("/terms", 0.5, "yearly"),
    page("/contact", 0.5, "yearly"),
  ];
}
