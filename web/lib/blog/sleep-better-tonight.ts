import type { DocSection } from "@/lib/content";

export const sleepBetterTonightArticleSections: { en: DocSection[]; ru: DocSection[] } = {
  en: [
    {
      id: "intro",
      h: "",
      blocks: [
        {
          t: "p",
          v: "Most sleep advice fails because it asks you to rebuild your life. This guide is the opposite: a few **small levers** that make tonight better — even if your schedule is messy.",
        },
        { t: "quote", v: "Better sleep is usually a system, not a hack." },
      ],
    },
    {
      id: "two-hour-runway",
      h: "Give your brain a two‑hour runway",
      blocks: [
        {
          t: "p",
          v: "You don’t need a perfect evening routine. But you do need a boundary between “day mode” and “sleep mode”. A simple rule: **protect the last two hours**.",
        },
        {
          t: "ul",
          v: [
            "Make the last 2 hours **predictable** (same order of actions, not the same time).",
            "Keep “heavy thinking” earlier — planning tomorrow, hard emails, intense conversations.",
            "If you train late, keep it easy: walk, mobility, light strength. Hard intervals close to bed often show up as restless sleep.",
          ],
        },
      ],
    },
    {
      id: "light",
      h: "Light is the fastest switch",
      blocks: [
        {
          t: "p",
          v: "Your body clock listens to light more than it listens to motivation. Two moves matter most: **bright light early** and **dim light late**.",
        },
        {
          t: "ul",
          v: [
            "Within 60 minutes of waking: go outside for 5–10 minutes (even cloudy days count).",
            "After sunset: keep the room warm and dim; turn down overhead lights if you can.",
            "If you must use your phone: lower brightness and avoid scrolling in bed — it trains your brain that bed is for content, not sleep.",
          ],
        },
      ],
    },
    {
      id: "caffeine",
      h: "Treat caffeine like a half‑day commitment",
      blocks: [
        {
          t: "p",
          v: "Caffeine doesn’t “wear off” when you stop feeling it. For many people, a late coffee quietly reduces deep sleep.",
        },
        {
          t: "ul",
          v: [
            "If your sleep is fragile: stop caffeine **8–10 hours** before bed for a week and see what changes.",
            "If you’re fine most days: still try a softer cutoff (6–8 hours).",
            "Energy drinks hit harder than you think — not just caffeine, but timing and sugar spikes.",
          ],
        },
      ],
    },
    {
      id: "temperature",
      h: "Cool body, warm hands",
      blocks: [
        {
          t: "p",
          v: "Sleep starts when core temperature drops. That’s why a slightly cool room often works better than “cozy warm”.",
        },
        {
          t: "ul",
          v: [
            "Try a cooler bedroom (or just a cooler blanket).",
            "Warm shower 60–90 minutes before bed can help — it warms skin, then your core drops after.",
            "Cold feet keep people awake: warm socks can be more effective than another supplement.",
          ],
        },
      ],
    },
    {
      id: "middle-of-night",
      h: "If you wake up at 3 a.m.",
      blocks: [
        {
          t: "p",
          v: "Waking up isn’t the problem. The spiral is. Your job is to **keep the wake small**.",
        },
        {
          t: "ul",
          v: [
            "Don’t check the time. It turns one wake into a performance review.",
            "If you’re awake > 15–20 minutes: get up briefly, keep lights low, read a few pages, then return.",
            "Avoid “fixing” with bright screens — it’s the quickest way to fully wake the brain.",
          ],
        },
      ],
    },
    {
      id: "weekfit",
      h: "How WeekFit uses sleep",
      blocks: [
        {
          t: "p",
          v: "WeekFit doesn’t just count hours. It reads sleep alongside recovery signals (HRV, resting heart rate) and your plan. If sleep was short or broken, Coach will bias you toward a calmer training day, steadier nutrition, and earlier recovery — so tomorrow is easier.",
        },
      ],
    },
    {
      id: "checklist",
      h: "Tonight’s tiny checklist",
      blocks: [
        {
          t: "ul",
          v: [
            "Get outside briefly after waking.",
            "Stop caffeine earlier than usual (even 1–2 hours earlier helps).",
            "Dim lights and stop heavy thinking in the last two hours.",
            "Keep the room slightly cool; warm feet if needed.",
          ],
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
          v: "Проблема большинства советов про сон в том, что они требуют перестроить жизнь. Здесь наоборот: несколько **маленьких рычагов**, которые улучшат уже сегодняшнюю ночь — даже если график хаотичный.",
        },
        { t: "quote", v: "Хороший сон — это обычно система, а не лайфхак." },
      ],
    },
    {
      id: "two-hour-runway",
      h: "Дайте мозгу «взлётную полосу» на 2 часа",
      blocks: [
        {
          t: "p",
          v: "Не нужен идеальный вечерний ритуал. Нужна граница между «режимом дня» и «режимом сна». Простое правило: **защитите последние два часа**.",
        },
        {
          t: "ul",
          v: [
            "Сделайте последние 2 часа **предсказуемыми** (одинаковый порядок действий, не обязательно одинаковое время).",
            "Тяжёлые задачи — раньше: планы на завтра, сложные письма, напряжённые разговоры.",
            "Если тренируетесь поздно — лучше лёгкое: прогулка, мобилити, лёгкая силовая. Жёсткие интервалы перед сном часто делают сон беспокойным.",
          ],
        },
      ],
    },
    {
      id: "light",
      h: "Свет — самый быстрый переключатель",
      blocks: [
        {
          t: "p",
          v: "Биологические часы слушают свет больше, чем мотивацию. Две вещи важнее всего: **яркий свет утром** и **приглушённый вечером**.",
        },
        {
          t: "ul",
          v: [
            "В течение 60 минут после подъёма: выйдите на улицу на 5–10 минут (пасмурно тоже считается).",
            "После заката: сделайте свет тёплым и мягким; по возможности уберите яркий верхний свет.",
            "Если телефон нужен: снизьте яркость и не скролльте в постели — мозг привыкает, что кровать = контент, а не сон.",
          ],
        },
      ],
    },
    {
      id: "caffeine",
      h: "Кофеин — это обязательство на полдня",
      blocks: [
        {
          t: "p",
          v: "Кофеин не «уходит», когда вы перестали его ощущать. У многих поздний кофе тихо снижает глубокий сон.",
        },
        {
          t: "ul",
          v: [
            "Если сон хрупкий: попробуйте убрать кофеин за **8–10 часов** до сна на неделю и посмотрите, что изменится.",
            "Если в целом всё ок: всё равно полезен более мягкий cutoff (6–8 часов).",
            "Энергетики бьют сильнее, чем кажется — не только кофеин, но и тайминг + сахарные пики.",
          ],
        },
      ],
    },
    {
      id: "temperature",
      h: "Охладите тело, согрейте руки и ноги",
      blocks: [
        {
          t: "p",
          v: "Сон начинается, когда падает температура тела. Поэтому слегка прохладная комната часто работает лучше, чем «уютно жарко».",
        },
        {
          t: "ul",
          v: [
            "Попробуйте прохладнее в спальне (или просто более лёгкое одеяло).",
            "Тёплый душ за 60–90 минут до сна может помочь — кожа нагревается, а затем «ядро» остывает.",
            "Холодные ступни часто держат людей в бодрствовании: тёплые носки иногда эффективнее любой добавки.",
          ],
        },
      ],
    },
    {
      id: "middle-of-night",
      h: "Если проснулись в 3 ночи",
      blocks: [
        {
          t: "p",
          v: "Просыпаться — нормально. Проблема в раскручивании мыслей. Ваша задача — **сделать пробуждение маленьким**.",
        },
        {
          t: "ul",
          v: [
            "Не смотрите на часы. Это превращает одно пробуждение в «проверку результата».",
            "Если бодрствуете > 15–20 минут: встаньте ненадолго, держите свет мягким, почитайте пару страниц и возвращайтесь.",
            "Не «чините» экраном — яркий свет быстрее всего полностью будит мозг.",
          ],
        },
      ],
    },
    {
      id: "weekfit",
      h: "Как WeekFit использует сон",
      blocks: [
        {
          t: "p",
          v: "WeekFit не просто считает часы. Он читает сон вместе с сигналами восстановления (ВСР, пульс покоя) и вашим планом. Если сон был коротким или прерывистым, Коуч сместит фокус в сторону более спокойной нагрузки, более ровного питания и раннего восстановления — чтобы завтра стало легче.",
        },
      ],
    },
    {
      id: "checklist",
      h: "Мини-чеклист на сегодня",
      blocks: [
        {
          t: "ul",
          v: [
            "Утром — коротко на улицу.",
            "Кофеин остановить раньше обычного (даже на 1–2 часа раньше уже помогает).",
            "За 2 часа до сна — мягкий свет и без тяжёлых задач.",
            "Комната чуть прохладнее; ноги — теплее при необходимости.",
          ],
        },
      ],
    },
  ],
};

