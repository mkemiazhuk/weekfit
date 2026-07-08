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
    home: "Home",
    features: "Experience",
    pillars: "How it understands you",
    privacy: "Privacy",
    download: "Download",
    support: "Support",
    menu: "Menu",
    closeMenu: "Close menu",
  },
  hero: {
    eyebrow: "AI that reasons",
    titleA: "Your body,",
    titleB: "understood.",
    lead: "Sleep, recovery, activity, nutrition — connected. One clear decision, every morning.",
    coachTitle: "Move today.",
    coachBody: "Strong recovery. Residual ride fatigue — move today, push tomorrow.",
    ctaPrimary: "Get notified",
    ctaSecondary: "See how it works",
    scroll: "Scroll to live the day",
  },
  morning: {
    kicker: "Morning",
    title: "Wake up to clarity.",
    body: "Sleep and recovery become one calm read — before you decide anything.",
    ringLabel: "Recovery",
  },
  prep: {
    kicker: "Preparation",
    title: "Know how to prepare.",
    body: "Fuel, hydration, timing — adapted to your plan, not a template.",
  },
  workout: {
    kicker: "Training",
    title: "Train in sync.",
    body: "Workouts from Apple Health. Rings update the moment you finish.",
  },
  recovery: {
    kicker: "Recovery",
    title: "Recover like it matters.",
    body: "The Coach shifts toward stretching, nutrition, and sleep as the day softens.",
  },
  night: {
    kicker: "Night",
    title: "Wind down together.",
    body: "Everything calms. WeekFit quietly prepares tomorrow.",
  },
  reasoning: {
    kicker: "The Coach",
    title: "Watch it think.",
    yesterday: "Yesterday",
    signals: [
      "Slept 8h 12m",
      "HRV +12%",
      "16 km cycling",
      "Protein target reached",
    ],
    analyzing: "Analyzing relationships",
    priority: "Today's priority",
    priorityValue: "Recovery",
    reasonLabel: "Why",
    reason:
      "Cardiovascular recovery is excellent. Muscular fatigue from yesterday's ride remains elevated.",
    recommendationLabel: "Recommendation",
    recommendationToday: "Move today.",
    recommendationTomorrow: "Push hard tomorrow.",
  },
  seo: {
    kicker: "What is WeekFit",
    title: "An AI fitness coach for Apple Health.",
    p1: "One daily read from sleep, recovery, activity and nutrition — with the reasoning behind it. Private, on your device.",
    features: [
      "Recovery score",
      "Sleep & readiness",
      "Nutrition balance",
      "Weekly planning",
      "Apple Health sync",
      "On-device privacy",
    ],
  },
  pillars: {
    kicker: "How it understands you",
    title: "Four signals. One story.",
    lead: "WeekFit reads the relationships between four signals — not just the numbers.",
    items: {
      recovery: {
        name: "Recovery",
        desc: "Sleep, HRV and resting heart rate → one readiness read.",
      },
      activity: {
        name: "Activity",
        desc: "Workouts and energy, live from Apple Health.",
      },
      nutrition: {
        name: "Nutrition",
        desc: "Macros in the context of your day.",
      },
      hydration: {
        name: "Hydration",
        desc: "Fluid balance for training and heat.",
      },
    },
  },
  trust: {
    kicker: "Privacy",
    title: "Your health stays yours.",
    lead: "Built private from the inside out.",
    items: {
      device: {
        name: "On your device",
        desc: "Plans and preferences stay local. No account required.",
      },
      health: {
        name: "Powered by Apple Health",
        desc: "Reads only what you allow. Only to personalize your day.",
      },
      noads: {
        name: "Never for sale",
        desc: "Health data never used for ads. Never sold.",
      },
      notrack: {
        name: "No tracking",
        desc: "No third-party analytics or advertising IDs.",
      },
    },
    link: "Read the Privacy Policy",
  },
  cta: {
    title: "Ready to stop guessing?",
    subtitle: "Wake up knowing exactly what matters today.",
    body: "Join the public beta on TestFlight. Built around Apple Health, private by design.",
    button: "Download on the App Store",
    notify: "Get notified",
    testflight: "Join the beta",
    testflightNote: "Free public beta on TestFlight",
    soon: "App Store — coming soon",
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
    blog: "Blog",
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
    home: "Главная",
    features: "Обзор",
    pillars: "Как он вас понимает",
    privacy: "Приватность",
    download: "Скачать",
    support: "Поддержка",
    menu: "Меню",
    closeMenu: "Закрыть меню",
  },
  hero: {
    eyebrow: "ИИ, который рассуждает",
    titleA: "Ваше тело —",
    titleB: "понято.",
    lead: "Сон, восстановление, активность, питание — связаны. Одно ясное решение каждое утро.",
    coachTitle: "Движение сегодня.",
    coachBody: "Восстановление сильное. Усталость после поездки — движение сегодня, интенсив завтра.",
    ctaPrimary: "Сообщить о запуске",
    ctaSecondary: "Как это работает",
    scroll: "Листайте, чтобы прожить день",
  },
  morning: {
    kicker: "Утро",
    title: "Ясность с самого утра.",
    body: "Сон и восстановление — один спокойный вывод, ещё до первого решения.",
    ringLabel: "Восстановление",
  },
  prep: {
    kicker: "Подготовка",
    title: "Знайте, как подготовиться.",
    body: "Питание, вода, время — под ваш план, не шаблон.",
  },
  workout: {
    kicker: "Тренировка",
    title: "Тренируйтесь в такт.",
    body: "Тренировки из Apple Health. Кольца обновляются сразу после.",
  },
  recovery: {
    kicker: "Восстановление",
    title: "Восстанавливайтесь как следует.",
    body: "К вечеру Коуч смещается к растяжке, питанию и сну.",
  },
  night: {
    kicker: "Ночь",
    title: "Затихайте вместе.",
    body: "Всё успокаивается. WeekFit тихо готовит завтра.",
  },
  reasoning: {
    kicker: "Коуч",
    title: "Смотрите, как он думает.",
    yesterday: "Вчера",
    signals: [
      "Сон 8ч 12м",
      "ВСР +12%",
      "16 км велосипед",
      "Белок — цель достигнута",
    ],
    analyzing: "Анализ связей",
    priority: "Приоритет сегодня",
    priorityValue: "Восстановление",
    reasonLabel: "Почему",
    reason:
      "Сердечно-сосудистое восстановление отличное. Мышечная усталость после вчерашней поездки всё ещё повышена.",
    recommendationLabel: "Рекомендация",
    recommendationToday: "Движение сегодня.",
    recommendationTomorrow: "Интенсив — завтра.",
  },
  seo: {
    kicker: "Что такое WeekFit",
    title: "AI-коуч по фитнесу на основе Apple Health.",
    p1: "Один вывод в день из сна, восстановления, активности и питания — с объяснением. Приватно, на устройстве.",
    features: [
      "Показатель восстановления",
      "Сон и готовность",
      "Баланс питания",
      "План на неделю",
      "Синхронизация с Apple Health",
      "Приватность на устройстве",
    ],
  },
  pillars: {
    kicker: "Как он вас понимает",
    title: "Четыре сигнала. Одна картина.",
    lead: "WeekFit видит связи между четырьмя сигналами — не только цифры.",
    items: {
      recovery: {
        name: "Восстановление",
        desc: "Сон, ВСР и пульс покоя → один показатель готовности.",
      },
      activity: {
        name: "Активность",
        desc: "Тренировки и энергия — из Apple Health.",
      },
      nutrition: {
        name: "Питание",
        desc: "БЖУ в контексте вашего дня.",
      },
      hydration: {
        name: "Вода",
        desc: "Баланс жидкости под нагрузку и жару.",
      },
    },
  },
  trust: {
    kicker: "Приватность",
    title: "Ваше здоровье остаётся вашим.",
    lead: "Приватность заложена в основу.",
    items: {
      device: {
        name: "На вашем устройстве",
        desc: "План и настройки локально. Аккаунт не нужен.",
      },
      health: {
        name: "На основе Apple Health",
        desc: "Читает только то, что вы разрешили.",
      },
      noads: {
        name: "Не для продажи",
        desc: "Данные не идут в рекламу и не продаются.",
      },
      notrack: {
        name: "Без слежки",
        desc: "Без сторонней аналитики и рекламных ID.",
      },
    },
    link: "Читать политику конфиденциальности",
  },
  cta: {
    title: "Хватит гадать.",
    subtitle: "Просыпайтесь, зная, что важно сегодня.",
    body: "Открытая бета в TestFlight. Apple Health, приватность в основе.",
    button: "Загрузить в App Store",
    notify: "Сообщить о запуске",
    testflight: "Открыть бету",
    testflightNote: "Открытая бета в TestFlight",
    soon: "App Store — скоро",
  },
  footer: {
    tagline: "Спокойный AI-коуч, который понимает ваш день.",
    product: "Продукт",
    resources: "Ресурсы",
    legal: "Документы",
    experience: "Обзор",
    download: "Скачать",
    pillars: "Как это работает",
    support: "Поддержка",
    faq: "Частые вопросы",
    changelog: "Обновления",
    press: "Пресс-кит",
    blog: "Блог",
    privacy: "Приватность",
    terms: "Условия",
    contact: "Контакты",
    rights: "Все права защищены.",
    disclaimer:
      "WeekFit даёт рекомендации по фитнесу и здоровому образу жизни и не заменяет консультацию врача.",
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
