import type { Locale } from "./locale";

export interface PageSeoCopy {
  title: string;
  description: string;
  socialTitle?: string;
  keywords?: string[];
}

export const HOME_SEO: Record<Locale, PageSeoCopy> = {
  en: {
    title: "WeekFit — What is today for?",
    description:
      "One clear call for today — what to do now, why it matters, and how to adjust. Private on your iPhone.",
    socialTitle: "WeekFit — Your AI coach, powered by Apple Health",
    keywords: [
      "WeekFit",
      "Week Fit",
      "AI coach",
      "Apple Health",
      "recovery score",
      "iPhone fitness app",
    ],
  },
  ru: {
    title: "WeekFit — Что важно сегодня?",
    description:
      "Один понятный вывод на сегодня — что делать сейчас, почему это важно и как подстроиться. Приватно на iPhone.",
    socialTitle: "WeekFit — Ваш AI-коуч на основе Apple Health",
    keywords: [
      "WeekFit",
      "Week Fit",
      "AI фитнес-коуч",
      "Apple Health",
      "показатель восстановления",
      "фитнес-приложение iPhone",
    ],
  },
};

export const PAGE_SEO = {
  "calorie-tracker": {
    en: {
      title: "Calorie tracker",
      description:
        "WeekFit is a calmer calorie and macro tracker for people who train — built around recovery, activity and Apple Health context. Private on your iPhone.",
      socialTitle: "WeekFit — Calorie tracker for training",
    },
    ru: {
      title: "Учёт питания",
      description:
        "WeekFit — спокойный учёт питания и БЖУ для тех, кто тренируется. Питание в контексте восстановления, активности и Apple Health. Приватно на iPhone.",
      socialTitle: "WeekFit — учёт питания под тренировки",
    },
  },
  "workout-planner": {
    en: {
      title: "Workout planner",
      description:
        "Plan your training week and adjust with recovery signals. WeekFit connects sleep, HRV and load into one calm daily decision — powered by Apple Health.",
      socialTitle: "WeekFit — Workout planner that adapts",
    },
    ru: {
      title: "План тренировок",
      description:
        "Планируйте неделю тренировок и корректируйте день по сигналам восстановления. WeekFit связывает сон, ВСР и нагрузку в один вывод — на основе Apple Health.",
      socialTitle: "WeekFit — план тренировок с учётом восстановления",
    },
  },
  "apple-health-fitness-app": {
    en: {
      title: "Apple Health fitness app",
      description:
        "An Apple Health fitness app that stays private. WeekFit turns Apple Health signals into daily guidance — no accounts, on-device first.",
      socialTitle: "WeekFit — Apple Health fitness app",
    },
    ru: {
      title: "Фитнес на Apple Health",
      description:
        "Фитнес‑приложение на Apple Health с приватностью по умолчанию. WeekFit превращает сигналы здоровья в ежедневный вывод — без аккаунта, всё на устройстве.",
      socialTitle: "WeekFit — фитнес на Apple Health",
    },
  },
  download: {
    en: {
      title: "Download",
      description:
        "Download WeekFit for iPhone on the App Store. An AI fitness coach that reads Apple Health data for recovery, activity and nutrition.",
      socialTitle: "Download WeekFit for iPhone",
    },
    ru: {
      title: "Скачать",
      description:
        "Скачайте WeekFit для iPhone в App Store. AI-коуч, который читает Apple Health: восстановление, активность и питание.",
      socialTitle: "Скачать WeekFit для iPhone",
    },
  },
  support: {
    en: {
      title: "Support",
      description:
        "WeekFit help center — setup guides, Apple Health troubleshooting, recovery score, nutrition and privacy.",
    },
    ru: {
      title: "Поддержка",
      description:
        "Центр помощи WeekFit — настройка, Apple Health, показатель восстановления, питание и приватность.",
    },
  },
  faq: {
    en: {
      title: "FAQ",
      description:
        "Frequently asked questions about WeekFit — the AI fitness coach, recovery score, Apple Health, nutrition tracking and privacy.",
    },
    ru: {
      title: "Частые вопросы",
      description:
        "Ответы о WeekFit — AI-коуч, показатель восстановления, Apple Health, питание и приватность.",
    },
  },
  changelog: {
    en: {
      title: "Changelog",
      description: "WeekFit release notes — new features, improvements and fixes.",
    },
    ru: {
      title: "Обновления",
      description: "История версий WeekFit — новые функции, улучшения и исправления.",
    },
  },
  blog: {
    en: {
      title: "Blog",
      description:
        "Guides on recovery, sleep, nutrition and training — and how an AI fitness coach turns Apple Health data into daily guidance.",
    },
    ru: {
      title: "Блог",
      description:
        "Гайды о восстановлении, сне, питании и тренировках — и как AI-коуч превращает Apple Health в ежедневные решения.",
    },
  },
  press: {
    en: {
      title: "Press Kit",
      description:
        "WeekFit press resources — app description, screenshots, icon assets and contact for media.",
    },
    ru: {
      title: "Пресс-кит",
      description:
        "Материалы для прессы WeekFit — описание, скриншоты, иконки и контакты для СМИ.",
    },
  },
  contact: {
    en: {
      title: "Contact",
      description: "Contact WeekFit support — questions, feedback and partnership inquiries.",
    },
    ru: {
      title: "Контакты",
      description: "Связаться с поддержкой WeekFit — вопросы, отзывы и предложения о сотрудничестве.",
    },
  },
  privacy: {
    en: {
      title: "Privacy Policy",
      description:
        "How WeekFit handles your data: local-first storage, Apple Health integration, no server upload, no advertising, no data sales.",
    },
    ru: {
      title: "Политика конфиденциальности",
      description:
        "Как WeekFit обрабатывает данные: локальное хранение, Apple Health, без загрузки на сервер, без рекламы и продажи данных.",
    },
  },
  terms: {
    en: {
      title: "Terms of Use",
      description:
        "WeekFit terms of use — eligibility, health disclaimer, Apple Health data, and acceptable use.",
    },
    ru: {
      title: "Условия использования",
      description:
        "Условия использования WeekFit — правила, отказ от медицинских гарантий, данные Apple Health.",
    },
  },
  experience: {
    en: {
      title: "Try it",
      description:
        "Interactive Tuesday simulator — adjust sleep, HRV and load to see how WeekFit makes your morning decision.",
      socialTitle: "Try WeekFit — Tuesday simulator",
    },
    ru: {
      title: "Попробовать",
      description:
        "Интерактивный симулятор — настройте сон, ВСР и нагрузку и посмотрите, как WeekFit делает утренний вывод.",
      socialTitle: "WeekFit — симулятор вторника",
    },
  },
} as const satisfies Record<string, Record<Locale, PageSeoCopy>>;

export const BREADCRUMB_HOME: Record<Locale, string> = {
  en: "Home",
  ru: "Главная",
};
