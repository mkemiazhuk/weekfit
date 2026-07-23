import type { Lang } from "./dictionaries";
import type { IconName } from "@/components/Icon";
import { accents, pillars, pastels } from "./tokens";

// ---------- shared types ----------
export interface QA {
  q: string;
  a: string;
}
export interface Category {
  icon: IconName;
  color: string;
  title: string;
  faqs: QA[];
}
export type Block =
  | { t: "p"; v: string }
  | { t: "h3"; v: string }
  | { t: "ul"; v: string[] }
  | { t: "quote"; v: string }
  | { t: "vo2-drop"; before: string; after: string; labels: [string, string] }
  | { t: "trend"; values: number[]; caption: string }
  | {
      t: "compare";
      left: { vo2: string; title: string; lines: string[] };
      right: { vo2: string; title: string; lines: string[] };
      question?: string;
    }
  | { t: "divider" };
export interface DocSection {
  id: string;
  h: string;
  blocks: Block[];
}

const red = "#f56b6b";

// ============================================================
// SUPPORT / HELP CENTER
// ============================================================
export const support: Record<
  Lang,
  {
    kicker: string;
    title: string;
    lead: string;
    search: string;
    noResults: string;
    browse: string;
    contactTitle: string;
    contactBody: string;
    contactCta: string;
    categories: Category[];
  }
