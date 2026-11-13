import type { DocSection } from "@/lib/content";

export const mayaCoachArticleSections: { en: DocSection[]; ru: DocSection[] } = {
  en: [
    {
      id: "intro",
      h: "",
      blocks: [
        {
          t: "p",
          v: "Most coaching apps hand you another screen of numbers. **Maya** is the opposite: a voice on Today. You call her, say what the day actually looks like, and get a decision you can carry into the afternoon.",
        },
        {
          t: "quote",
          v: "The useful part is saying it out loud.",
        },
      ],
    },
    {
      id: "where",
      h: "Where Maya lives",
      blocks: [
        {
          t: "p",
          v: "On Today, Maya is one card. Tap to call. If you already spoke, the card brings you back into the conversation instead of starting from zero.",
        },
        {
          t: "p",
          v: "The card also shows how much call time is left. Maya is part of the full WeekFit subscription. When the minutes run out, the card says so before you tap — not halfway through a sentence.",
        },
      ],
    },
    {
      id: "ask",
      h: "What a call is for",
      blocks: [
        {
          t: "p",
          v: "Maya can see today’s plan: what is still ahead and what you already did. Ask in plain language. Move a session, keep the easy day, or put food before the workout instead of after it.",
        },
        {
          t: "ul",
          v: [
            "“I slept badly and intervals are at 18:00. Keep them?”",
            "“Move the ride to tomorrow morning.”",
            "“What should I eat before the session, not after?”",
          ],
        },
        {
          t: "p",
          v: "She answers in your language and can place the change on the plan. You still confirm the day. The call is a conversation, not a silent rewrite of the week.",
        },
      ],
    },
    {
      id: "not",
      h: "What she is not",
      blocks: [
        {
          t: "p",
          v: "Maya is not a doctor and not a second dashboard. The written coach on Today still gives the short read — what matters now and why. Maya is for the moment the day gets messy and a chart is the wrong shape for the question.",
        },
        {
          t: "p",
          v: "Don’t use the call to negotiate with a number you already understand. Use it when you need the plan to change in a sentence.",
        },
      ],
    },
    {
      id: "better-call",
      h: "A better call",
      blocks: [
        {
          t: "ul",
          v: [
            "One real constraint: sleep, time, or soreness.",
            "One decision: keep, shorten, or move.",
            "Then leave the call and do that thing.",
          ],
        },
        {
          t: "p",
          v: "A long monologue about the whole week usually produces a vague answer. A specific afternoon produces a plan you can follow before dinner.",
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
          v: "Большинство приложений-коучей дают ещё один экран с цифрами. **Maya** устроена иначе: голос на экране «Сегодня». Вы звоните, говорите, каким вышел день, и уносите решение, которому можно следовать.",
        },
        {
          t: "quote",
          v: "Польза в том, чтобы сказать это вслух.",
        },
      ],
    },
    {
      id: "where",
      h: "Где её найти",
      blocks: [
        {
          t: "p",
          v: "На экране «Сегодня» Maya — одна карточка. Нажмите, чтобы позвонить. Если вы уже говорили, карточка возвращает в разговор, а не начинает с нуля.",
        },
        {
          t: "p",
          v: "На карточке видно, сколько минут звонка осталось. Maya входит в полную версию WeekFit. Когда минуты кончаются, карточка говорит об этом до нажатия — не на полуслове.",
        },
      ],
    },
    {
      id: "ask",
      h: "Зачем звонить",
      blocks: [
        {
          t: "p",
          v: "Maya видит план на сегодня: что ещё впереди и что уже сделано. Спросите обычными словами. Перенесите тренировку, оставьте лёгкий день или поставьте еду до сессии, а не после.",
        },
        {
          t: "ul",
          v: [
            "«Плохо спал, интервалы в 18:00. Оставлять?»",
            "«Перенеси поездку на завтрашнее утро.»",
            "«Что съесть до тренировки, а не после?»",
          ],
        },
        {
          t: "p",
          v: "Она отвечает на вашем языке и может положить изменение в план. День всё равно подтверждаете вы. Звонок — разговор, а не тихая перепись недели.",
        },
      ],
    },
    {
      id: "not",
      h: "Кем она не является",
      blocks: [
        {
          t: "p",
          v: "Maya — не врач и не вторая панель графиков. Короткий вывод на экране «Сегодня» по-прежнему говорит, что важно сейчас и почему. Maya нужна, когда день сбился и график — неудачная форма для вопроса.",
        },
        {
          t: "p",
          v: "Не звоните, чтобы спорить с цифрой, которую уже поняли. Звоните, когда план нужно изменить одним предложением.",
        },
      ],
    },
    {
      id: "better-call",
      h: "Как звонить полезнее",
      blocks: [
        {
          t: "ul",
          v: [
            "Одно настоящее ограничение: сон, время или усталость.",
            "Одно решение: оставить, укоротить или перенести.",
            "Потом выйти из звонка и сделать это.",
          ],
        },
        {
          t: "p",
          v: "Длинный рассказ про всю неделю обычно даёт расплывчатый ответ. Конкретный день даёт план, которому можно следовать до ужина.",
        },
      ],
    },
  ],
};
