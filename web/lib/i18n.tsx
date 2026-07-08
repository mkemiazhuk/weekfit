"use client";

import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";

export type Lang = "en" | "ru";

const en = {
  nav: {
    features: "Experience",
    pillars: "How it understands you",
    privacy: "Privacy",
    download: "Download",
    support: "Support",
  },
  hero: {
    eyebrow: "A calm AI coach",
    titleA: "Your day,",
    titleB: "understood.",
    lead: "WeekFit reads your sleep, activity, nutrition and recovery — then tells you the one thing that matters today.",
    ctaPrimary: "Download",
    ctaSecondary: "See how it works",
    scroll: "Scroll to live the day",
  },
  morning: {
    kicker: "Morning",
    title: "Wake up to clarity.",
    body: "Before you even move, WeekFit interprets last night's sleep and recovery into one calm, confident read on your day.",
    ringLabel: "Recovery",
  },
  prep: {
    kicker: "Preparation",
    title: "Know exactly how to prepare.",
    body: "Fuel, hydration, and the right time to train — guidance that adapts to your plan, never a generic template.",
  },
  workout: {
    kicker: "Training",
    title: "Train in sync with your body.",
    body: "Workouts flow straight from Apple Health. Rings, energy and effort update the moment you finish.",
  },
  recovery: {
    kicker: "Recovery",
    title: "Recover like it matters.",
    body: "As the day softens, the Coach shifts toward recovery — stretching, nutrition, and a gentle path into sleep.",
  },
  night: {
    kicker: "Night",
    title: "The day winds down with you.",
    body: "Everything calms. Colors settle. WeekFit quietly prepares tomorrow while you rest.",
  },
  pillars: {
    kicker: "How it understands you",
    title: "Four signals. One clear story.",
    lead: "WeekFit doesn't just collect health data. It reads the relationships between four signals to explain what matters today.",
    items: {
      recovery: {
        name: "Recovery",
        desc: "Sleep, HRV and resting heart rate become a single readiness read.",
      },
      activity: {
        name: "Activity",
        desc: "Workouts and active energy, synced live from Apple Health.",
      },
      nutrition: {
        name: "Nutrition",
        desc: "Calories and macro balance, in the context of your day.",
      },
      hydration: {
        name: "Hydration",
        desc: "Fluid balance that adapts to training and heat.",
      },
    },
  },
  trust: {
    kicker: "Privacy",
    title: "Your health stays yours.",
    lead: "Privacy isn't a policy page. It's how WeekFit is built.",
    items: {
      device: {
        name: "On your device",
        desc: "Your plan and preferences live locally. No account required to start.",
      },
      health: {
        name: "Powered by Apple Health",
        desc: "WeekFit reads only what you allow, and only to personalize your day.",
      },
      noads: {
        name: "Never for sale",
        desc: "Health data is never used for advertising and never sold.",
      },
      notrack: {
        name: "No tracking",
        desc: "No third-party analytics, cross-app tracking or advertising IDs.",
      },
    },
    link: "Read the Privacy Policy",
  },
  cta: {
    title: "Meet the calm in your day.",
    body: "WeekFit is coming to the App Store. Built around Apple Health, private by design.",
    button: "Download on the App Store",
    soon: "Coming soon",
  },
  footer: {
    tagline: "A calm AI coach that understands your day.",
    product: "Product",
    resources: "Resources",
    legal: "Legal",
    experience: "Experience",
    download: "Download",
    pillars: "How it works",
    support: "Support",
    faq: "FAQ",
    changelog: "Changelog",
    press: "Press Kit",
    privacy: "Privacy",
    terms: "Terms",
    contact: "Contact",
    rights: "All rights reserved.",
    disclaimer:
      "WeekFit provides fitness and wellness guidance only and does not provide medical advice.",
  },
};

type Dict = typeof en;