> = {
  en: {
    kicker: "Help Center",
    title: "How can we help?",
    lead: "Setup guides and answers for WeekFit. Search below, or browse by topic.",
    search: "Search help…",
    noResults: "No matches. Try different keywords, or email us.",
    browse: "Browse by topic",
    contactTitle: "Still need a hand?",
    contactBody: "Email us and we'll usually reply within 2–3 business days.",
    contactCta: "Email support",
    categories: [
      {
        icon: "start",
        color: pillars.activity,
        title: "Getting Started",
        faqs: [
          { q: "Do I need an account to use WeekFit?", a: "No. Tap Open WeekFit on the login screen and start right away — WeekFit 1.0 works fully on-device, no account required." },
          { q: "What are the main tabs?", a: "Today shows your daily read and rings, Coach explains what matters, Meals logs nutrition, and Plan holds your week." },
        ],
      },
      {
        icon: "health",
        color: accents.appleHealth,
        title: "Apple Health",
        faqs: [
          { q: "Why should I connect Apple Health?", a: "Sleep, heart rate, workouts, energy and nutrition are what let Coach personalize your day. Without Health access, personalization is limited." },
          { q: "Data looks missing — how do I fix it?", a: "Open Settings → Privacy & Security → Health → WeekFit and enable read access. Sleep and recovery may take a night to appear." },
        ],
      },
      {
        icon: "recovery",
        color: pillars.recovery,
        title: "Recovery",
        faqs: [
          { q: "How is my Recovery score calculated?", a: "WeekFit blends sleep duration and quality, resting heart rate and HRV into a single readiness read for the day." },
          { q: "Why did my Recovery drop?", a: "Short or broken sleep, an elevated resting heart rate, or low HRV can lower recovery. Coach will suggest how to adjust." },
        ],
      },
      {
        icon: "nutrition",
        color: pillars.nutrition,
        title: "Nutrition",
        faqs: [
          { q: "How do I log a meal?", a: "Open Meals and add foods or log a suggested meal. Calories and macros roll up into your Nutrition Balance." },
          { q: "What is Nutrition Balance?", a: "A quality read of your day's fuel — calories seen in context with protein, carbs and fat — not just a raw calorie count." },
        ],
      },
      {
        icon: "activity",
        color: pillars.activity,
        title: "Activities",
        faqs: [
          { q: "How do workouts get added?", a: "Completed workouts sync automatically from Apple Health. They may take a moment to show in Plan and your Activity score." },
          { q: "Can I plan a workout ahead?", a: "Yes — add planned activities in Plan and Coach will arrange fuel, timing and recovery around them." },
        ],
      },
      {
        icon: "coach",
        color: pillars.coach,
        title: "Coach",
        faqs: [
          { q: "What does the Coach actually do?", a: "Coach reads recovery, activity, nutrition and schedule together and surfaces the one thing that matters most today — with the reasoning behind it." },
          { q: "Why does the Coach change its advice?", a: "Because your day changes. A poor night, a hard session or a missed meal shifts what matters — Coach adapts in real time." },
        ],
      },
      {
        icon: "plan",
        color: pastels.workout,
        title: "Planning",
        faqs: [
          { q: "How does the weekly Plan work?", a: "Plan holds your activities and habits across the week so Coach can look ahead and prepare you for what's coming." },
          { q: "Can I edit or move items?", a: "Yes — tap any planned item to adjust it, reschedule it, or remove it." },
        ],
      },
      {
        icon: "trouble",
        color: red,
        title: "Troubleshooting",
        faqs: [
          { q: "The app isn't showing new data.", a: "Confirm Apple Health permissions are on, then reopen WeekFit. Health metrics can lag briefly after syncing." },
          { q: "How do I delete all my data?", a: "WeekFit 1.0 stores data on-device, so deleting the app removes all local plans, preferences and settings. Apple Health data stays in the Health app." },
        ],
      },
    ],
  },
  ru: {
    kicker: "Центр помощи",
    title: "Чем помочь?",
    lead: "Руководства и ответы по WeekFit. Ищите ниже или выбирайте тему.",
    search: "Поиск по справке…",
    noResults: "Ничего не найдено. Измените запрос или напишите нам.",
    browse: "По темам",
    contactTitle: "Остались вопросы?",
    contactBody: "Напишите нам — обычно отвечаем в течение 2–3 рабочих дней.",
    contactCta: "Написать в поддержку",
    categories: [
      {
        icon: "start",
        color: pillars.activity,
        title: "Быстрый старт",
        faqs: [
          { q: "Нужен ли аккаунт?", a: "Нет. Нажмите «Открыть WeekFit» на экране входа и начинайте — версия 1.0 работает полностью на устройстве, без аккаунта." },
          { q: "Какие есть вкладки?", a: "«Сегодня» — сводка дня и кольца, «Коуч» — что важно прямо сейчас, «Питание» — учёт еды, «План» — ваша неделя." },
        ],
      },
      {
        icon: "health",
        color: accents.appleHealth,
        title: "Apple Health",
        faqs: [
          { q: "Зачем подключать Apple Health?", a: "Сон, пульс, тренировки, энергия и питание позволяют Коучу персонализировать день. Без доступа персонализация ограничена." },
          { q: "Данных нет — что делать?", a: "Откройте «Настройки» → «Конфиденциальность и безопасность» → «Здоровье» → WeekFit и включите доступ на чтение. Сон и восстановление могут появиться только на следующее утро." },
        ],
      },
      {
        icon: "recovery",
        color: pillars.recovery,
        title: "Восстановление",
        faqs: [
          { q: "Как считается восстановление?", a: "WeekFit объединяет длительность и качество сна, пульс покоя и ВСР в единый показатель готовности." },
          { q: "Почему упало восстановление?", a: "Короткий или прерывистый сон, высокий пульс покоя или низкая ВСР снижают восстановление. Коуч подскажет, как скорректировать." },
        ],
      },
      {
        icon: "nutrition",
        color: pillars.nutrition,
        title: "Питание",
        faqs: [
          { q: "Как записать приём пищи?", a: "Откройте «Питание» и добавьте продукты или запишите предложенное блюдо. Калории и макросы попадут в Баланс питания." },
          { q: "Что такое Баланс питания?", a: "Оценка качества питания за день — калории в контексте белков, жиров и углеводов, а не просто счётчик калорий." },
        ],
      },
      {
        icon: "activity",
        color: pillars.activity,
        title: "Активности",
        faqs: [
          { q: "Как добавляются тренировки?", a: "Завершённые тренировки подтягиваются из Apple Health автоматически. Иногда они появляются с небольшой задержкой." },
          { q: "Можно ли запланировать тренировку заранее?", a: "Да — добавьте активность в «План», и Коуч заранее подстроит под неё питание, тайминг и восстановление." },
        ],
      },
      {
        icon: "coach",
        color: pillars.coach,
        title: "Коуч",
        faqs: [
          { q: "Что делает Коуч?", a: "Коуч читает восстановление, активность, питание и расписание вместе и показывает главное на сегодня — с объяснением почему." },
          { q: "Почему совет меняется?", a: "Потому что меняется ваш день. Плохая ночь, тяжёлая тренировка или пропуск еды меняют приоритеты — Коуч адаптируется." },
        ],
      },
      {
        icon: "plan",
        color: pastels.workout,
        title: "Планирование",
        faqs: [
          { q: "Как работает недельный план?", a: "«План» хранит активности и привычки на неделю, чтобы Коуч смотрел вперёд и готовил вас к предстоящему." },
          { q: "Можно ли менять пункты?", a: "Да — нажмите на пункт, чтобы изменить, перенести или удалить его." },
        ],
      },
      {
        icon: "trouble",
        color: red,
        title: "Устранение неполадок",
        faqs: [
          { q: "Приложение не показывает новые данные.", a: "Проверьте разрешения Apple Health и перезапустите WeekFit. Метрики могут появляться с задержкой после синхронизации." },
          { q: "Как удалить все данные?", a: "WeekFit 1.0 хранит данные на устройстве, поэтому удаление приложения стирает все локальные данные — план, настройки и предпочтения. Данные из Apple Health остаются в приложении «Здоровье»." },
        ],
      },
    ],
  },
};

