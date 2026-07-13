import type { MetadataRoute } from "next";
import { absLocalized } from "@/lib/locale";
import { blogCategoryPath, blogCategoriesWithPosts, blogPostPath, blogPosts } from "@/lib/blog";
import { LOCALES } from "@/lib/locale";

export const dynamic = "force-static";

type Freq = "monthly" | "yearly" | "weekly";

const routes: [string, number, Freq][] = [
  ["/", 1.0, "monthly"],
  ["/experience", 0.95, "monthly"],
  ["/download", 0.9, "monthly"],
  ["/workout-planner", 0.75, "monthly"],
  ["/calorie-tracker", 0.75, "monthly"],
  ["/apple-health-fitness-app", 0.72, "monthly"],
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
  const entries: MetadataRoute.Sitemap = [];

  for (const locale of LOCALES) {
    for (const [path, priority, changeFrequency] of routes) {
      entries.push({
        url: absLocalized(path, locale),
        lastModified: now,
        changeFrequency,
        priority,
      });
    }

    for (const post of blogPosts) {
      entries.push({
        url: absLocalized(blogPostPath(post), locale),
        lastModified: new Date(post.date),
        changeFrequency: "monthly",
        priority: 0.55,
      });
    }

    for (const category of blogCategoriesWithPosts()) {
      entries.push({
        url: absLocalized(blogCategoryPath(category.slug), locale),
        lastModified: now,
        changeFrequency: "weekly",
        priority: 0.5,
      });
    }
  }

  return entries;
}
