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
    eyebrow: "A calm AI coach",
    titleA: "Your day,",
    titleB: "understood.",
    lead: "WeekFit reads your sleep, activity, nutrition and recovery — then tells you the one thing that matters today.",
    ctaPrimary: "Get notified",
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
  seo: {
    kicker: "What is WeekFit",
    title: "A daily AI fitness coach, built around Apple Health.",
    p1: "WeekFit turns the health data you already have into a clear plan for the day. It reads your sleep, recovery, activity and nutrition from Apple Health and combines them into a single readiness score — so you always know whether to push or hold back.",
    p2: "It works like a coach, not a dashboard. Recovery tracking, sleep analysis, nutrition tracking and weekly workout planning come together in one calm daily read, with the reasoning behind every recommendation — and everything stays private, on your device.",
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
  why: {
    kicker: "Why WeekFit",
    title: "From data to what to do.",
    lead: "Most health apps show you numbers. WeekFit reads them together and tells you what actually matters today — so you spend less energy deciding and more doing.",
    items: {
      data: {
        name: "Most apps stop at data",
        desc: "Charts, rings and stats show what happened. They rarely tell you what to do next.",
      },
      matters: {
        name: "WeekFit finds what matters today",
        desc: "It reads sleep, recovery, activity and nutrition together and surfaces the one thing worth your attention.",
      },
      doing: {
        name: "Less deciding, more doing",
        desc: "One clear daily read means less second-guessing — and an obvious next step.",
      },
    },
  },
  cta: {
    title: "Meet the calm in your day.",
    body: "WeekFit is coming to the App Store. Built around Apple Health, private by design.",
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
    eyebrow: "Спокойный AI-коуч",
    titleA: "Ваш день —",
    titleB: "как на ладони.",
    lead: "WeekFit читает ваш сон, активность, питание и восстановление — и подсказывает главное: что важно именно сегодня.",
    ctaPrimary: "Сообщить о запуске",
    ctaSecondary: "Как это работает",
    scroll: "Листайте, чтобы прожить день",
  },
  morning: {
    kicker: "Утро",
    title: "Ясность с самого утра.",
    body: "Ещё до подъёма WeekFit превращает прошедшую ночь и восстановление в один спокойный и уверенный вывод о вашем дне.",
    ringLabel: "Восстановление",
  },
  prep: {
    kicker: "Подготовка",
    title: "Точно знайте, как подготовиться.",
    body: "Питание, питьевой режим и удачное время для тренировки — советы под ваш план, а не общий шаблон.",
  },
  workout: {
    kicker: "Тренировка",
    title: "Тренируйтесь в такт телу.",
    body: "Тренировки подтягиваются прямо из Apple Health. Кольца, энергия и нагрузка обновляются, как только вы закончили.",
  },
  recovery: {
    kicker: "Восстановление",
    title: "Восстанавливайтесь как следует.",
    body: "К вечеру Коуч смещает фокус на восстановление — растяжка, питание и спокойный путь ко сну.",
  },
  night: {
    kicker: "Ночь",
    title: "День затихает вместе с вами.",
    body: "Всё успокаивается, цвета гаснут. WeekFit тихо готовит завтрашний день, пока вы отдыхаете.",
  },
  seo: {
    kicker: "Что такое WeekFit",
    title: "Ежедневный AI-коуч по фитнесу на основе Apple Health.",
    p1: "WeekFit превращает данные о здоровье, которые у вас уже есть, в понятный план на день. Он читает сон, восстановление, активность и питание из Apple Health и сводит их в единый показатель готовности — чтобы вы всегда знали, стоит ли прибавить или лучше сбавить.",
    p2: "Он работает как коуч, а не как панель с цифрами. Контроль восстановления, анализ сна, учёт питания и планирование тренировок на неделю складываются в один спокойный вывод на день — с объяснением каждой рекомендации. И всё остаётся приватным, на вашем устройстве.",
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
    title: "Четыре сигнала. Одна понятная картина.",
    lead: "WeekFit не просто собирает данные о здоровье. Он видит связи между четырьмя сигналами и объясняет, что важно сегодня.",
    items: {
      recovery: {
        name: "Восстановление",
        desc: "Сон, ВСР и пульс покоя складываются в единый показатель готовности.",
      },
      activity: {
        name: "Активность",
        desc: "Тренировки и активная энергия — синхронно из Apple Health, в реальном времени.",
      },
      nutrition: {
        name: "Питание",
        desc: "Калории и баланс БЖУ в контексте вашего дня.",
      },
      hydration: {
        name: "Вода",
        desc: "Баланс жидкости с учётом нагрузки и жары.",
      },
    },
  },
  trust: {
    kicker: "Приватность",
    title: "Ваше здоровье остаётся вашим.",
    lead: "Приватность — это не страница с текстом. Это то, как устроен WeekFit изнутри.",
    items: {
      device: {
        name: "На вашем устройстве",
        desc: "План и настройки хранятся локально. Чтобы начать, аккаунт не нужен.",
      },
      health: {
        name: "На основе Apple Health",
        desc: "WeekFit читает только то, что вы разрешили, и только чтобы настроить день под вас.",
      },
      noads: {
        name: "Не для продажи",
        desc: "Данные о здоровье никогда не идут в рекламу и не продаются.",
      },
      notrack: {
        name: "Без слежки",
        desc: "Без сторонней аналитики, отслеживания между приложениями и рекламных идентификаторов.",
      },
    },
    link: "Читать политику конфиденциальности",
  },
  why: {
    kicker: "Зачем WeekFit",
    title: "От данных — к действию.",
    lead: "Большинство приложений показывают цифры. WeekFit читает их вместе и подсказывает, что действительно важно сегодня — чтобы вы меньше размышляли и больше делали.",
    items: {
      data: {
        name: "Большинство приложений останавливаются на данных",
        desc: "Графики, кольца и статистика показывают, что произошло. Но редко — что делать дальше.",
      },
      matters: {
        name: "WeekFit находит, что важно сегодня",
        desc: "Он читает сон, восстановление, активность и питание вместе и выделяет главное, на что стоит обратить внимание.",
      },
      doing: {
        name: "Меньше решать, больше делать",
        desc: "Один понятный вывод в день — меньше сомнений и очевидный следующий шаг.",
      },
    },
  },
  cta: {
    title: "Впустите спокойствие в свой день.",
    body: "WeekFit скоро появится в App Store. Работает на данных Apple Health, приватность — в основе.",
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