// ============================================================
// PRIVACY (visual intro + full policy)
// ============================================================
export const privacy: Record<
  Lang,
  {
    kicker: string;
    title: string;
    lead: string;
    updated: string;
    flowTitle: string;
    flow: { from: string; on: string; never: string };
    tocTitle: string;
    sections: DocSection[];
  }
> = {
  en: {
    kicker: "Privacy",
    title: "Your health stays yours.",
    lead: "WeekFit is a local-first app. Here's exactly what it accesses, and what it never does.",
    updated: "Last updated: July 8, 2026",
    flowTitle: "How your data flows",
    flow: {
      from: "Apple Health — sleep, heart rate, workouts, energy, nutrition",
      on: "Interpreted on your device to personalize Coach, Today and Plan",
      never: "Never uploaded to a server · never sold · never used for ads",
    },
    tocTitle: "On this page",
    sections: [
      {
        id: "summary",
        h: "Summary",
        blocks: [
          { t: "p", v: "WeekFit (\u201cwe\u201d, \u201cthe app\u201d) is a local-first fitness planner for iOS. This policy explains what data the app accesses and how it is used." },
          { t: "ul", v: ["WeekFit 1.0 stores your plan and preferences on your device.", "We do not operate cloud sync or user accounts in version 1.0.", "We do not sell your data or use cross-app tracking."] },
        ],
      },
      {
        id: "access",
        h: "Data the app accesses",
        blocks: [
          { t: "h3", v: "Apple Health (optional but recommended)" },
          { t: "p", v: "With your permission, WeekFit reads health and activity data such as sleep, heart rate, workouts, steps, active energy, and nutrition metrics to personalize Coach, Today, and Plan. WeekFit may write workout-related records to Apple Health to keep your fitness history consistent." },
          { t: "p", v: "In line with Apple's HealthKit requirements, data obtained through HealthKit is used only to provide features inside WeekFit. It is never used for advertising or marketing, and is never sold or shared with third parties or data brokers." },
          { t: "h3", v: "Camera (optional)" },
          { t: "p", v: "Used only when you add photos to custom foods." },
          { t: "h3", v: "Location (optional)" },
          { t: "p", v: "Approximate location may be used to adjust the Night Comfort theme at local sunset. Location is not stored on a server." },
          { t: "h3", v: "On-device storage" },
          { t: "p", v: "The app stores planned activities, meal preferences, profile settings, and similar app data locally using iOS storage (including UserDefaults and SwiftData)." },
        ],
      },
      {
        id: "not-collect",
        h: "What we do not collect in 1.0",
        blocks: [
          { t: "ul", v: ["No advertising identifiers", "No third-party analytics SDKs", "No cloud upload of Health data", "No required sign-in or email collection"] },
        ],
      },
      {
        id: "retention",
        h: "Data retention and deletion",
        blocks: [
          { t: "p", v: "Because WeekFit 1.0 stores data only on your device, we do not keep a copy on any server. To erase all app data, delete WeekFit from your device — this removes locally stored plans, meal preferences, and profile settings. Data you granted from Apple Health stays in the Health app and remains under your control there; you can delete it in the Health app at any time." },
        ],
      },
      {
        id: "permissions",
        h: "Managing permissions",
        blocks: [
          { t: "p", v: "You can review or revoke Apple Health, Camera, and Location access at any time in the iOS Settings app. Revoking Apple Health access may limit personalization in Coach, Today, and Plan." },
        ],
      },
      {
        id: "future",
        h: "Future features",
        blocks: [
          { t: "p", v: "If future versions add account services, cloud sync, analytics, or support diagnostics, we will update this policy and disclose those practices before they ship." },
        ],
      },
      {
        id: "children",
        h: "Children",
        blocks: [{ t: "p", v: "WeekFit is not directed at children under 13." }],
      },
      {
        id: "medical",
        h: "Medical disclaimer",
        blocks: [{ t: "p", v: "WeekFit provides fitness and wellness guidance only. It is not a medical device and does not provide medical advice, diagnosis, or treatment." }],
      },
      {
        id: "contact",
        h: "Contact",
        blocks: [{ t: "p", v: "Questions: support@weekfit.app" }],
      },
    ],
  },
  ru: {
    kicker: "Приватность",
    title: "Ваше здоровье — ваше.",
    lead: "WeekFit — локальное приложение. Вот что именно оно использует и чего никогда не делает.",
    updated: "Обновлено: 8 июля 2026",
    flowTitle: "Как движутся ваши данные",
    flow: {
      from: "Apple Health — сон, пульс, тренировки, энергия, питание",
      on: "Обрабатываются на устройстве для персонализации Коуча, Сегодня и Плана",
      never: "Никогда не выгружаются на сервер · не продаются · не для рекламы",
    },
    tocTitle: "На этой странице",
    sections: [
      {
        id: "summary",
        h: "Кратко",
        blocks: [
          { t: "p", v: "WeekFit («мы», «приложение») — локальный фитнес-планировщик для iOS. Эта политика описывает, какие данные использует приложение." },
          { t: "ul", v: ["WeekFit 1.0 хранит план и настройки на вашем устройстве.", "В версии 1.0 нет облачной синхронизации и аккаунтов.", "Мы не продаём данные и не используем кросс-приложенческое отслеживание."] },
        ],
      },
      {
        id: "access",
        h: "Какие данные использует приложение",
        blocks: [
          { t: "h3", v: "Apple Health (по желанию, рекомендуется)" },
          { t: "p", v: "С вашего разрешения WeekFit читает сон, пульс, тренировки, шаги, активную энергию и питание для персонализации Коуча, Сегодня и Плана. Приложение может записывать тренировки в Apple Health для согласованности истории." },
          { t: "p", v: "В соответствии с требованиями Apple HealthKit данные из HealthKit используются только для работы функций WeekFit. Они никогда не применяются для рекламы или маркетинга, не продаются и не передаются третьим лицам или брокерам данных." },
          { t: "h3", v: "Камера (по желанию)" },
          { t: "p", v: "Только для фото пользовательских продуктов." },
          { t: "h3", v: "Геолокация (по желанию)" },
          { t: "p", v: "Примерное местоположение может использоваться для темы Night Comfort по местному закату. На сервер не передаётся." },
          { t: "h3", v: "Локальное хранение" },
          { t: "p", v: "План, предпочтения питания, профиль и другие данные хранятся на устройстве (UserDefaults, SwiftData)." },
        ],
      },
      {
        id: "not-collect",
        h: "Чего нет в 1.0",
        blocks: [
          { t: "ul", v: ["Рекламные идентификаторы", "Сторонняя аналитика", "Облачная выгрузка Health-данных", "Обязательный вход или сбор email"] },
        ],
      },
      {
        id: "retention",
        h: "Хранение и удаление данных",
        blocks: [
          { t: "p", v: "Поскольку WeekFit 1.0 хранит данные только на вашем устройстве, мы не держим их копию на сервере. Чтобы стереть все данные, удалите WeekFit с устройства. Данные из Apple Health остаются в приложении «Здоровье» под вашим контролем." },
        ],
      },
      {
        id: "permissions",
        h: "Управление разрешениями",
        blocks: [
          { t: "p", v: "Вы можете просмотреть или отозвать доступ к Apple Health, Камере и Геолокации в любой момент в приложении «Настройки» iOS. Отзыв доступа к Apple Health может ограничить персонализацию." },
        ],
      },
      {
        id: "future",
        h: "Будущие функции",
        blocks: [{ t: "p", v: "При появлении аккаунта, облака или аналитики мы обновим политику до релиза этих функций." }],
      },
      {
        id: "children",
        h: "Дети",
        blocks: [{ t: "p", v: "Приложение не предназначено для детей младше 13 лет." }],
      },
      {
        id: "medical",
        h: "Медицинский дисклеймер",
        blocks: [{ t: "p", v: "WeekFit даёт рекомендации по фитнесу и здоровому образу жизни, но не является медицинским устройством и не заменяет консультацию врача." }],
      },
      {
        id: "contact",
        h: "Контакты",
        blocks: [{ t: "p", v: "Вопросы: support@weekfit.app" }],
      },
    ],
  },
};

