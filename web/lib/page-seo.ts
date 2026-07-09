import type { Locale } from "./locale";

export interface PageSeoCopy {
  title: string;
  description: string;
  socialTitle?: string;
}

export const HOME_SEO: Record<Locale, PageSeoCopy> = {
  en: {
    title: "WeekFit — What is today for?",
    description:
      "WeekFit reads Apple Health and gives you one clear decision every morning — push, hold, or recover — with visible reasoning. Private on your iPhone.",
    socialTitle: "WeekFit — Know what today is for",
  },
  ru: {
    title: "WeekFit — Для чего сегодня?",
    description:
      "WeekFit читает Apple Health и каждое утро даёт одно ясное решение — давить, держать или восстанавливаться — с объяснением. Приватно на iPhone.",
    socialTitle: "WeekFit — Для чего сегодня?",
  },
};

export const PAGE_SEO = {
  download: {
    en: {
      title: "Download",
      description:
        "Install WeekFit on iPhone via TestFlight. An AI fitness coach that reads Apple Health data for recovery, activity and nutrition.",
      socialTitle: "Download WeekFit for iPhone",
    },
    ru: {
      title: "Скачать",
      description:
        "Установите WeekFit на iPhone через TestFlight. AI-коуч, который читает Apple Health: восстановление, активность и питание.",
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
