import type { DocSection } from "@/lib/content";

export const foodRecognitionArticleSections: { en: DocSection[]; ru: DocSection[] } = {
  en: [
    {
      id: "intro",
      h: "",
      blocks: [
        {
          t: "p",
          v: "Logging food fails when it takes longer than eating. Food recognition in WeekFit is the short path: **a photo of the plate**, an estimate of calories and macros, and a moment for you to agree before it lands in the day.",
        },
        {
          t: "quote",
          v: "The plate is a guess until you confirm it.",
        },
      ],
    },
    {
      id: "how",
      h: "How a photo becomes a log",
      blocks: [
        {
          t: "p",
          v: "Open Log Food. Take a photo now or choose one from your library. WeekFit estimates the dish and returns calories, protein, carbs, and fat. You check the name and the amount, then save it to today.",
        },
        {
          t: "ul",
          v: [
            "A clear plate beats a dark restaurant table.",
            "One dish in frame is easier than a whole table.",
            "If the package is clearer than the photo, use the barcode or the nutrition label instead.",
          ],
        },
        {
          t: "p",
          v: "Photo estimates are part of the full WeekFit subscription. The diary entry is yours to edit. Nothing is logged until you accept it.",
        },
      ],
    },
    {
      id: "misses",
      h: "Why the estimate misses",
      blocks: [
        {
          t: "p",
          v: "A photo cannot weigh oil, sauce, or the sugar in a drink sitting just outside the frame. Mixed plates, shared dishes, and “a bit of cheese” are where estimates drift.",
        },
        {
          t: "ul",
          v: [
            "Correct the portion if the plate was larger than it looks.",
            "Add the drink if it was not in the photo.",
            "A 20% miss you fix is more useful than a meal you never log.",
          ],
        },
        {
          t: "p",
          v: "Treat the number as a starting point for the day, not a lab result. The point is a log you will actually keep.",
        },
      ],
    },
    {
      id: "photo",
      h: "Where the photo goes",
      blocks: [
        {
          t: "p",
          v: "The photo is sent so the estimate can be made. That is separate from Apple Health. Sleep, heart rate, and workouts stay in Health and are not uploaded as part of a meal photo.",
        },
        {
          t: "p",
          v: "If you would rather not send a picture, log the meal by hand or from a barcode. The rest of the day still works.",
        },
      ],
    },
    {
      id: "day",
      h: "Why it belongs next to training",
      blocks: [
        {
          t: "p",
          v: "A calorie number alone does not know you have intervals at 18:00. In WeekFit the log sits with activity and recovery, so food is context: enough before the session, protein after it, and a calmer target on a short-sleep day.",
        },
        {
          t: "p",
          v: "Photograph the meal you actually ate. Then let the day use it — instead of reconstructing dinner from memory at 23:00.",
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
          v: "Учёт еды ломается, когда он длиннее самой еды. Распознавание в WeekFit — короткий путь: **фото тарелки**, оценка калорий и БЖУ, и ваше согласие, прежде чем запись попадёт в день.",
        },
        {
          t: "quote",
          v: "Тарелка остаётся догадкой, пока вы её не подтвердите.",
        },
      ],
    },
    {
      id: "how",
      h: "Как фото становится записью",
      blocks: [
        {
          t: "p",
          v: "Откройте запись еды. Снимите блюдо сейчас или выберите снимок из библиотеки. WeekFit оценивает блюдо и возвращает калории, белки, углеводы и жиры. Проверьте название и количество, затем сохраните на сегодня.",
        },
        {
          t: "ul",
          v: [
            "Ясная тарелка лучше тёмного ресторанного стола.",
            "Одно блюдо в кадре проще, чем весь стол.",
            "Если упаковка яснее фото, возьмите штрихкод или этикетку с составом.",
          ],
        },
        {
          t: "p",
          v: "Оценка по фото входит в полную версию WeekFit. Запись в дневнике можно поправить. Ничего не сохраняется, пока вы не согласитесь.",
        },
      ],
    },
    {
      id: "misses",
      h: "Почему оценка промахивается",
      blocks: [
        {
          t: "p",
          v: "Фото не взвешивает масло, соус и сахар в напитке за краем кадра. Смешанные тарелки, общие блюда и «немного сыра» — места, где оценка плывёт.",
        },
        {
          t: "ul",
          v: [
            "Поправьте порцию, если тарелка была больше, чем кажется.",
            "Добавьте напиток, если его не было на снимке.",
            "Промах на пятую часть, который вы исправили, полезнее ужина, который вы так и не записали.",
          ],
        },
        {
          t: "p",
          v: "Считайте число отправной точкой дня, а не лабораторным результатом. Смысл — в записи, которую вы реально ведёте.",
        },
      ],
    },
    {
      id: "photo",
      h: "Куда уходит снимок",
      blocks: [
        {
          t: "p",
          v: "Снимок отправляется, чтобы появилась оценка. Это отдельно от Apple Health. Сон, пульс и тренировки остаются в «Здоровье» и не уезжают вместе с фото еды.",
        },
        {
          t: "p",
          v: "Если снимок отправлять не хотите, запишите блюдо вручную или по штрихкоду. Остальной день от этого не ломается.",
        },
      ],
    },
    {
      id: "day",
      h: "Зачем это рядом с тренировкой",
      blocks: [
        {
          t: "p",
          v: "Одни калории не знают, что в 18:00 интервалы. В WeekFit запись стоит рядом с активностью и восстановлением: еда до сессии, белок после, спокойнее цель в день короткого сна.",
        },
        {
          t: "p",
          v: "Снимите то, что вы действительно съели. Пусть день использует эту запись — вместо того чтобы вспоминать ужин в одиннадцать вечера.",
        },
      ],
    },
  ],
};
