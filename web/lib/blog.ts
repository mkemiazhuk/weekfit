import type { Lang } from "./i18n";
import type { IconName } from "@/components/Icon";

// ============================================================
// Blog architecture (content-ready, articles pending).
//
// Planned routes once articles exist:
//   /blog                     → this index
//   /blog/[category]          → category archive (generateStaticParams)
//   /blog/[category]/[slug]   → article
//
// To ship articles: populate `blogPosts`, then add the dynamic
// route folders with generateStaticParams derived from this data.
// ============================================================

export interface BlogCategory {
  slug: string;
  icon: IconName;
  color: string;
  name: Record<Lang, string>;
  desc: Record<Lang, string>;
}

export interface BlogPost {
  slug: string;
  category: string; // BlogCategory.slug
  date: string; // ISO
  title: Record<Lang, string>;
  excerpt: Record<Lang, string>;
  body?: Record<Lang, string>;
}

export const blogCategories: BlogCategory[] = [
  {
    slug: "recovery",
    icon: "recovery",
    color: "#2edbfa",
    name: { en: "Recovery", ru: "Восстановление" },
    desc: {
      en: "Readiness, HRV, resting heart rate and how to train with your recovery, not against it.",
      ru: "Готовность, ВСР, пульс покоя и как тренироваться в согласии с восстановлением, а не против него.",
    },
  },
  {
    slug: "nutrition",
    icon: "nutrition",
    color: "#ff9424",
    name: { en: "Nutrition", ru: "Питание" },
    desc: {
      en: "Fuelling for training, protein and macro balance, and eating for the day you actually have.",
      ru: "Питание под тренировки, белок и баланс БЖУ, еда под ваш реальный день.",
    },
  },
  {
    slug: "training",
    icon: "activity",
    color: "#66f070",
    name: { en: "Training", ru: "Тренировки" },
    desc: {
      en: "Workout planning, effort management and building a week that adapts to your body.",
      ru: "Планирование тренировок, управление нагрузкой и неделя, которая подстраивается под тело.",
    },
  },
  {
    slug: "sleep",
    icon: "recovery",
    color: "#ad8fe6",
    name: { en: "Sleep", ru: "Сон" },
    desc: {
      en: "Sleep analysis, why last night matters today, and simple ways to sleep more deeply.",
      ru: "Анализ сна, почему прошедшая ночь важна сегодня, и как спать глубже.",
    },
  },
  {
    slug: "apple-health",
    icon: "health",
    color: "#4088f2",
    name: { en: "Apple Health", ru: "Apple Health" },
    desc: {
      en: "Getting the most from Apple Health and HealthKit inside a private, on-device coach.",
      ru: "Как получить максимум от Apple Health и HealthKit в приватном коуче на устройстве.",
    },
  },
  {
    slug: "wellness",
    icon: "sparkles",
    color: "#f5bf5c",
    name: { en: "Wellness", ru: "Здоровье" },
    desc: {
      en: "Habits, hydration and the small daily choices that compound into feeling good.",
      ru: "Привычки, вода и маленькие ежедневные решения, из которых складывается хорошее самочувствие.",
    },
  },
  {
    slug: "coach",
    icon: "coach",
    color: "#8c66d9",
    name: { en: "Coach", ru: "Коуч" },
    desc: {
      en: "How the WeekFit AI coach reads your signals and decides what matters most today.",
      ru: "Как AI-коуч WeekFit читает ваши сигналы и решает, что важнее всего сегодня.",
    },
  },
];

export const blogPosts: BlogPost[] = []; // articles land here

export const blogCopy: Record<
  Lang,
  { kicker: string; title: string; lead: string; empty: string; categoriesTitle: string }
> = {
  en: {
    kicker: "Blog",
    title: "Guides & insights",
    lead: "Practical writing on recovery, sleep, nutrition and training — and how a daily AI coach helps you act on them. New articles are on the way.",
    empty: "The first articles are being written. In the meantime, here's what we'll be covering.",
    categoriesTitle: "Topics",
  },
  ru: {
    kicker: "Блог",
    title: "Гайды и заметки",
    lead: "Практичные тексты о восстановлении, сне, питании и тренировках — и о том, как ежедневный AI-коуч помогает применять это на деле. Новые статьи уже готовятся.",
    empty: "Первые статьи ещё пишутся. А пока — вот темы, которые мы разберём.",
    categoriesTitle: "Темы",
  },
};
