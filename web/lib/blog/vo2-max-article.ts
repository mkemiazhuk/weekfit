import type { DocSection } from "@/lib/content";

export const vo2MaxArticleSections: { en: DocSection[]; ru: DocSection[] } = {
  en: [
    {
      id: "intro",
      h: "",
      blocks: [
        {
          t: "p",
          v: "Yesterday your Apple Watch showed **46**. Today it says **44**. Two points gone overnight.",
        },
        { t: "vo2-drop", before: "46", after: "44", labels: ["Yesterday", "Today"] },
        {
          t: "p",
          v: "If you've ever checked Apple Health after a workout, you've probably had the same thought:",
        },
        { t: "quote", v: "Am I getting less fit?" },
        {
          t: "p",
          v: "Probably not. And that's exactly why VO₂ max is one of the most useful — and most misunderstood — numbers your watch can show.",
        },
      ],
    },
    {
      id: "what-it-measures",
      h: "What it actually measures",
      blocks: [
        {
          t: "p",
          v: "Think of your body as an engine. Two engines can produce the same speed, but one burns far less fuel to get there.",
        },
        {
          t: "p",
          v: "During exercise, your muscles rely on oxygen to produce energy. The better your body is at delivering and using that oxygen, the longer and more efficiently you can keep moving.",
        },
        {
          t: "p",
          v: "That's what VO₂ max represents. It's not a measure of strength. It's not a measure of speed. It's a measure of how efficiently your body powers endurance.",
        },
      ],
    },
    {
      id: "estimate",
      h: "Your watch estimates it",
      blocks: [
        { t: "p", v: "Here's the catch. Your Apple Watch doesn't actually **measure** VO₂ max. It **estimates** it." },
        {
          t: "p",
          v: "A true VO₂ max test happens in a lab. You run on a treadmill wearing a breathing mask while specialists analyze every breath you take. Your watch can't do that.",
        },
        {
          t: "p",
          v: "Instead, it looks at your heart rate, walking or running pace, elevation changes, age, weight, and years of research to estimate how your cardiovascular system is performing.",
        },
        {
          t: "p",
          v: "Is it perfect? No. Is it useful? Absolutely — especially if you care about **trends** instead of individual numbers.",
        },
      ],
    },
    {
      id: "daily-noise",
      h: "Why today's number misleads you",
      blocks: [
        {
          t: "p",
          v: "That's where most people make a mistake. They obsess over today's score — 44, then 45, then 46, then back to 44. Those small changes feel important, but they usually aren't.",
        },
        {
          t: "trend",
          values: [43, 44, 43, 44, 45, 44, 46],
          caption:
            "Day-to-day readings jump around. Fitness doesn't change overnight — the direction over weeks and months is what matters.",
        },
        {
          t: "p",
          v: "VO₂ max moves slowly. The number that matters isn't today's. It's the direction you're moving over the next few weeks and months.",
        },
      ],
    },
    {
      id: "why-it-drops",
      h: "When a drop means nothing",
      blocks: [
        {
          t: "p",
          v: "Sometimes your VO₂ max drops for reasons that have nothing to do with fitness:",
        },
        {
          t: "ul",
          v: [
            "You just finished a demanding training block",
            "You slept badly for several nights",
            "You're recovering from a cold",
            "You just landed after a long flight",
          ],
        },
        {
          t: "p",
          v: "Your body is under more stress than usual. That doesn't automatically mean you've lost endurance. Sometimes it simply means your body hasn't fully recovered yet.",
        },
      ],
    },
    {
      id: "comparison",
      h: "Don't compare with others",
      blocks: [
        {
          t: "p",
          v: "One person has a VO₂ max of **58**. Another has **41**. Without context, those numbers are almost meaningless.",
        },
        {
          t: "p",
          v: "Age, sex, training history, and genetics all play a role. The only comparison that really matters is between **you today** and **you a few months ago**.",
        },
        {
          t: "p",
          v: "If the long-term trend is moving in the right direction, you're making progress.",
        },
      ],
    },
    {
      id: "readiness",
      h: "Potential vs. ready today",
      blocks: [
        { t: "p", v: "Now imagine two athletes:" },
        {
          t: "compare",
          left: {
            vo2: "58",
            title: "Athlete A",
            lines: ["Slept 4 hours", "Feels exhausted", "Recovery is poor"],
          },
          right: {
            vo2: "42",
            title: "Athlete B",
            lines: ["Slept 8 hours", "Recovered well", "Feels fresh"],
          },
          question: "Who's more ready for a hard workout today?",
        },
        {
          t: "p",
          v: "The answer isn't as obvious as the numbers suggest. VO₂ max tells you about your **potential**. It doesn't tell you how prepared your body is **right now**.",
        },
      ],
    },
    {
      id: "weekfit",
      h: "How WeekFit uses it",
      blocks: [
        {
          t: "p",
          v: "That's why WeekFit never looks at VO₂ max in isolation. It combines it with your sleep, recovery, heart rate variability, resting heart rate, recent training load, and daily activity.",
        },
        {
          t: "p",
          v: "A great VO₂ max doesn't automatically mean it's time to push harder. And an average VO₂ max doesn't mean today can't be your best run of the month.",
        },
        {
          t: "p",
          v: "The smartest training decisions don't come from a single metric. They come from understanding the whole story your body is telling.",
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
          v: "Вы просыпаетесь утром. Открываете Apple Health. Вчера было **46**. Сегодня — **44**.",
        },
        { t: "vo2-drop", before: "46", after: "44", labels: ["Вчера", "Сегодня"] },
        { t: "p", v: "И первая мысль звучит примерно одинаково у всех:" },
        { t: "quote", v: "Что случилось? Я потерял форму?" },
        {
          t: "p",
          v: "Самое интересное — скорее всего, ничего не случилось. VO₂ max — одна из самых полезных метрик Apple Watch и одновременно одна из самых неправильно понятых.",
        },
      ],
    },
    {
      id: "what-it-measures",
      h: "Что на самом деле измеряет VO₂ max",
      blocks: [
        {
          t: "p",
          v: "Представьте два двигателя. Оба могут ехать со скоростью 100 км/ч, но один расходует гораздо меньше топлива — и может ехать дольше.",
        },
        {
          t: "p",
          v: "Во время нагрузки мышцы работают благодаря кислороду. Чем эффективнее организм доставляет и использует кислород, тем меньше сил он тратит на одну и ту же работу.",
        },
        {
          t: "p",
          v: "Именно это и отражает VO₂ max. Не скорость. Не силу. А эффективность всей системы.",
        },
      ],
    },
    {
      id: "estimate",
      h: "Часы вычисляют, а не измеряют",
      blocks: [
        { t: "p", v: "Apple Watch **не измеряет** VO₂ max — она его **вычисляет**." },
        {
          t: "p",
          v: "Настоящее измерение — маска, беговая дорожка, анализ каждого вдоха и выдоха. Часы ничего подобного сделать не могут.",
        },
        {
          t: "p",
          v: "Они смотрят на пульс, скорость движения, возраст, вес, историю тренировок и строят математическую модель. Число на экране — не лабораторный результат, а очень хорошая оценка.",
        },
        {
          t: "p",
          v: "И именно поэтому её не стоит воспринимать слишком буквально.",
        },
      ],
    },
    {
      id: "daily-noise",
      h: "Почему сегодняшняя цифра обманывает",
      blocks: [
        {
          t: "p",
          v: "Самая распространённая ошибка — смотреть на каждое новое значение. Сегодня 43, завтра 44, послезавтра снова 43. Кажется, что организм живёт собственной жизнью.",
        },
        {
          t: "trend",
          values: [43, 44, 43, 44, 45, 44, 46],
          caption:
            "Отдельные измерения почти ничего не говорят. Настоящий тренд виден через месяц — или через три.",
        },
        {
          t: "p",
          v: "VO₂ max меняется очень медленно. За один день вы почти не можете стать значительно выносливее — и точно так же невозможно потерять форму после одной тяжёлой недели.",
        },
      ],
    },
    {
      id: "why-it-drops",
      h: "Когда падение — это нормально",
      blocks: [
        {
          t: "p",
          v: "Иногда показатель падает по простым причинам, не связанным с потерей формы:",
        },
        {
          t: "ul",
          v: [
            "Плохой сон несколько ночей подряд",
            "Возвращение после перелёта",
            "Недавняя болезнь",
            "Завершение тяжёлого тренировочного блока",
          ],
        },
        {
          t: "p",
          v: "Организм устал — и это абсолютно нормально. Не всегда проблема в том, что форма ухудшилась. Иногда телу просто нужно восстановиться.",
        },
      ],
    },
    {
      id: "comparison",
      h: "Не сравнивайте себя с другими",
      blocks: [
        {
          t: "p",
          v: "У кого-то VO₂ max — **58**, у кого-то — **39**. Без контекста эти цифры ничего не значат.",
        },
        {
          t: "p",
          v: "Возраст, пол, история тренировок и даже генетика сильно влияют на показатель. Лучший человек для сравнения — **вы сами несколько месяцев назад**.",
        },
        {
          t: "p",
          v: "Если тренд постепенно растёт — значит, всё работает.",
        },
      ],
    },
    {
      id: "readiness",
      h: "Потенциал и готовность сегодня",
      blocks: [
        { t: "p", v: "Представьте двух людей:" },
        {
          t: "compare",
          left: {
            vo2: "55",
            title: "Первый",
            lines: ["Спал 4 часа", "Сильный стресс", "Чувствует усталость"],
          },
          right: {
            vo2: "42",
            title: "Второй",
            lines: ["Выспался", "Хорошо восстановился", "Полон энергии"],
          },
          question: "Кто сегодня лучше готов к интенсивной тренировке?",
        },
        {
          t: "p",
          v: "Ответ не такой очевидный, как кажется. VO₂ max рассказывает о вашей выносливости, но ничего не говорит о том, насколько организм готов работать **именно сегодня**.",
        },
      ],
    },
    {
      id: "weekfit",
      h: "Как WeekFit использует VO₂ max",
      blocks: [
        {
          t: "p",
          v: "WeekFit никогда не принимает решения по одной цифре. Он смотрит на VO₂ max вместе со сном, восстановлением, пульсом покоя, вариабельностью сердечного ритма, недавними тренировками и общей нагрузкой.",
        },
        {
          t: "p",
          v: "Высокий VO₂ max не означает, что сегодня обязательно нужно тренироваться тяжело. Так же как средний показатель не означает, что день потерян.",
        },
        {
          t: "p",
          v: "Самая важная цифра — не та, которую показывает Apple Watch. Самая важная — это история, которую рассказывают все ваши данные вместе.",
        },
      ],
    },
  ],
};