// ============================================================
// TERMS OF USE
// ============================================================
export const terms: Record<
  Lang,
  { kicker: string; title: string; lead: string; updated: string; tocTitle: string; sections: DocSection[] }
> = {
  en: {
    kicker: "Terms",
    title: "Terms of Use",
    lead: "The agreement between you and WeekFit when you use the app.",
    updated: "Last updated: July 8, 2026",
    tocTitle: "On this page",
    sections: [
      { id: "acceptance", h: "1. Acceptance", blocks: [{ t: "p", v: "By downloading or using WeekFit, you agree to these Terms of Use. If you do not agree, please do not use the app." }] },
      { id: "license", h: "2. License", blocks: [{ t: "p", v: "We grant you a personal, non-exclusive, non-transferable, revocable license to use WeekFit for your own non-commercial purposes, subject to these terms and the App Store terms." }] },
      { id: "health", h: "3. Health disclaimer", blocks: [{ t: "p", v: "WeekFit provides fitness and wellness guidance only. It is not a medical device and does not provide medical advice, diagnosis, or treatment. Always consult a qualified professional before starting or changing any exercise, nutrition, or recovery program, and never disregard professional advice because of something in the app." }] },
      { id: "use", h: "4. Acceptable use", blocks: [{ t: "p", v: "You agree not to misuse the app, including attempting to reverse engineer, disrupt, or use it in a way that violates applicable law or the rights of others." }] },
      { id: "health-data", h: "5. Apple Health data", blocks: [{ t: "p", v: "If you grant access, WeekFit reads Apple Health data solely to provide features inside the app. It is processed on your device and handled as described in our Privacy Policy." }] },
      { id: "ip", h: "6. Intellectual property", blocks: [{ t: "p", v: "WeekFit, its design, content, and trademarks are owned by us or our licensors and are protected by law. These terms do not grant you rights to our branding except as needed to use the app." }] },
      { id: "liability", h: "7. Disclaimers & liability", blocks: [{ t: "p", v: "The app is provided \u201cas is\u201d without warranties of any kind. To the maximum extent permitted by law, we are not liable for any indirect, incidental, or consequential damages arising from your use of the app." }] },
      { id: "changes", h: "8. Changes", blocks: [{ t: "p", v: "We may update these terms as the app evolves. Material changes will be reflected on this page with an updated date." }] },
      { id: "contact", h: "9. Contact", blocks: [{ t: "p", v: "Questions about these terms: support@weekfit.app" }] },
    ],
  },
  ru: {
    kicker: "Условия",
    title: "Условия использования",
    lead: "Соглашение между вами и WeekFit при использовании приложения.",
    updated: "Обновлено: 8 июля 2026",
    tocTitle: "На этой странице",
    sections: [
      { id: "acceptance", h: "1. Принятие", blocks: [{ t: "p", v: "Загружая или используя WeekFit, вы соглашаетесь с этими условиями. Если вы не согласны — не используйте приложение." }] },
      { id: "license", h: "2. Лицензия", blocks: [{ t: "p", v: "Мы предоставляем вам личную, неисключительную, непередаваемую и отзывную лицензию на использование WeekFit в некоммерческих целях, согласно этим условиям и правилам App Store." }] },
      { id: "health", h: "3. Медицинский дисклеймер", blocks: [{ t: "p", v: "WeekFit даёт рекомендации по фитнесу и здоровому образу жизни. Это не медицинское устройство, и оно не заменяет консультацию врача. Перед началом или изменением программы тренировок, питания или восстановления проконсультируйтесь со специалистом." }] },
      { id: "use", h: "4. Допустимое использование", blocks: [{ t: "p", v: "Вы обязуетесь не злоупотреблять приложением, не пытаться декомпилировать его, нарушать его работу или использовать с нарушением закона и прав других лиц." }] },
      { id: "health-data", h: "5. Данные Apple Health", blocks: [{ t: "p", v: "При наличии разрешения WeekFit читает данные Apple Health только для работы функций приложения. Они обрабатываются на устройстве согласно нашей Политике конфиденциальности." }] },
      { id: "ip", h: "6. Интеллектуальная собственность", blocks: [{ t: "p", v: "WeekFit, его дизайн, контент и товарные знаки принадлежат нам или нашим лицензиарам и защищены законом." }] },
      { id: "liability", h: "7. Отказ от ответственности", blocks: [{ t: "p", v: "Приложение предоставляется «как есть» без каких-либо гарантий. В максимально допустимой законом степени мы не несём ответственности за косвенный или случайный ущерб от использования приложения." }] },
      { id: "changes", h: "8. Изменения", blocks: [{ t: "p", v: "Мы можем обновлять эти условия по мере развития приложения. Существенные изменения будут отражены на этой странице." }] },
      { id: "contact", h: "9. Контакты", blocks: [{ t: "p", v: "Вопросы: support@weekfit.app" }] },
    ],
  },
};