// Russian mirrors the English structure.
const ru: Dict = {
  nav: {
    features: "Опыт",
    pillars: "Как это понимает вас",
    privacy: "Приватность",
    download: "Скачать",
    support: "Поддержка",
  },
  hero: {
    eyebrow: "Спокойный AI-коуч",
    titleA: "Ваш день —",
    titleB: "понятен.",
    lead: "WeekFit читает ваш сон, активность, питание и восстановление — и говорит одно: что важно сегодня.",
    ctaPrimary: "Скачать",
    ctaSecondary: "Как это работает",
    scroll: "Листайте, чтобы прожить день",
  },
  morning: {
    kicker: "Утро",
    title: "Проснитесь с ясностью.",
    body: "Ещё до того, как вы встали, WeekFit превращает прошлую ночь и восстановление в один спокойный и уверенный вывод о вашем дне.",
    ringLabel: "Восстановление",
  },
  prep: {
    kicker: "Подготовка",
    title: "Точно знайте, как подготовиться.",
    body: "Питание, гидратация и подходящее время для тренировки — рекомендации под ваш план, а не шаблон.",
  },
  workout: {
    kicker: "Тренировка",
    title: "Тренируйтесь в такт телу.",
    body: "Тренировки поступают напрямую из Apple Health. Кольца, энергия и усилие обновляются сразу после финиша.",
  },
  recovery: {
    kicker: "Восстановление",
    title: "Восстанавливайтесь как следует.",
    body: "Когда день смягчается, Коуч смещается к восстановлению — растяжка, питание и спокойный путь ко сну.",
  },
  night: {
    kicker: "Ночь",
    title: "День затихает вместе с вами.",
    body: "Всё успокаивается. Цвета гаснут. WeekFit тихо готовит завтрашний день, пока вы отдыхаете.",
  },
  pillars: {
    kicker: "Как это понимает вас",
    title: "Четыре сигнала. Одна ясная история.",
    lead: "WeekFit не просто собирает данные о здоровье. Он читает связи между четырьмя сигналами, чтобы объяснить, что важно сегодня.",
    items: {
      recovery: {
        name: "Восстановление",
        desc: "Сон, ВСР и пульс покоя складываются в единый показатель готовности.",
      },
      activity: {
        name: "Активность",
        desc: "Тренировки и активная энергия — синхронизация из Apple Health в реальном времени.",
      },
      nutrition: {
        name: "Питание",
        desc: "Калории и баланс макросов в контексте вашего дня.",
      },
      hydration: {
        name: "Гидратация",
        desc: "Баланс жидкости с учётом нагрузки и жары.",
      },
    },
  },
  trust: {
    kicker: "Приватность",
    title: "Ваше здоровье — ваше.",
    lead: "Приватность — это не страница с текстом. Это то, как устроен WeekFit.",
    items: {
      device: {
        name: "На вашем устройстве",
        desc: "План и настройки хранятся локально. Для старта аккаунт не нужен.",
      },
      health: {
        name: "На основе Apple Health",
        desc: "WeekFit читает только то, что вы разрешили, и только для персонализации дня.",
      },
      noads: {
        name: "Никогда не на продажу",
        desc: "Данные о здоровье никогда не используются для рекламы и не продаются.",
      },
      notrack: {
        name: "Без слежки",
        desc: "Без сторонней аналитики, кросс-приложенческого отслеживания и рекламных ID.",
      },
    },
    link: "Читать политику конфиденциальности",
  },
  cta: {
    title: "Найдите спокойствие в своём дне.",
    body: "WeekFit скоро появится в App Store. На основе Apple Health, приватный по умолчанию.",
    button: "Загрузить в App Store",
    soon: "Скоро",
  },
  footer: {
    tagline: "Спокойный AI-коуч, который понимает ваш день.",
    product: "Продукт",
    resources: "Ресурсы",
    legal: "Правовое",
    experience: "Опыт",
    download: "Скачать",
    pillars: "Как это работает",
    support: "Поддержка",
    faq: "Вопросы",
    changelog: "Изменения",
    press: "Пресс-кит",
    privacy: "Приватность",
    terms: "Условия",
    contact: "Контакты",
    rights: "Все права защищены.",
    disclaimer:
      "WeekFit даёт рекомендации по фитнесу и wellness и не заменяет медицинскую консультацию.",
  },
};

const dictionaries: Record<Lang, Dict> = { en, ru };

interface I18nValue {
  lang: Lang;
  setLang: (l: Lang) => void;
  t: Dict;
}

const I18nContext = createContext<I18nValue | null>(null);

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const [lang, setLangState] = useState<Lang>("en");

  useEffect(() => {
    let initial: Lang = "en";
    try {
      const saved = localStorage.getItem("weekfit_lang") as Lang | null;
      if (saved === "en" || saved === "ru") initial = saved;
      else if ((navigator.language || "en").toLowerCase().startsWith("ru"))
        initial = "ru";
    } catch {}
    setLangState(initial);
    document.documentElement.lang = initial;
  }, []);

  const setLang = useCallback((l: Lang) => {
    setLangState(l);
    document.documentElement.lang = l;
    try {
      localStorage.setItem("weekfit_lang", l);
    } catch {}
  }, []);

  const value = useMemo<I18nValue>(
    () => ({ lang, setLang, t: dictionaries[lang] }),
    [lang, setLang]
  );

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n(): I18nValue {
  const ctx = useContext(I18nContext);
  if (!ctx) throw new Error("useI18n must be used within I18nProvider");
  return ctx;
}
