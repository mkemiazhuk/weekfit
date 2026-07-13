import type { Locale } from "./locale";

export type LandingKey = "calorie-tracker" | "workout-planner" | "apple-health-fitness-app";

export type LandingCopy = {
  kicker: string;
  title: string;
  lead: string;
  highlightsTitle: string;
  highlights: string[];
  whoTitle: string;
  who: string[];
  faqTitle: string;
  faqs: { q: string; a: string }[];
};

export const SEO_LANDINGS: Record<LandingKey, Record<Locale, LandingCopy>> = {
  "calorie-tracker": {
    en: {
      kicker: "Calorie tracker",
      title: "A calmer calorie tracker for people who train",
      lead: "Calories and macros are useful — until they become a daily argument with yourself. WeekFit frames nutrition in context: training load, recovery, and the day you actually have.",
      highlightsTitle: "What makes it different",
      highlights: [
        "Designed for training days and recovery days — not “same target every day”.",
        "Nutrition is shown next to recovery and activity signals, so choices feel obvious.",
        "Private by design: no account required, on-device first.",
      ],
      whoTitle: "Good fit if you…",
      who: [
        "Train 3–6 days a week and want nutrition to support performance.",
        "Get stuck between “bulk/cut” advice and real life.",
        "Want something calmer than a guilt-based tracker.",
      ],
      faqTitle: "Common questions",
      faqs: [
        {
          q: "Is WeekFit a calorie counter?",
          a: "It can support calorie and macro awareness, but it’s built around context: recovery, activity and planning — so nutrition guidance stays practical.",
        },
        {
          q: "Does it integrate with Apple Health?",
          a: "Yes. WeekFit is powered by Apple Health signals like workouts, sleep and recovery metrics (with your permission).",
        },
      ],
    },
    ru: {
      kicker: "Учёт питания",
      title: "Спокойный «счётчик калорий» для тех, кто тренируется",
      lead: "Калории и БЖУ полезны — пока не превращаются в ежедневный спор с собой. WeekFit показывает питание в контексте: нагрузка, восстановление и ваш реальный день.",
      highlightsTitle: "Чем WeekFit отличается",
      highlights: [
        "Под тренировки и восстановление — а не «одна цель на каждый день».",
        "Питание рядом с сигналами восстановления и активности — решения становятся проще.",
        "Приватно: без аккаунта, всё в первую очередь на устройстве.",
      ],
      whoTitle: "Подойдёт, если вы…",
      who: [
        "Тренируетесь 3–6 раз в неделю и хотите, чтобы питание помогало прогрессу.",
        "Застреваете между советами «масса/сушка» и реальной жизнью.",
        "Хотите трекер без чувства вины и давления.",
      ],
      faqTitle: "Частые вопросы",
      faqs: [
        {
          q: "WeekFit — это счётчик калорий?",
          a: "Он помогает держать в голове калории и БЖУ, но основа — контекст: восстановление, активность и план недели. Так питание остаётся практичным.",
        },
        {
          q: "Есть интеграция с Apple Health?",
          a: "Да. WeekFit работает на данных Apple Health — тренировки, сон и метрики восстановления (с вашего разрешения).",
        },
      ],
    },
  },
  "workout-planner": {
    en: {
      kicker: "Workout planner",
      title: "A weekly workout planner that adapts to recovery",
      lead: "Planning is easy when your body cooperates. WeekFit keeps your week visible, then helps you adjust based on how you actually recovered — not how you hoped you would.",
      highlightsTitle: "What you get",
      highlights: [
        "A clear weekly plan — training, meals and recovery in one place.",
        "Daily guidance that connects sleep, HRV, resting heart rate and load.",
        "A calmer approach to consistency: adjust the day, keep the week.",
      ],
      whoTitle: "Good fit if you…",
      who: [
        "Want structure, but hate rigid plans that ignore recovery.",
        "Train for health and performance, not punishment.",
        "Use Apple Watch / Apple Health and want it to inform your plan.",
      ],
      faqTitle: "Common questions",
      faqs: [
        {
          q: "Is this a training plan generator?",
          a: "WeekFit helps you plan and adjust. It’s not a generic one-size-fits-all generator — it’s a coach-style layer on top of your signals.",
        },
        {
          q: "Can I plan recovery activities too?",
          a: "Yes — recovery blocks (walks, mobility, etc.) are part of the week, not an afterthought.",
        },
      ],
    },
    ru: {
      kicker: "План тренировок",
      title: "Недельный план тренировок, который учитывает восстановление",
      lead: "Планировать легко, когда тело «согласилось». WeekFit держит неделю перед глазами и помогает корректировать день по факту восстановления — а не по надеждам.",
      highlightsTitle: "Что вы получаете",
      highlights: [
        "Понятная неделя — тренировки, питание и восстановление в одном месте.",
        "Ежедневный вывод: сон, ВСР, пульс покоя и нагрузка связаны в одну картину.",
        "Спокойная системность: корректируем день — сохраняем неделю.",
      ],
      whoTitle: "Подойдёт, если вы…",
      who: [
        "Хотите структуру, но не любите жёсткие планы без учёта восстановления.",
        "Тренируетесь ради здоровья и прогресса, а не наказания.",
        "Пользуетесь Apple Watch / Apple Health и хотите опираться на данные.",
      ],
      faqTitle: "Частые вопросы",
      faqs: [
        {
          q: "WeekFit сам составит план тренировок?",
          a: "Он помогает планировать и корректировать. Это не «универсальный генератор», а коуч-слой поверх ваших сигналов.",
        },
        {
          q: "Можно планировать восстановление?",
          a: "Да — восстановление (прогулки, мобилити и т. п.) — часть недели, а не пункт «если успею».",
        },
      ],
    },
  },
  "apple-health-fitness-app": {
    en: {
      kicker: "Apple Health fitness app",
      title: "An Apple Health fitness app that stays private",
      lead: "WeekFit reads your Apple Health signals (with permission) and turns them into one calm decision each day. No accounts, no cloud sync of health data, and no advertising use of your metrics.",
      highlightsTitle: "Built around Apple Health",
      highlights: [
        "Recovery and readiness from sleep, HRV and resting heart rate.",
        "Workouts and activity context from Apple Watch / Health.",
        "Private by design: on-device first, no third-party ad tracking.",
      ],
      whoTitle: "Good fit if you…",
      who: [
        "Already track workouts and sleep in Apple Health.",
        "Want clearer guidance than a dashboard of numbers.",
        "Care about privacy and prefer local-first apps.",
      ],
      faqTitle: "Common questions",
      faqs: [
        {
          q: "Do I need an account?",
          a: "No. WeekFit is designed to work without sign-in.",
        },
        {
          q: "Do you upload my Health data?",
          a: "WeekFit is built as local-first. Your plan and preferences stay on-device, and HealthKit data is used only to provide features inside the app.",
        },
      ],
    },
    ru: {
      kicker: "Apple Health",
      title: "Фитнес‑приложение на Apple Health — с приватностью по умолчанию",
      lead: "WeekFit читает сигналы Apple Health (с вашего разрешения) и превращает их в один спокойный вывод на день. Без аккаунта, без выгрузки здоровья в облако и без использования метрик для рекламы.",
      highlightsTitle: "Основа — Apple Health",
      highlights: [
        "Готовность и восстановление: сон, ВСР и пульс покоя.",
        "Контекст нагрузки: тренировки и активность из Apple Watch / Health.",
        "Приватность: всё в первую очередь на устройстве, без рекламного трекинга.",
      ],
      whoTitle: "Подойдёт, если вы…",
      who: [
        "Уже ведёте тренировки и сон в Apple Health.",
        "Хотите вывод и смысл, а не ещё одну панель цифр.",
        "Цените приватность и предпочитаете локальные приложения.",
      ],
      faqTitle: "Частые вопросы",
      faqs: [
        {
          q: "Нужен аккаунт?",
          a: "Нет. WeekFit задуман так, чтобы работать без регистрации.",
        },
        {
          q: "Вы куда-то выгружаете данные здоровья?",
          a: "WeekFit построен как local-first: план и настройки остаются на устройстве, а данные HealthKit используются только для функций внутри приложения.",
        },
      ],
    },
  },
};