// ============================================================
// CHANGELOG
// ============================================================
export interface Release {
  version: string;
  date: string;
  tag: string;
  added?: string[];
  improved?: string[];
  fixed?: string[];
}
export const changelog: Record<
  Lang,
  { kicker: string; title: string; lead: string; labels: { added: string; improved: string; fixed: string }; roadmap: string; releases: Release[] }
> = {
  en: {
    kicker: "Changelog",
    title: "What's new",
    lead: "The story of WeekFit, one release at a time.",
    labels: { added: "Added", improved: "Improved", fixed: "Fixed" },
    roadmap: "More on the way — cloud sync, deeper insights, and Apple Watch are on the roadmap.",
    releases: [
      {
        version: "1.1",
        date: "23 Jul 2026, 23:45",
        tag: "Update",
        improved: [
          "Completely redesigned onboarding experience",
          "Better AI coaching from your very first day",
          "Improved recovery insights and daily guidance",
          "Faster performance and stability improvements",
          "Multiple UX improvements throughout the app",
        ],
      },
      {
        version: "1.0",
        date: "2026",
        tag: "Initial release",
        added: [
          "Today, Coach, Meals and Plan — the four pillars of your day",
          "AI Coach that reads recovery, activity, nutrition and schedule",
          "Apple Health integration with on-device personalization",
          "Recovery, Activity and Nutrition Balance rings",
          "Night Comfort — the interface calms with the local sunset",
        ],
      },
    ],
  },
  ru: {
    kicker: "Изменения",
    title: "Что нового",
    lead: "История WeekFit — от релиза к релизу.",
    labels: { added: "Добавлено", improved: "Улучшено", fixed: "Исправлено" },
    roadmap: "Дальше — больше: облачная синхронизация, детальная аналитика и Apple Watch уже в планах.",
    releases: [
      {
        version: "1.1",
        date: "23 июля 2026, 23:45",
        tag: "Обновление",
        improved: [
          "Полностью обновлённый онбординг",
          "Лучший AI-коучинг с самого первого дня",
          "Улучшенные инсайты по восстановлению и ежедневные подсказки",
          "Быстрее работа и улучшения стабильности",
          "Множество UX-улучшений по всему приложению",
        ],
      },
      {
        version: "1.0",
        date: "2026",
        tag: "Первый релиз",
        added: [
          "Сегодня, Коуч, Питание и План — четыре опоры вашего дня",
          "AI-коуч, читающий восстановление, активность, питание и расписание",
          "Интеграция с Apple Health и персонализация на устройстве",
          "Кольца восстановления, активности и баланса питания",
          "Night Comfort — интерфейс успокаивается к местному закату",
        ],
      },
    ],
  },
};

