import type { Lang } from "./dictionaries";
import type { DocSection } from "./content";
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
  sections: Record<Lang, DocSection[]>;
  readMinutes: number;
}

export function blogPostPath(post: Pick<BlogPost, "category" | "slug">): string {
  return `/blog/${post.category}/${post.slug}`;
}

export function getBlogPost(category: string, slug: string): BlogPost | undefined {
  return blogPosts.find((p) => p.category === category && p.slug === slug);
}

export function blogStaticParams() {
  return blogPosts.map((p) => ({ category: p.category, slug: p.slug }));
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

export const blogPosts: BlogPost[] = [
  {
    slug: "what-is-a-recovery-score",
    category: "recovery",
    date: "2026-07-08",
    readMinutes: 6,
    title: {
      en: "What is a recovery score — and how WeekFit calculates yours",
      ru: "Что такое показатель восстановления — и как WeekFit его считает",
    },
    excerpt: {
      en: "Sleep, HRV and resting heart rate combined into one daily readiness read — with the reasoning behind it.",
      ru: "Сон, ВСР и пульс покоя в одном показателе готовности на день — с объяснением, откуда он берётся.",
    },
    sections: {
      en: [
        {
          id: "why-one-number",
          h: "Why a single recovery score?",
          blocks: [
            {
              t: "p",
              v: "Most fitness apps show you a dashboard of numbers — hours slept, HRV in milliseconds, resting heart rate, training load. The problem is not missing data. It is knowing what those numbers mean together, today.",
            },
            {
              t: "p",
              v: "A recovery score answers one practical question: how ready is your body for what you planned — or what life throws at you? WeekFit reads Apple Health overnight and turns sleep, heart rate variability (HRV) and resting heart rate into one calm read each morning.",
            },
          ],
        },
        {
          id: "signals",
          h: "The signals behind the score",
          blocks: [
            {
              t: "p",
              v: "WeekFit weighs four groups of signals. Each compares last night to your recent baseline — not a generic population average.",
            },
            {
              t: "ul",
              v: [
                "Sleep duration — did you get enough time in bed relative to your typical week?",
                "Bedtime consistency — are you going to sleep around the same time?",
                "Sleep continuity and architecture — how fragmented was the night, and how much deep and REM sleep did you get?",
                "Cardiovascular recovery — HRV and resting heart rate versus your baseline.",
              ],
            },
            {
              t: "p",
              v: "Prior-day training load can pull the score down when muscular or cardiovascular fatigue is still elevated — even if sleep looked fine on paper.",
            },
          ],
        },
        {
          id: "not-a-diagnosis",
          h: "An estimate, not a diagnosis",
          blocks: [
            {
              t: "p",
              v: "Recovery scores are useful daily guides, not medical tests. WeekFit is explicit about this: the score compares you to you, over recent nights, and explains which factors moved it most.",
            },
            {
              t: "p",
              v: "That transparency matters. A number without context is just another metric to stress about. A number with reasoning — \"most points came from sleep duration\" or \"HRV is below your baseline\" — is something you can act on.",
            },
          ],
        },
        {
          id: "how-coach-uses-it",
          h: "How the Coach uses recovery",
          blocks: [
            {
              t: "p",
              v: "The recovery score is not the whole story. WeekFit's AI Coach combines it with yesterday's activity, nutrition and your weekly plan to decide what matters most today — move, recover, or prepare.",
            },
            {
              t: "p",
              v: "Strong recovery after a hard ride might still mean \"move today, push hard tomorrow\" if muscular fatigue is elevated. A moderate score on a rest day might mean focus on sleep and nutrition instead of forcing a workout.",
            },
          ],
        },
        {
          id: "getting-started",
          h: "Getting started with Apple Health",
          blocks: [
            {
              t: "p",
              v: "WeekFit needs read access to sleep, heart rate and workouts in Apple Health. After one or two nights of data, your baseline forms and the recovery breakdown becomes meaningful.",
            },
            {
              t: "p",
              v: "Everything stays on your iPhone. No account, no cloud upload of health data — the score is calculated locally from the signals you already collect.",
            },
          ],
        },
      ],
      ru: [
        {
          id: "why-one-number",
          h: "Зачем один показатель?",
          blocks: [
            {
              t: "p",
              v: "Большинство фитнес-приложений показывают панель цифр — часы сна, ВСР в миллисекундах, пульс покоя, нагрузка. Проблема не в нехватке данных, а в том, чтобы понять, что они значат вместе — сегодня.",
            },
            {
              t: "p",
              v: "Показатель восстановления отвечает на практический вопрос: насколько тело готово к запланированному — или к тому, что принесёт день? WeekFit читает Apple Health за ночь и превращает сон, вариабельность сердечного ритма (ВСР) и пульс покоя в один спокойный вывод каждое утро.",
            },
          ],
        },
        {
          id: "signals",
          h: "Сигналы за цифрой",
          blocks: [
            {
              t: "p",
              v: "WeekFit учитывает четыре группы сигналов. Каждый сравнивает прошедшую ночь с вашей недавней базой — не со средним по популяции.",
            },
            {
              t: "ul",
              v: [
                "Длительность сна — достаточно ли времени относительно вашей типичной недели?",
                "Стабильность времени отхода ко сну — ложитесь ли вы примерно в одно время?",
                "Непрерывность и архитектура сна — насколько фрагментирована ночь, сколько глубокого и REM-сна?",
                "Сердечно-сосудистое восстановление — ВСР и пульс покоя относительно вашей базы.",
              ],
            },
            {
              t: "p",
              v: "Нагрузка прошлого дня может снизить показатель, если мышечная или сердечно-сосудистая усталость ещё высока — даже если сон на бумаге выглядел нормально.",
            },
          ],
        },
        {
          id: "not-a-diagnosis",
          h: "Оценка, а не диагноз",
          blocks: [
            {
              t: "p",
              v: "Показатели восстановления — полезные ежедневные ориентиры, а не медицинские тесты. WeekFit прямо говорит об этом: цифра сравнивает вас с вами за последние ночи и объясняет, какие факторы повлияли сильнее всего.",
            },
            {
              t: "p",
              v: "Прозрачность важна. Число без контекста — ещё одна метрика для тревоги. Число с объяснением — «больше всего баллов дала длительность сна» или «ВСР ниже вашей базы» — то, на что можно опереться.",
            },
          ],
        },
        {
          id: "how-coach-uses-it",
          h: "Как Коуч использует восстановление",
          blocks: [
            {
              t: "p",
              v: "Показатель восстановления — не вся картина. AI-коуч WeekFit сочетает его с вчерашней активностью, питанием и недельным планом, чтобы решить, что важнее сегодня — двигаться, восстанавливаться или готовиться.",
            },
            {
              t: "p",
              v: "Хорошее восстановление после тяжёлой поездки может означать «движение сегодня, интенсив завтра», если мышечная усталость ещё повышена. Умеренный показатель в день отдыха — повод сфокусироваться на сне и питании, а не форсировать тренировку.",
            },
          ],
        },
        {
          id: "getting-started",
          h: "С чего начать с Apple Health",
          blocks: [
            {
              t: "p",
              v: "WeekFit нужен доступ на чтение к сну, пульсу и тренировкам в Apple Health. После одной-двух ночей данных формируется база, и разбор восстановления становится осмысленным.",
            },
            {
              t: "p",
              v: "Всё остаётся на iPhone. Без аккаунта, без загрузки данных о здоровье в облако — показатель считается локально из сигналов, которые вы уже собираете.",
            },
          ],
        },
      ],
    },
  },
  {
    slug: "vo2-max-plain-language",
    category: "training",
    date: "2026-07-02",
    readMinutes: 5,
    title: {
      en: "VO₂ max, in plain language",
      ru: "VO₂ max простыми словами",
    },
    excerpt: {
      en: "Apple Watch gives you a number. Here’s what it actually means — and what to do with it.",
      ru: "Apple Watch показывает цифру. Что она значит — и что с ней делать.",
    },
    sections: {
      en: [
        {
          id: "the-number",
          h: "The number on your wrist",
          blocks: [
            {
              t: "p",
              v: "Open the Fitness app and you’ll see VO₂ max — a single number, usually somewhere between 30 and 60 for most adults. It looks precise. It feels official. And it’s easy to stare at it every Monday and wonder if you’re getting worse.",
            },
            {
              t: "p",
              v: "Here’s the simple version: VO₂ max is an estimate of how much oxygen your body can use during hard exercise. Higher generally means better cardiovascular fitness. Apple Watch calculates it from outdoor walks, runs and hikes — not from sitting at your desk.",
            },
          ],
        },
        {
          id: "estimate-not-test",
          h: "It’s an estimate — not a lab test",
          blocks: [
            {
              t: "p",
              v: "A real VO₂ max test involves a mask, a treadmill, and someone in a lab coat. Your watch does something clever but different: it watches your pace and heart rate during workouts and fits a model. Useful — absolutely. Identical to clinical testing — no.",
            },
            {
              t: "p",
              v: "That’s fine. You don’t need lab precision to know whether your cardio fitness is moving in the right direction. You need a consistent signal over weeks, not a perfect number on one Tuesday.",
            },
          ],
        },
        {
          id: "what-changes-it",
          h: "What actually moves the needle",
          blocks: [
            {
              t: "p",
              v: "VO₂ max tends to drift up when you do regular aerobic work — brisk walking, easy runs, cycling, anything that keeps your heart rate elevated for 20–40 minutes, several times a week. It drifts down when you stop, get sick, or pile on stress without recovery.",
            },
            {
              t: "p",
              v: "Age matters too. A number that would be average at 45 can look excellent at 65. Apple Health shows age and sex bands for a reason — compare yourself to your demographic, not to a 25-year-old runner on Instagram.",
            },
          ],
        },
        {
          id: "dont-chase",
          h: "What not to do",
          blocks: [
            {
              t: "p",
              v: "Don’t sprint every workout trying to bump the score. Don’t ignore recovery because the number dipped after a hard week. A drop after illness, travel, or a block of intense training is normal — it’s your body, not a broken watch.",
            },
            {
              t: "p",
              v: "And don’t treat VO₂ max as a health diagnosis. It’s one lens on fitness. Sleep, resting heart rate, HRV, and how you actually feel matter just as much for deciding what today should look like.",
            },
          ],
        },
        {
          id: "weekfit-context",
          h: "How it fits your day",
          blocks: [
            {
              t: "p",
              v: "WeekFit reads VO₂ max from Apple Health alongside sleep, recovery and activity. It doesn’t worship the number — it puts it in context. Strong VO₂ max with poor sleep still means take it easy. Moderate VO₂ max after a great night might mean go for that run.",
            },
            {
              t: "p",
              v: "The point isn’t another metric to optimise. It’s knowing how your cardio base fits with everything else — so you train when it helps, and back off when it doesn’t.",
            },
          ],
        },
      ],
      ru: [
        {
          id: "the-number",
          h: "Цифра на запястье",
          blocks: [
            {
              t: "p",
              v: "Откройте «Фитнес» — там VO₂ max: одно число, обычно где-то между 30 и 60. Выглядит точно. Хочется каждый понедельник проверять, не стало ли хуже.",
            },
            {
              t: "p",
              v: "Простыми словами: VO₂ max — оценка того, сколько кислорода тело может использовать при нагрузке. Чем выше, тем лучше выносливость. Apple Watch считает это по прогулкам, бегу и походам на улице — не за рабочим столом.",
            },
          ],
        },
        {
          id: "estimate-not-test",
          h: "Это оценка, не лаборатория",
          blocks: [
            {
              t: "p",
              v: "Настоящий тест — маска, беговая дорожка, лаборатория. Часы делают другое, но полезное: смотрят на темп и пульс во время тренировок и подгоняют модель. Точно для тренда — да. Как в клинике — нет.",
            },
            {
              t: "p",
              v: "И это нормально. Для понимания, куда движется форма, нужны недели стабильных данных — не идеальная цифра во вторник.",
            },
          ],
        },
        {
          id: "what-changes-it",
          h: "Что реально влияет",
          blocks: [
            {
              t: "p",
              v: "VO₂ max растёт, когда вы регулярно делаете аэробику — быстрая ходьба, лёгкий бег, велик, 20–40 минут несколько раз в неделю. Падает, когда останавливаетесь, болеете или копите усталость без восстановления.",
            },
            {
              t: "p",
              v: "Возраст тоже важен. Средний показатель в 45 и в 65 — разные истории. Apple Health показывает возрастные группы не просто так — сравнивайте себя с собой и своей группой, а не с блогером-марафонцем.",
            },
          ],
        },
        {
          id: "dont-chase",
          h: "Чего не стоит делать",
          blocks: [
            {
              t: "p",
              v: "Не нужно каждую тренировку рвать ради цифры. Не игнорируйте восстановление, если показатель просел после тяжёлой недели. Спад после болезни, поездки или блока нагрузки — нормален. Это тело, не сломанные часы.",
            },
            {
              t: "p",
              v: "И не воспринимайте VO₂ max как диагноз. Это один ракурс. Сон, пульс покоя, ВСР и самочувствие не менее важны, когда решаете, как выглядит сегодняшний день.",
            },
          ],
        },
        {
          id: "weekfit-context",
          h: "Как это ложится на ваш день",
          blocks: [
            {
              t: "p",
              v: "WeekFit читает VO₂ max из Apple Health вместе со сном, восстановлением и активностью. Не поклоняется цифре — ставит её в контекст. Высокий VO₂ max при плохом сне — повод не форсировать. Средний VO₂ max после хорошей ночи — можно идти на пробежку.",
            },
            {
              t: "p",
              v: "Смысл не в ещё одной метрике для оптимизации. А в том, чтобы понимать, как выносливость сочетается со всем остальным — и тренироваться, когда это помогает, а не когда «надо поднять число».",
            },
          ],
        },
      ],
    },
  },
];

export const blogCopy: Record<
  Lang,
  { kicker: string; title: string; lead: string; empty: string; categoriesTitle: string; latestTitle: string; readMin: string }
> = {
  en: {
    kicker: "Blog",
    title: "Guides & insights",
    lead: "Practical writing on recovery, sleep, nutrition and training — and how a daily AI coach helps you act on them. New articles are on the way.",
    empty: "Latest guides and deep dives on recovery, sleep and training.",
    categoriesTitle: "Topics",
    latestTitle: "Latest",
    readMin: "min read",
  },
  ru: {
    kicker: "Блог",
    title: "Гайды и заметки",
    lead: "Практичные тексты о восстановлении, сне, питании и тренировках — и о том, как ежедневный AI-коуч помогает применять это на деле.",
    empty: "Свежие гайды и разборы восстановления, сна и тренировок.",
    categoriesTitle: "Темы",
    latestTitle: "Новое",
    readMin: "мин",
  },
};
