"use client";

import Link from "next/link";
import { useI18n } from "@/lib/i18n";
import {
  blogPosts,
  blogPostPath,
  type BlogPost,
} from "@/lib/blog";

export default function BlogArticleFooter({ post }: { post: BlogPost }) {
  const { lang, localePath } = useI18n();

  const related = blogPosts
    .filter((p) => p.slug !== post.slug && p.category === post.category)
    .slice(0, 2);

  const copy =
    lang === "ru"
      ? {
          related: "Ещё по теме",
          experience: "Попробовать симулятор",
          download: "Установить WeekFit",
          privacy: "Политика конфиденциальности",
        }
      : {
          related: "Related reading",
          experience: "Try the Tuesday simulator",
          download: "Download WeekFit",
          privacy: "Privacy policy",
        };

  return (
    <footer className="blog-article-footer mt-14 border-t border-white/[0.06] pt-8">
      {related.length > 0 && (
        <div className="mb-8">
          <p className="kicker-sm mb-3">{copy.related}</p>
          <ul className="space-y-2 text-[15px]">
            {related.map((item) => (
              <li key={item.slug}>
                <Link
                  href={localePath(blogPostPath(item))}
                  className="text-white/62 transition-colors hover:text-white"
                >
                  {item.title[lang]}
                </Link>
              </li>
            ))}
          </ul>
        </div>
      )}

      <p className="text-[15px] leading-relaxed text-white/50">
        {lang === "ru" ? (
          <>
            Хотите увидеть, как коуч реагирует на ваши сигналы?{" "}
            <Link href={localePath("/experience")} className="text-white/72 underline-offset-2 hover:text-white hover:underline">
              {copy.experience}
            </Link>
            . WeekFit доступен через{" "}
            <Link href={localePath("/download")} className="text-white/72 underline-offset-2 hover:text-white hover:underline">
              {copy.download}
            </Link>
            . Данные остаются на устройстве — см.{" "}
            <Link href={localePath("/privacy")} className="text-white/72 underline-offset-2 hover:text-white hover:underline">
              {copy.privacy}
            </Link>
            .
          </>
        ) : (
          <>
            Want to see how the coach responds to your signals?{" "}
            <Link href={localePath("/experience")} className="text-white/72 underline-offset-2 hover:text-white hover:underline">
              {copy.experience}
            </Link>
            . WeekFit is available via{" "}
            <Link href={localePath("/download")} className="text-white/72 underline-offset-2 hover:text-white hover:underline">
              {copy.download}
            </Link>
            . Your data stays on device — see our{" "}
            <Link href={localePath("/privacy")} className="text-white/72 underline-offset-2 hover:text-white hover:underline">
              {copy.privacy}
            </Link>
            .
          </>
        )}
      </p>
    </footer>
  );
}