// ============================================================
// PRESS KIT
// ============================================================
export const press: Record<
  Lang,
  {
    kicker: string;
    title: string;
    lead: string;
    factsTitle: string;
    facts: { label: string; value: string }[];
    boilerTitle: string;
    boilerShort: string;
    boilerLong: string;
    colorsTitle: string;
    assetsTitle: string;
    assetsNote: string;
    preferredTitle: string;
    preferredBody: string;
    preferredNote: string;
    preferredCta: string;
    preferredLinkLabel: string;
    contactTitle: string;
    contactBody: string;
  }
> = {
  en: {
    kicker: "Press Kit",
    title: "WeekFit for press",
    lead: "Brand assets, boilerplate and facts for stories about WeekFit.",
    factsTitle: "Quick facts",
    facts: [
      { label: "Name", value: "WeekFit" },
      { label: "Category", value: "Health & Fitness" },
      { label: "Platform", value: "iOS (iPhone)" },
      { label: "Price", value: "Free" },
      { label: "Launch", value: "2026" },
      { label: "Website", value: "weekfit.app" },
    ],
    boilerTitle: "Boilerplate",
    boilerShort:
      "WeekFit is your AI coach, powered by Apple Health. One clear call for today — what to do now, why it matters, and how to adjust. Private on your iPhone.",
    boilerLong: "WeekFit is your AI coach for iOS, powered by Apple Health. Instead of another dashboard of numbers, it turns sleep, activity, nutrition and recovery into one clear call for today — what to do now, why it matters, and how to adjust. Private by design, WeekFit requires no account and never uses your health data for advertising.",
    colorsTitle: "Brand colors",
    assetsTitle: "Downloadable assets",
    assetsNote: "App icon and product screenshots. For anything else, get in touch.",
    preferredTitle: "Preferred source in Google Search",
    preferredBody:
      "Google lets readers highlight trusted publishers in Top Stories, AI Overviews and AI Mode. weekfit.app is domain-eligible, but Google curates which sites appear in its source catalog — usually publishers with fresh, regular content.",
    preferredNote:
      "weekfit.app is not in the catalog yet. If the search below shows “No results”, Google hasn’t added us — the deeplink will work once it does. We’re publishing guides on recovery, sleep and training to build toward eligibility.",
    preferredCta: "Check in Google Search",
    preferredLinkLabel: "Deeplink for when we’re listed",
    contactTitle: "Media contact",
    contactBody: "For interviews, review access or additional assets, email us.",
  },
  ru: {
    kicker: "Пресс-кит",
    title: "WeekFit для прессы",
    lead: "Материалы бренда, описание и факты для публикаций о WeekFit.",
    factsTitle: "Кратко о продукте",
    facts: [
      { label: "Название", value: "WeekFit" },
      { label: "Категория", value: "Здоровье и фитнес" },
      { label: "Платформа", value: "iOS (iPhone)" },
      { label: "Цена", value: "Бесплатно" },
      { label: "Запуск", value: "2026" },
      { label: "Сайт", value: "weekfit.app" },
    ],
    boilerTitle: "Описание",
    boilerShort:
      "WeekFit — ваш AI-коуч на основе Apple Health. Один понятный вывод на сегодня — что делать сейчас, почему это важно и как подстроиться. Приватно на iPhone.",
    boilerLong: "WeekFit — спокойный AI-коуч для iOS. Вместо очередной панели с цифрами он видит связи между сном, активностью, питанием и восстановлением — на основе Apple Health и с обработкой прямо на устройстве — и объясняет, что важно сегодня и как к этому подготовиться. Приватность заложена в основу: без аккаунта, и данные о здоровье никогда не используются для рекламы.",
    colorsTitle: "Цвета бренда",
    assetsTitle: "Материалы для загрузки",
    assetsNote: "Иконка приложения и скриншоты. За остальным — напишите нам.",
    preferredTitle: "Предпочитаемый источник в Google",
    preferredBody:
      "Google позволяет читателям выделять проверенные издания в Top Stories, AI Overviews и AI Mode. weekfit.app подходит по формату домена, но Google сам формирует каталог — обычно это сайты со свежим регулярным контентом.",
    preferredNote:
      "weekfit.app пока нет в каталоге. Если поиск показывает «No results», Google ещё не добавил нас — deeplink заработает, когда это произойдёт. Мы публикуем гайды о восстановлении, сне и тренировках, чтобы приблизиться к eligibility.",
    preferredCta: "Проверить в Google",
    preferredLinkLabel: "Deeplink на будущее",
    contactTitle: "Контакт для прессы",
    contactBody: "Для интервью, доступа к обзору или дополнительных материалов напишите нам.",
  },
};

