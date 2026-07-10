import type { DocSection } from "@/lib/content";

export const preWorkoutNutritionArticleSections: { en: DocSection[]; ru: DocSection[] } = {
  en: [
    {
      id: "intro",
      h: "",
      blocks: [
        {
          t: "p",
          v: "Someone asks me this at least once a week: \"What should I eat before training?\" And honestly — most of the advice online sounds like a chemistry exam. Grams, timing windows, forbidden foods…",
        },
        {
          t: "p",
          v: "Here's the version I'd give a friend. Not perfect. Just practical. The goal is simple: **have energy for the session, feel good during it, and recover without overthinking.**",
        },
        { t: "quote", v: "You don't need a perfect plan. You need a repeatable one." },
      ],
    },
    {
      id: "three-hours-before",
      h: "About 3 hours before — your main meal",
      blocks: [
        {
          t: "p",
          v: "Three hours out is the sweet spot for most people. Food has time to digest, blood sugar is stable, and you're not training with a full stomach.",
        },
        {
          t: "p",
          v: "**What to aim for on the plate:**",
        },
        {
          t: "ul",
          v: [
            "**Carbs** — your fuel. Rice, oats, pasta, potato, bread, fruit. This is not the meal to go low-carb.",
            "**Protein** — chicken, fish, eggs, yogurt, tofu. Keeps you satisfied and starts recovery early.",
            "**A little fat** — olive oil, avocado, nuts. Fine in normal amounts; you don't need a lot.",
            "**Water** — start hydrating here, not five minutes before you start.",
          ],
        },
        {
          t: "p",
          v: "**What to watch for:**",
        },
        {
          t: "ul",
          v: [
            "Portion size — eat **enough**, not \"as little as possible.\" Under-fuelling feels like \"I have no legs today.\"",
            "Fiber and very fatty meals — a huge salad with loads of beans and cheese can sit heavy. Save that for after.",
            "Brand-new foods — race day is not the day to try the spicy bowl you saw on TikTok.",
            "Caffeine timing — coffee 60–90 minutes before is fine for most; right before can upset your stomach on hard intervals.",
          ],
        },
        {
          t: "p",
          v: "**Easy examples:** oatmeal with banana and yogurt; rice bowl with chicken and vegetables; sandwich with turkey and fruit on the side. Nothing fancy.",
        },
      ],
    },
    {
      id: "closer-to-start",
      h: "60–90 minutes before — if you still need something",
      blocks: [
        {
          t: "p",
          v: "Training early, or your last meal was a while ago? A **small, simple snack** is enough — not a second lunch.",
        },
        {
          t: "ul",
          v: [
            "Banana or dates",
            "Toast with honey or jam",
            "A small yogurt",
            "Half an energy bar you already know sits well",
          ],
        },
        {
          t: "p",
          v: "**Skip** large amounts of fat, heavy protein shakes, or anything that usually makes you bloated. You're topping up glucose, not building a meal.",
        },
      ],
    },
    {
      id: "during",
      h: "During the workout — what matters",
      blocks: [
        {
          t: "p",
          v: "Most gym sessions under **60–75 minutes** don't need calories mid-session. Water (or an electrolyte drink if you sweat a lot) is enough.",
        },
        {
          t: "p",
          v: "**When to eat or drink more during training:**",
        },
        {
          t: "ul",
          v: [
            "Sessions **over 90 minutes** — running, cycling, long HIIT blocks",
            "Training in **heat** or high humidity",
            "You feel **light-headed, flat, or unusually weak** — that's a signal, not weakness",
            "Hard intervals with **short rest** — mouth gets dry, performance drops",
          ],
        },
        {
          t: "p",
          v: "**What to do:** sip regularly; don't wait until you're parched. For longer work, **30–60 g carbs per hour** is a common range — gels, chews, diluted sports drink, or even a few dates. Start before you feel empty.",
        },
        {
          t: "p",
          v: "**What to watch:** heart rate drifting up for the same effort, cramping, nausea, or a sudden \"bonk.\" Often that's under-fuelling or dehydration from hours earlier — not just \"during.\"",
        },
      ],
    },
    {
      id: "after",
      h: "After — the first hour counts, but don't panic",
      blocks: [
        {
          t: "p",
          v: "You don't need to sprint to the shaker bottle. But **within roughly 1–2 hours**, give your body carbs + protein so glycogen refills and muscle repair starts.",
        },
        {
          t: "ul",
          v: [
            "**Carbs again** — rice, pasta, potatoes, fruit, bread. Training depleted them.",
            "**Protein** — 20–40 g for most people. Eggs, fish, meat, dairy, powder if convenient.",
            "**Fluids** — replace what you lost. Pale urine later in the day is a boring but useful check.",
            "**Salt** — if you sweated heavily, normal food (broth, salted meal) beats plain water alone.",
          ],
        },
        {
          t: "p",
          v: "**If your next session is tomorrow morning** and today's was hard, don't go to bed on salad only. A proper dinner matters more than a perfect post-workout window.",
        },
        {
          t: "p",
          v: "**If you're not hungry** — a small shake or yogurt with fruit still helps. Skipping entirely because \"I burned calories\" is how people feel awful on the next training day.",
        },
      ],
    },
    {
      id: "what-to-bring",
      h: "What to pack — the no-drama gym bag list",
      blocks: [
        {
          t: "p",
          v: "Half the battle is showing up prepared so you're not buying random snacks from a vending machine.",
        },
        {
          t: "ul",
          v: [
            "**Water bottle** — full. Refill if the gym has a fountain.",
            "**Pre-workout snack** (if needed) — banana, bar, or dates in a small container.",
            "**Post-workout option** — shaker + powder, or a ready yogurt / milk box if you won't eat for a while.",
            "**Electrolytes** — single sachet or tablet for hot days or long sessions.",
            "**Towel + optional fruit** — sounds basic; it's what people forget when rushing from work.",
          ],
        },
        {
          t: "p",
          v: "Keep a **duplicate set** at work or in your car if you train after office hours. Consistency beats willpower.",
        },
      ],
    },
    {
      id: "checklist",
      h: "If you remember only three things",
      blocks: [
        {
          t: "ul",
          v: [
            "**3 hours before:** real meal with carbs + protein, familiar foods, start drinking water.",
            "**During:** water first; add carbs only if the session is long or hard enough to need them.",
            "**After:** carbs + protein within a couple of hours — then a normal dinner if training was serious.",
          ],
        },
        {
          t: "p",
          v: "WeekFit's Meals view is built around this kind of day — pre-workout fuel, what you logged, and what the Coach suggests when recovery and training load don't match the plan. Less guessing, more showing up ready.",
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
          v: "Раз в неделю мне точно пишут: «Что есть перед тренировкой?» И честно — советы в интернете часто звучат как экзамен по химии. Граммы, окна, запреты…",
        },
        {
          t: "p",
          v: "Ниже — как я объяснил бы другу. Без идеала, зато по делу. Цель простая: **хватило энергии на занятие, было комфортно во время и нормально восстановиться — без лишней головной боли.**",
        },
        { t: "quote", v: "Нужен не идеальный план, а тот, который повторяется из раза в раз." },
      ],
    },
    {
      id: "three-hours-before",
      h: "За ~3 часа — основной приём пищи",
      blocks: [
        {
          t: "p",
          v: "Три часа — удобная точка для большинства. Еда успевает перевариться, сахар в крови стабилен, и вы не идёте на тренировку с полным желудком.",
        },
        {
          t: "p",
          v: "**Что положить на тарелку:**",
        },
        {
          t: "ul",
          v: [
            "**Углеводы** — топливо. Рис, овсянка, паста, картофель, хлеб, фрукты. Это не время для жёсткого low-carb.",
            "**Белок** — курица, рыба, яйца, йогурт, тофу. Дольше сыт и раньше стартует восстановление.",
            "**Немного жира** — масло, авокадо, орехи. В обычных порциях — нормально.",
            "**Вода** — пить начинайте здесь, а не за пять минут до старта.",
          ],
        },
        {
          t: "p",
          v: "**На что смотреть:**",
        },
        {
          t: "ul",
          v: [
            "Размер порции — ешьте **достаточно**, а не «как можно меньше». Недоедание = «ног нет» на тренировке.",
            "Много клетчатки и жирное — огромный салат с фасолью и сыром может тяжело лежать. Оставьте на потом.",
            "Новая еда — день важной тренировки не лучший момент пробовать острое боул из ленты.",
            "Кофеин — кофе за 60–90 минут до занятия большинству ок; впритык к старту на интервалах может upset stomach.",
          ],
        },
        {
          t: "p",
          v: "**Простые примеры:** овсянка с бананом и йогуртом; рис с курицей и овощами; сандвич с индейкой и фрукт сбоку. Без ресторанной магии.",
        },
      ],
    },
    {
      id: "closer-to-start",
      h: "За 60–90 минут — если нужен лёгкий перекус",
      blocks: [
        {
          t: "p",
          v: "Тренировка рано или последний приём был давно? **Небольшой простой перекус** — не второй обед.",
        },
        {
          t: "ul",
          v: [
            "Банан или финики",
            "Тост с мёдом или вареньем",
            "Небольшой йогурт",
            "Половина батончика, который вы уже знаете — садится нормально",
          ],
        },
        {
          t: "p",
          v: "**Лучше пропустить** много жира, тяжёлый протеиновый шейк или всё, от чего обычно вздувает. Вы поднимаете глюкозу, а не собираете полноценный приём пищи.",
        },
      ],
    },
    {
      id: "during",
      h: "Во время тренировки — что важно",
      blocks: [
        {
          t: "p",
          v: "Для большинства занятий **до 60–75 минут** калории посередине не нужны. Достаточно воды (или напитка с электролитами, если сильно потеете).",
        },
        {
          t: "p",
          v: "**Когда есть смысл есть или пить больше:**",
        },
        {
          t: "ul",
          v: [
            "Занятие **дольше 90 минут** — бег, вело, длинный HIIT",
            "Тренировка **в жару** или высокой влажности",
            "Кружится голова, «пусто», необычная слабость — это сигнал, а не «слабая воля»",
            "Тяжёлые интервалы с **коротким отдыхом** — пересыхает во рту, падает темп",
          ],
        },
        {
          t: "p",
          v: "**Что делать:** пить регулярно, не ждать жажды. На длинной работе часто ориентируются на **30–60 г углеводов в час** — гели, жвачки, разбавленный изотоник или те же финики. Начинать до ощущения «пусто».",
        },
        {
          t: "p",
          v: "**На что смотреть:** пульс растёт при той же нагрузке, судороги, тошнота, резкий «bonk». Часто это недоедание или обезвоживание **ещё до** зала — не только «во время».",
        },
      ],
    },
    {
      id: "after",
      h: "После — первый час важен, но без паники",
      blocks: [
        {
          t: "p",
          v: "Не обязательно бежать к шейкеру. Но **примерно в течение 1–2 часов** дайте телу углеводы + белок — гликоген восполнится, ремонт мышц начнётся.",
        },
        {
          t: "ul",
          v: [
            "**Снова углеводы** — рис, паста, картофель, фрукты, хлеб. Тренировка их потратила.",
            "**Белок** — для большинства 20–40 г. Яйца, рыба, мясо, молочное, порошок если удобно.",
            "**Жидкость** — заменить потерянное. Бледная моча позже — скучная, но полезная проверка.",
            "**Соль** — если сильно потели, обычная еда (бульон, нормальный ужин) лучше одной воды.",
          ],
        },
        {
          t: "p",
          v: "**Если завтра утром снова тренировка**, а сегодня было тяжело — не ложитесь спать на один салат. Полноценный ужин важнее идеального «окна после».",
        },
        {
          t: "p",
          v: "**Если аппетита нет** — маленький шейк или йогурт с фруктом всё равно помогут. Пропустить «потому что сожгли калории» — верный путь к плохому самочувствию завтра.",
        },
      ],
    },
    {
      id: "what-to-bring",
      h: "Что взять с собой — список без драмы",
      blocks: [
        {
          t: "p",
          v: "Половина успеха — прийти подготовленным, а не покупать случайное в автомате.",
        },
        {
          t: "ul",
          v: [
            "**Бутылка воды** — полная. Долить в зале, если есть кулер.",
            "**Перекус до** (если нужен) — банан, батончик или финики в контейнере.",
            "**Что-то после** — шейк + порошок или готовый йогурт / молоко, если долго не поесте.",
            "**Электролиты** — один пакетик или таблетка на жару или длинную сессию.",
            "**Полотенце + фрукт по желанию** — банально, но забывают, когда бежишь с работы.",
          ],
        },
        {
          t: "p",
          v: "Держите **дубликат набора** на работе или в машине, если тренируетесь после офиса. Система бьёт силу воли.",
        },
      ],
    },
    {
      id: "checklist",
      h: "Если запомнить только три вещи",
      blocks: [
        {
          t: "ul",
          v: [
            "**За 3 часа:** нормальный приём с углеводами и белком, знакомая еда, вода.",
            "**Во время:** сначала вода; углеводы — только если занятие длинное или тяжёлое.",
            "**После:** углеводы + белок в пару часов — и нормальный ужин, если тренировка была серьёзной.",
          ],
        },
        {
          t: "p",
          v: "Экран Meals в WeekFit как раз про такой день — топливо до тренировки, что вы залогировали и что подскажет Коуч, когда восстановление и нагрузка не совпадают с планом. Меньше гаданий, больше прихода готовым.",
        },
      ],
    },
  ],
};
