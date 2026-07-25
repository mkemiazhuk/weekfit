import type { DocSection } from "@/lib/content";

export const bevelVsWeekFitArticleSections: { en: DocSection[]; ru: DocSection[] } = {
  en: [
    {
      id: "intro",
      h: "",
      blocks: [
        {
          t: "p",
          v: "If you're looking for an app that helps you understand your health, you've probably come across **Bevel** and **WeekFit**.",
        },
        {
          t: "p",
          v: "At first glance, they seem similar. Both connect with Apple Health, analyze recovery, and help you make better training decisions.",
        },
        {
          t: "p",
          v: "But after using both, it becomes clear that they're built around two very different philosophies.",
        },
      ],
    },
    {
      id: "bevel",
      h: "Bevel: Built for Understanding Your Body",
      blocks: [
        {
          t: "p",
          v: "Bevel is one of the most polished recovery apps available for Apple users.",
        },
        {
          t: "p",
          v: "It focuses on metrics such as:",
        },
        {
          t: "ul",
          v: ["Recovery", "Heart Rate Variability (HRV)", "Resting Heart Rate", "Sleep", "Training Strain"],
        },
        {
          t: "p",
          v: "The experience is data-rich. You get detailed charts, trends, and scores that help explain how your body is recovering over time.",
        },
        {
          t: "p",
          v: "If you enjoy understanding your physiology and making your own decisions based on health data, Bevel does an excellent job.",
        },
        { t: "h3", v: "Pros" },
        {
          t: "ul",
          v: [
            "Beautiful design",
            "Excellent recovery metrics",
            "Strong Apple Health integration",
            "Great trend analysis",
          ],
        },
        { t: "h3", v: "Cons" },
        {
          t: "ul",
          v: [
            "Requires interpreting the data yourself",
            "Limited nutrition tracking",
            "No personalized daily action plan",
          ],
        },
      ],
    },
    {
      id: "weekfit",
      h: "WeekFit: Built for Deciding What to Do Next",
      blocks: [
        {
          t: "p",
          v: "WeekFit takes a different approach.",
        },
        {
          t: "p",
          v: "Instead of showing as many health metrics as possible, it tries to answer one question:",
        },
        { t: "quote", v: "**What should I do today?**" },
        {
          t: "p",
          v: "Your recovery score is only one part of the picture.",
        },
        {
          t: "p",
          v: "WeekFit combines information from:",
        },
        {
          t: "ul",
          v: [
            "Recovery",
            "Sleep",
            "HRV",
            "Resting heart rate",
            "Activity",
            "Calories",
            "Hydration",
            "Nutrition",
          ],
        },
        {
          t: "p",
          v: "Instead of leaving you with dozens of charts, it turns that information into practical guidance.",
        },
        {
          t: "p",
          v: "For example:",
        },
        {
          t: "ul",
          v: [
            "Should today be a hard workout or an easy one?",
            "Are you under-fueled?",
            "Do you need more hydration?",
            "Is your recovery limited by sleep or yesterday's training?",
            "Will pushing harder today likely hurt tomorrow's performance?",
          ],
        },
        {
          t: "p",
          v: "The goal isn't to replace your judgment.",
        },
        {
          t: "p",
          v: "It's to reduce the mental effort required to make healthy decisions.",
        },
      ],
    },
    {
      id: "philosophy",
      h: "Philosophy Matters More Than Features",
      blocks: [
        { t: "p", v: "Many health apps collect data." },
        { t: "p", v: "Some analyze it." },
        { t: "p", v: "Few actually help you decide what to do next." },
        {
          t: "p",
          v: "That's the biggest philosophical difference between these two apps.",
        },
        { t: "p", v: "**Bevel** helps you understand your body." },
        { t: "p", v: "**WeekFit** helps you act on that understanding." },
        {
          t: "p",
          v: "Neither approach is objectively better—they're simply designed for different types of users.",
        },
      ],
    },
    {
      id: "which-one",
      h: "Which One Should You Choose?",
      blocks: [
        { t: "p", v: "Choose **Bevel** if you:" },
        {
          t: "ul",
          v: [
            "Love detailed health metrics",
            "Enjoy analyzing trends",
            "Already know how to interpret recovery data",
            "Prefer making your own training decisions",
          ],
        },
        { t: "p", v: "Choose **WeekFit** if you:" },
        {
          t: "ul",
          v: [
            "Want clear daily guidance",
            "Track nutrition alongside recovery",
            "Prefer recommendations over dashboards",
            "Want one place for recovery, activity, hydration, and calories",
          ],
        },
      ],
    },
    {
      id: "final-thoughts",
      h: "Final Thoughts",
      blocks: [
        { t: "p", v: "Recovery isn't just about one number." },
        {
          t: "p",
          v: "A great night's sleep doesn't always mean you're ready for a hard workout. Stress, yesterday's training, hydration, nutrition, and overall workload all influence how your body performs.",
        },
        {
          t: "p",
          v: "That's why choosing the right app isn't about finding the one with the most graphs.",
        },
        {
          t: "p",
          v: "It's about finding the one that helps you make better decisions.",
        },
        { t: "p", v: "For some people, that's Bevel." },
        { t: "p", v: "For others, it's WeekFit." },
        {
          t: "p",
          v: "The best health app is the one you'll actually use every day—and the one that helps you build healthier habits over time.",
        },
      ],
    },
  ],
  ru: [
    {
      id: "intro",
      h: "",
      blocks: [
        {
          t: "p",
          v: "Если вы ищете приложение, которое поможет лучше понимать своё здоровье, то наверняка уже встречали **Bevel** и **WeekFit**.",
        },
        {
          t: "p",
          v: "На первый взгляд они похожи. Оба подключаются к Apple Health, анализируют восстановление и помогают принимать более взвешенные решения о тренировках.",
        },
        {
          t: "p",
          v: "Но после использования обоих становится понятно: в их основе лежат две совершенно разные философии.",
        },
      ],
    },
    {
      id: "bevel",
      h: "Bevel: чтобы понимать своё тело",
      blocks: [
        {
          t: "p",
          v: "Bevel — одно из самых продуманных приложений для анализа восстановления среди доступных пользователям Apple.",
        },
        { t: "p", v: "Оно сосредоточено на таких показателях, как:" },
        {
          t: "ul",
          v: [
            "Восстановление",
            "Вариабельность сердечного ритма (ВСР)",
            "Пульс покоя",
            "Сон",
            "Тренировочная нагрузка",
          ],
        },
        {
          t: "p",
          v: "Bevel даёт много данных: подробные графики, тренды и оценки помогают понять, как организм восстанавливается со временем.",
        },
        {
          t: "p",
          v: "Если вам нравится разбираться в своей физиологии и самостоятельно принимать решения на основе данных о здоровье, Bevel отлично с этим справляется.",
        },
        { t: "h3", v: "Плюсы" },
        {
          t: "ul",
          v: [
            "Красивый дизайн",
            "Отличные показатели восстановления",
            "Глубокая интеграция с Apple Health",
            "Качественный анализ трендов",
          ],
        },
        { t: "h3", v: "Минусы" },
        {
          t: "ul",
          v: [
            "Данные нужно интерпретировать самостоятельно",
            "Ограниченный учёт питания",
            "Нет персонального плана действий на день",
          ],
        },
      ],
    },
    {
      id: "weekfit",
      h: "WeekFit: чтобы решить, что делать дальше",
      blocks: [
        { t: "p", v: "WeekFit использует другой подход." },
        {
          t: "p",
          v: "Вместо того чтобы показывать как можно больше показателей, он пытается ответить на один вопрос:",
        },
        { t: "quote", v: "**Что мне делать сегодня?**" },
        {
          t: "p",
          v: "Показатель восстановления — лишь одна часть общей картины.",
        },
        { t: "p", v: "WeekFit объединяет данные о:" },
        {
          t: "ul",
          v: [
            "Восстановлении",
            "Сне",
            "ВСР",
            "Пульсе покоя",
            "Активности",
            "Калориях",
            "Гидратации",
            "Питании",
          ],
        },
        {
          t: "p",
          v: "Вместо десятков графиков приложение превращает эту информацию в практические рекомендации.",
        },
        { t: "p", v: "Например:" },
        {
          t: "ul",
          v: [
            "Сегодня лучше провести тяжёлую или лёгкую тренировку?",
            "Достаточно ли вы едите?",
            "Нужно ли пить больше воды?",
            "Что ограничивает восстановление: сон или вчерашняя тренировка?",
            "Не ухудшит ли дополнительная нагрузка сегодняшнего дня результат завтра?",
          ],
        },
        { t: "p", v: "Цель не в том, чтобы заменить ваше собственное мнение." },
        {
          t: "p",
          v: "Цель — сократить умственные усилия, которые требуются для принятия полезных для здоровья решений.",
        },
      ],
    },
    {
      id: "philosophy",
      h: "Философия важнее набора функций",
      blocks: [
        { t: "p", v: "Многие приложения собирают данные о здоровье." },
        { t: "p", v: "Некоторые их анализируют." },
        { t: "p", v: "И лишь немногие помогают решить, что делать дальше." },
        {
          t: "p",
          v: "В этом и состоит главное философское различие между двумя приложениями.",
        },
        { t: "p", v: "**Bevel** помогает понять своё тело." },
        { t: "p", v: "**WeekFit** помогает действовать на основе этого понимания." },
        {
          t: "p",
          v: "Ни один подход не лучше другого сам по себе — просто они созданы для разных пользователей.",
        },
      ],
    },
    {
      id: "which-one",
      h: "Какое приложение выбрать?",
      blocks: [
        { t: "p", v: "Выбирайте **Bevel**, если вы:" },
        {
          t: "ul",
          v: [
            "Любите подробные показатели здоровья",
            "Получаете удовольствие от анализа трендов",
            "Уже умеете интерпретировать данные о восстановлении",
            "Предпочитаете самостоятельно решать, как тренироваться",
          ],
        },
        { t: "p", v: "Выбирайте **WeekFit**, если вы:" },
        {
          t: "ul",
          v: [
            "Хотите получать понятные рекомендации на каждый день",
            "Учитываете питание вместе с восстановлением",
            "Предпочитаете рекомендации панелям с графиками",
            "Хотите видеть восстановление, активность, воду и калории в одном месте",
          ],
        },
      ],
    },
    {
      id: "final-thoughts",
      h: "Итоги",
      blocks: [
        { t: "p", v: "Восстановление — это не одна цифра." },
        {
          t: "p",
          v: "Даже отличный ночной сон не всегда означает, что вы готовы к тяжёлой тренировке. Стресс, вчерашняя нагрузка, вода, питание и общий объём тренировок — всё это влияет на работу организма.",
        },
        {
          t: "p",
          v: "Поэтому при выборе приложения важнее не количество графиков.",
        },
        {
          t: "p",
          v: "Важнее найти то, которое помогает принимать более правильные решения.",
        },
        { t: "p", v: "Для кого-то это Bevel." },
        { t: "p", v: "Для кого-то — WeekFit." },
        {
          t: "p",
          v: "Лучшее приложение для здоровья — то, которым вы действительно пользуетесь каждый день и которое помогает со временем формировать более здоровые привычки.",
        },
      ],
    },
  ],
};