// ============================================================
// CONTACT
// ============================================================
export const contact: Record<
  Lang,
  { kicker: string; title: string; lead: string; cardTitle: string; response: string; includeTitle: string; include: string[]; cta: string }
> = {
  en: {
    kicker: "Contact",
    title: "We're a message away.",
    lead: "Questions, feedback or an issue? We read every email.",
    cardTitle: "Email support",
    response: "We usually reply within 2–3 business days.",
    includeTitle: "To help us help you, include:",
    include: ["Your iOS version and iPhone model", "What you expected vs. what happened", "A screenshot, if it helps"],
    cta: "support@weekfit.app",
  },
  ru: {
    kicker: "Контакты",
    title: "Мы всегда на связи.",
    lead: "Вопросы, отзывы или проблема? Мы читаем каждое письмо.",
    cardTitle: "Написать в поддержку",
    response: "Обычно отвечаем в течение 2–3 рабочих дней.",
    includeTitle: "Чтобы помочь быстрее, укажите:",
    include: ["Версию iOS и модель iPhone", "Что вы ожидали и что произошло на самом деле", "Скриншот, если он поможет"],
    cta: "support@weekfit.app",
  },
};

// ============================================================
// DOWNLOAD
// ============================================================
export const download: Record<
  Lang,
  { kicker: string; title: string; lead: string; reqTitle: string; requirements: { label: string; value: string }[]; qr: string }
