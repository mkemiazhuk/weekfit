import type { DocSection } from "@/lib/content";

export const stressIndexArticleSections: { en: DocSection[]; ru: DocSection[] } = {
  en: [
    {
      id: "intro",
      h: "",
      blocks: [
        {
          t: "p",
          v: "A stress index is easy to take personally. A high number can feel like the app is judging your day. It is not. In WeekFit the stress index is a **physiological strain read** — last night and yesterday, compared with your own recent norm.",
        },
        {
          t: "quote",
          v: "Feeling busy and a high stress index are not the same thing.",
        },
      ],
    },
    {
      id: "signals",
      h: "What the index is made of",
      blocks: [
        {
          t: "p",
          v: "WeekFit builds the index from Apple Health, not from a mood check-in. Four signals can contribute. Heart rate variability and resting heart rate carry the most weight. Sleep and yesterday’s training load fill in the rest.",
        },
        {
          t: "ul",
          v: [
            "**HRV** — lower than your norm pushes strain up.",
            "**Resting heart rate** — higher than your norm does the same.",
            "**Sleep** — a short or broken night adds strain even when the heart looks calm.",
            "**Training load** — a hard session yesterday still counts this morning.",
          ],
        },
        {
          t: "p",
          v: "The index needs enough of those signals to be honest. If sleep is missing and there is no personal heart baseline yet, WeekFit leaves the index blank instead of showing a fake zero.",
        },
      ],
    },
    {
      id: "levels",
      h: "Low, moderate, elevated, high",
      blocks: [
        {
          t: "p",
          v: "When the read is confident, you see a score **out of 100** and a level: Low, Moderate, Elevated, or High. A higher score means more strain in the signals, not a worse personality.",
        },
        {
          t: "p",
          v: "If the night is thin on data, WeekFit may keep the level and hide the precise number. A level without a score is still useful. A precise score on a guess is not.",
        },
      ],
    },
    {
      id: "not-recovery",
      h: "It is not the recovery score",
      blocks: [
        {
          t: "p",
          v: "Recovery asks whether you are ready to train. The stress index asks how much strain the signals are already carrying. They can disagree.",
        },
        {
          t: "p",
          v: "You can wake up recovered enough for the planned session and still see an elevated stress index, because HRV has not caught your recent norm. Or recovery can be low while the stress index stays quiet, if the limiter is sleep debt more than heart strain. Read them together. Don’t let one cancel the other.",
        },
      ],
    },
    {
      id: "what-to-do",
      h: "What to do with the level",
      blocks: [
        {
          t: "ul",
          v: [
            "**Low or moderate** — train what you planned. No bonus session just because the number looks kind.",
            "**Elevated** — keep the main work, drop the extra volume, and protect the evening.",
            "**High** — easy movement only. A hard session to “burn off stress” usually adds the strain the index already flagged.",
          ],
        },
        {
          t: "p",
          v: "This is a daily guide, not a medical test. If you feel unwell, dizzy, or unlike yourself, the index is not the decision. You are.",
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
          v: "Индекс стресса легко принять на свой счёт. Высокая цифра будто оценивает ваш день. Нет. В WeekFit это **показатель физиологической нагрузки** — прошедшая ночь и вчерашний день на фоне вашей недавней нормы.",
        },
        {
          t: "quote",
          v: "Занятый день и высокий индекс стресса — не одно и то же.",
        },
      ],
    },
    {
      id: "signals",
      h: "Из чего он складывается",
      blocks: [
        {
          t: "p",
          v: "WeekFit считает индекс по данным Apple Health, а не по отметке настроения. Вклад дают четыре сигнала. Больше всего весят вариабельность сердечного ритма и пульс покоя. Сон и вчерашняя нагрузка дополняют картину.",
        },
        {
          t: "ul",
          v: [
            "**ВСР** — ниже вашей нормы, и нагрузка растёт.",
            "**Пульс покоя** — выше нормы, и эффект тот же.",
            "**Сон** — короткая или рваная ночь добавляет нагрузку, даже если сердце выглядит спокойным.",
            "**Тренировка** — тяжёлая сессия вчера ещё считается сегодня утром.",
          ],
        },
        {
          t: "p",
          v: "Индексу нужно достаточно сигналов, чтобы не врать. Если нет сна и ещё нет личной нормы по сердцу, WeekFit оставляет индекс пустым — вместо нуля, которого не было.",
        },
      ],
    },
    {
      id: "levels",
      h: "Низкий, умеренный, повышенный, высокий",
      blocks: [
        {
          t: "p",
          v: "Когда данных хватает, вы видите оценку **из 100** и уровень: низкий, умеренный, повышенный или высокий. Больше — значит больше нагрузки в сигналах, а не «вы хуже».",
        },
        {
          t: "p",
          v: "Если ночь бедная на данные, WeekFit может оставить уровень и скрыть точную цифру. Уровень без числа всё ещё полезен. Точное число на догадке — нет.",
        },
      ],
    },
    {
      id: "not-recovery",
      h: "Это не показатель восстановления",
      blocks: [
        {
          t: "p",
          v: "Восстановление отвечает, готовы ли вы тренироваться. Индекс стресса — сколько нагрузки сигналы уже несут. Они могут расходиться.",
        },
        {
          t: "p",
          v: "Утром восстановление может быть достаточным для плана, а индекс — повышенным: вариабельность ещё не догнала вашу норму. Или восстановление низкое, а индекс спокойный, если ограничитель — недосып, а не сердце. Читайте оба. Один не отменяет другой.",
        },
      ],
    },
    {
      id: "what-to-do",
      h: "Что делать с уровнем",
      blocks: [
        {
          t: "ul",
          v: [
            "**Низкий или умеренный** — делайте запланированное. Не добавляйте вторую сессию только потому, что цифра добрая.",
            "**Повышенный** — оставьте главную работу, уберите лишний объём и берегите вечер.",
            "**Высокий** — только лёгкое движение. Тяжёлая тренировка «чтобы сжечь стресс» обычно добавляет ту нагрузку, на которую индекс уже указал.",
          ],
        },
        {
          t: "p",
          v: "Это ориентир на день, не медицинский тест. Если вам плохо, кружится голова или вы себя не узнаёте — решает не индекс, а вы.",
        },
      ],
    },
  ],
};