> = {
  en: {
    kicker: "Download",
    title: "Bring calm to your day.",
    lead: "WeekFit is free on the App Store. Built around Apple Health, private by design.",
    reqTitle: "Requirements",
    requirements: [
      { label: "Platform", value: "iPhone" },
      { label: "iOS", value: "iOS 17 or later" },
      { label: "Apple Health", value: "Recommended" },
      { label: "Price", value: "Free" },
    ],
    qr: "Scan to open on your iPhone",
  },
  ru: {
    kicker: "Установить",
    title: "Добавьте спокойствие в свой день.",
    lead: "WeekFit бесплатно в App Store. Работает на данных Apple Health, приватность — в основе.",
    reqTitle: "Требования",
    requirements: [
      { label: "Платформа", value: "iPhone" },
      { label: "iOS", value: "iOS 17 или новее" },
      { label: "Apple Health", value: "Рекомендуется" },
      { label: "Цена", value: "Бесплатно" },
    ],
    qr: "Наведите камеру, чтобы открыть на iPhone",
  },
};

// ============================================================
// 404
// ============================================================
export const notFound: Record<Lang, { title: string; lead: string; cta: string }> = {
  en: {
    title: "This page wandered off.",
    lead: "The link may be old or the page may have moved. Let's get you back on track.",
    cta: "Back home",
  },
  ru: {
    title: "Эта страница потерялась.",
    lead: "Возможно, ссылка устарела или страница переехала. Вернёмся на главную.",
    cta: "На главную",
  },
};

// Brand colors surfaced on the press page.
export const brandColors = [
  { name: "Activity", hex: pillars.activity },
  { name: "Nutrition", hex: pillars.nutrition },
  { name: "Recovery", hex: pillars.recovery },
  { name: "Hydration", hex: pillars.hydration },
  { name: "Coach", hex: pillars.coach },
  { name: "Canvas", hex: "#06070a" },
];
