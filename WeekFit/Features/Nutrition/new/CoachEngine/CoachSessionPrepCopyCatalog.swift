import Foundation

enum CoachSessionPrepCopyCatalog {

    struct BilingualText: Hashable {
        let english: String
        let russian: String
    }

    struct PrepActionCopy {
        let type: CoachSupportActionTypeV3
        let title: BilingualText
        let subtitle: BilingualText
    }

    struct PrepWindowCopy {
        let hero: BilingualText
        let assessment: BilingualText
        let situation: BilingualText
        let primary: PrepActionCopy
        let avoidance: BilingualText
        let extras: [PrepActionCopy]
    }

    struct SessionPrepCopy {
        let mainTraining: BilingualText
        let longTraining: BilingualText
        let fourPlusHours: PrepWindowCopy
        let twoToFourHours: PrepWindowCopy
        let sixtyTo120Minutes: PrepWindowCopy
        let fifteenTo60Minutes: PrepWindowCopy
        let under15Minutes: PrepWindowCopy
    }

    enum Modality {
        case running
        case cycling
        case upperBody
        case lowerBody
        case fullBody
        case strength
        case tennis
        case squash
        case general
    }

    static func copy(for activity: PlannedActivity?, longSession: Bool) -> SessionPrepCopy {
        switch modality(for: activity) {
        case .running:
            return runningCopy(longSession: longSession)
        case .cycling:
            return cyclingCopy(longSession: longSession)
        case .upperBody:
            return upperBodyCopy(longSession: longSession)
        case .lowerBody:
            return lowerBodyCopy(longSession: longSession)
        case .fullBody:
            return fullBodyCopy(longSession: longSession)
        case .strength:
            return strengthCopy(longSession: longSession)
        case .tennis:
            return tennisCopy(longSession: longSession)
        case .squash:
            return squashCopy(longSession: longSession)
        case .general:
            return generalCopy(longSession: longSession)
        }
    }

    static func modality(for activity: PlannedActivity?) -> Modality {
        guard let activity else { return .general }
        if CoachActivityClassification.isWalkLike(activity) ||
            CoachActivityClassification.isHikeLike(activity) ||
            CoachLightRecoveryStableDayPolicy.isLightRecoveryModality(activity) {
            return .general
        }
        let text = "\(activity.title) \(activity.type) \(activity.imageName)".lowercased()

        if text.contains("tennis") { return .tennis }
        if text.contains("squash") { return .squash }
        if text.contains("cycling") || text.contains("cycle") || text.contains("bike") || text.contains("bicycle") ||
            text.contains("ride") || text.contains("biking") {
            return .cycling
        }
        if containsRunningIntent(text) { return .running }
        if text.contains("upper body") || text.contains("upper-body") || text.contains("upperbody") ||
            text.contains("push day") || text.contains("pull day") || text.contains("chest") ||
            text.contains("back day") || text.contains("shoulder") {
            return .upperBody
        }
        if text.contains("lower body") || text.contains("lower-body") || text.contains("lowerbody") ||
            text.contains("leg day") || text.contains("legs") || text.contains("glute") {
            return .lowerBody
        }
        if text.contains("full body") || text.contains("full-body") || text.contains("fullbody") {
            return .fullBody
        }
        if text.contains("strength") || text.contains("gym") || text.contains("lift") ||
            text.contains("weight") || text.contains("workout") {
            return .strength
        }
        return .general
    }

    private static func containsRunningIntent(_ text: String) -> Bool {
        if text.contains("running") || text.contains("jog") || text.contains("jogging") { return true }
        let tokens = text.split { !$0.isLetter }.map(String.init)
        return tokens.contains("run") || tokens.contains("runs") || tokens.contains("ran")
    }

    private static func bi(_ english: String, _ russian: String) -> BilingualText {
        BilingualText(english: english, russian: russian)
    }

    private static func prep(
        _ type: CoachSupportActionTypeV3,
        _ titleEN: String,
        _ subtitleEN: String,
        _ titleRU: String,
        _ subtitleRU: String
    ) -> PrepActionCopy {
        PrepActionCopy(type: type, title: bi(titleEN, titleRU), subtitle: bi(subtitleEN, subtitleRU))
    }

    private static func window(
        hero: BilingualText,
        assessment: BilingualText,
        situation: BilingualText,
        primary: PrepActionCopy,
        avoidance: BilingualText,
        extras: [PrepActionCopy] = []
    ) -> PrepWindowCopy {
        PrepWindowCopy(
            hero: hero,
            assessment: assessment,
            situation: situation,
            primary: primary,
            avoidance: avoidance,
            extras: extras
        )
    }

    private static func runningCopy(longSession: Bool) -> SessionPrepCopy {
        SessionPrepCopy(
            mainTraining: bi("Most of what's left today rides on this run.", "Это главная тренировка, которая у тебя ещё осталась сегодня."),
            longTraining: bi("This is the session that will ask the most of you today.", "Самая длинная и тяжёлая тренировка на сегодня — этот забег."),
            fourPlusHours: window(
                hero: bi("Most of the work is still ahead", "Основная работа ещё не началась"),
                assessment: bi("You've got hours before you need to be sharp — the day should feel calm, not busy.", "До старта ещё много времени — день можно не забивать."),
                situation: bi("What you do now shapes how fresh your legs feel at the start.", "От того, как ты себя ведёшь сейчас, зависит, как ноги будут на старте."),
                primary: prep(.lightFueling, "A meal 2–3 hours out gives your body time to settle", "Heavy legs at mile one usually trace back to rushing this window", "Поесть за 2–3 часа до выхода — еда успеет усвоиться", "Если на первом километре ноги тяжёлые — часто это от еды впритык"),
                avoidance: bi("Nothing useful comes from spending legs early.", "Ноги до забега гонять не нужно."),
                extras: [
                    prep(.hydrateBeforeSession, "A dry mouth before a long run is a signal you've been running behind", "The body usually tells you before the app does", "Если во рту сухо перед длинным забегом — ты уже отстаёшь", "Лучше попить сейчас, а не на старте"),
                    prep(.mobilityPrep, "Everything important should already be ready", "Shoes, route, layer — decided, not debated at the door", "Обувь, маршрут, что на себе — уже решено", "Чтобы на выходе не думать о мелочах")
                ]
            ),
            twoToFourHours: window(
                hero: bi("The run is still a few hours out", "До пробежки ещё несколько часов"),
                assessment: bi("Legs feel fine now — that's exactly what you want to protect.", "Ноги сейчас нормальные — так и оставь."),
                situation: bi("The afternoon is where runners accidentally burn matches.", "Многие в середине дня случайно убивают ноги — лестницы, спурты, лишняя активность."),
                primary: prep(.lightFueling, "How you eat in this window sets the tone for the opening miles", "A settled stomach beats a last-minute scramble", "Как поешь сейчас — так начнёшь первые километры", "Лучше поесть раньше, чем хватать на выходе"),
                avoidance: bi("Extra steps now rarely help the run later.", "Лишняя активность сейчас забегу не поможет."),
                extras: [
                    prep(.hydrateBeforeSession, "Thirst creeping in now is worth noticing", "Not urgent — just a signal to slow down the day", "Если жажда уже есть — не откладывай", "Не срочно, просто лучше не игнорировать"),
                    prep(.mobilityPrep, "Fresh legs are worth protecting", "Five easy minutes of movement is often enough", "Не гоняй ноги без нужды", "Пару минут лёгкой разминки — достаточно")
                ]
            ),
            sixtyTo120Minutes: window(
                hero: bi("About an hour out", "Около часа до старта"),
                assessment: bi("Nerves and restlessness often show up here — that's normal.", "Нервничать и не сидеть на месте — нормально, скоро выход."),
                situation: bi("Small decisions now remove big distractions later.", "Мелочи сейчас решить — меньше отвлекаться потом."),
                primary: prep(.mobilityPrep, "Let the legs wake up without waking up fatigue", "Movement now is about readiness, not effort", "Немного разомни ноги, не до усталости", "Сейчас это про подготовку, а не про работу"),
                avoidance: bi("Fresh legs are worth protecting — stairs and sprints won't prove anything now.", "Лестницы и спурты ничего не докажут — ноги пригодятся на дистанции."),
                extras: [
                    prep(.lightFueling, "Hunger that's real, not boredom", "A light bite only if the stomach is actually asking", "Голод или скука", "Перекус — только если реально голоден"),
                    prep(.mobilityPrep, "Route and shoes settled in your mind", "Fewer decisions at the first step", "Маршрут и обувь уже знаешь", "На первом шаге не решать ничего нового")
                ]
            ),
            fifteenTo60Minutes: window(
                hero: bi("The run is close now", "Пробежка уже скоро"),
                assessment: bi("Energy feels available — that's the trap of starting too fast.", "Энергия есть — и именно на этом часто разгоняются слишком быстро."),
                situation: bi("The goal is to arrive fresh, not busy.", "Постарайся сохранить то, что есть сейчас — без суеты."),
                primary: prep(.controlIntensity, "What you feel in your legs right now is what you're carrying onto the road", "Stillness preserves what pace will need", "Как ноги чувствуются сейчас — с такими и выйдешь", "Покой сейчас — больше сил потом"),
                avoidance: bi("A full meal at this point changes the problem, not solves it.", "Плотно поесть сейчас не решит проблему — только добавит дискомфорт."),
                extras: [
                    prep(.mobilityPrep, "Laces, surface, distance — already decided", "No negotiating with yourself at the curb", "Шнурки, покрытие, дистанция — уже решены", "У подъезда не торговаться с самим собой"),
                    prep(.controlIntensity, "A quiet warm-up often beats a rushed one", "Ten minutes of ease is plenty", "Спокойная разминка лучше суетной", "Десять минут — достаточно")
                ]
            ),
            under15Minutes: window(
                hero: bi("Time to move", "Пора выходить"),
                assessment: bi(
                    longSession ? "A long run rewards patience more than any other session." : "Good sessions usually start slower than expected.",
                    longSession ? "На длинном забеге все сначала стартуют быстрее, чем надо." : "Большинство начинают быстрее, чем планировали."
                ),
                situation: bi("Let the body settle into the work.", "Первые минуты — просто разойтись, не разгоняться."),
                primary: prep(
                    .controlIntensity,
                    "The first minutes should feel easy",
                    "Strong sessions start with patience",
                    "Первые минуты должны быть лёгкими",
                    "Не спеши. Тренировка никуда не денется."
                ),
                avoidance: bi(
                    longSession ? "The opening hour is not the finish — comparing them is a common mistake." : "Winning the first kilometre rarely wins the session.",
                    longSession ? "Первый час — это не финиш." : "Первый километр редко решает всю тренировку."
                ),
                extras: [
                    prep(.steadyHydration, "Dry mouth on the first kilometer is a late fix", "The body usually warned you earlier", "Если пересохло в начале — поздно", "Если жажда уже была — не оставляй до старта")
                ]
            )
        )
    }

    private static func cyclingCopy(longSession: Bool) -> SessionPrepCopy {
        SessionPrepCopy(
            mainTraining: bi("Most of what's left today rides on this ride.", "Это главная тренировка, которая у тебя ещё осталась сегодня."),
            longTraining: bi("This is the session that will ask the most of you today.", "Самая длинная и тяжёлая тренировка на сегодня — эта поездка."),
            fourPlusHours: window(
                hero: bi("Most of the work is still ahead", "Основная работа ещё не началась"),
                assessment: bi(
                    longSession ? "Hours before the pedals matter — the day should feel open, not loaded." : "Still hours out — that's a gift most riders waste.",
                    longSession ? "До поездки ещё несколько часов — день можно не забивать." : "До выезда ещё несколько часов — не трать их на лишнюю активность."
                ),
                situation: bi("What you do now shapes how your legs feel when you clip in.", "От того, как ты себя ведёшь сейчас, зависит, как ноги будут, когда защёлкнешь педали."),
                primary: prep(.lightFueling, "A meal 2–3 hours out gives your body time to settle", "Gut discomfort at hour two usually starts here", "Поесть за 2–3 часа до выезда — еда успеет усвоиться", "Дискомфорт на втором часу часто начинается, если поел впритык"),
                avoidance: bi("Nothing useful comes from rushing now.", "Сейчас спешить нечего."),
                extras: [
                    prep(.hydrateBeforeSession, "Bottles ready before you roll out", "Fixing logistics on the road costs more than time", "Фляги готовы до выезда", "На дороге чинить и искать — хуже, чем дома"),
                    prep(.mobilityPrep, "Tyre pressure and devices — small things that pull focus", "Sorted now means flow later", "Давление в шинах и заряд — мелочи, но отвлекают", "Лучше проверить сейчас")
                ]
            ),
            twoToFourHours: window(
                hero: bi("The ride is still a few hours out", "До поездки ещё несколько часов"),
                assessment: bi("The ride is still later — what you put in now shows up on the road.", "Поездка не скоро — то, что сделаешь сейчас, почувствуешь на дороге."),
                situation: bi("Calm legs and a settled mind beat one more hard effort.", "Спокойные ноги и ясная голова лучше, чем ещё одно жёсткое усилие."),
                primary: prep(.lightFueling, "How you eat in this window sets the tone for the opening miles", "On-bike comfort starts well before you clip in", "Как поешь сейчас — так начнёшь первые километры", "Комфорт на ходу начинается задолго до педалей"),
                avoidance: bi("Extra miles now rarely help the ride later.", "Лишние километры сейчас поездке не помогут."),
                extras: [
                    prep(.hydrateBeforeSession, "If you're already thirsty, the ride will remind you", "Worth noticing, not panicking about", "Если жажда уже есть — поездка напомнит", "Не паниковать, но лучше не откладывать"),
                    prep(.mobilityPrep, "Bike and kit sorted before the door", "Nothing left to fix at departure", "Велосипед и сборы — до двери", "На выезде ничего чинить")
                ]
            ),
            sixtyTo120Minutes: window(
                hero: bi("About an hour out", "Около часа до выезда"),
                assessment: bi("Anticipation often shows up as restlessness — that's the ride approaching.", "Нетерпение — нормально, поездка близко."),
                situation: bi("Small logistics now prevent big interruptions later.", "Мелочи сейчас — меньше прерываний потом."),
                primary: prep(.mobilityPrep, "Everything important should already be ready", "Route, kit, bottles — decided, not debated", "Маршрут, сборы, фляги — уже решено", "Не обсуждать на выезде"),
                avoidance: bi("A heavy stomach this close to rolling out rarely ends well.", "Плотно поесть так близко к выезду — плохая идея."),
                extras: [
                    prep(.lightFueling, "Hunger that's real, not nerves", "A light bite only if the stomach is asking", "Голод или нервы", "Перекус — только если реально голоден"),
                    prep(.mobilityPrep, "On-bike food where it belongs", "Reaching for it mid-ride should feel automatic", "Еда на велосипеде на месте", "Чтобы на ходу не искать")
                ]
            ),
            fifteenTo60Minutes: window(
                hero: bi("The ride is close now", "Поездка уже скоро"),
                assessment: bi("Fresh legs feel eager — that's exactly when riders go too hard early.", "Ноги живые — и именно тогда многие гонят слишком рано."),
                situation: bi("The goal is to arrive fresh, not busy.", "Постарайся сохранить то, что есть сейчас — без суеты."),
                primary: prep(.controlIntensity, "What you feel in your legs now is what you're rolling out with", "Stillness preserves what pace will need", "Как ноги сейчас — с такими и выедешь", "Покой сейчас — больше сил потом"),
                avoidance: bi("A full meal at this point changes the problem, not solves it.", "Плотно поесть сейчас не решит проблему — только добавит дискомфорт."),
                extras: [
                    prep(.mobilityPrep, "Tyres, bottles, route — already in your head", "Fewer surprises at the first corner", "Шины, фляги, маршрут — уже в голове", "Меньше сюрпризов на первом повороте"),
                    prep(.controlIntensity, "A quiet warm-up often beats a rushed one", "Ten minutes of ease is plenty", "Спокойная разминка лучше суетной", "Десять минут — достаточно")
                ]
            ),
            under15Minutes: window(
                hero: bi("Time to roll out", "Время выезжать"),
                assessment: bi(
                    longSession ? "A long ride rewards patience more than any other session." : "Good sessions usually start slower than expected.",
                    longSession ? "На длинной поездке все сначала стартуют быстрее, чем надо." : "Большинство начинают быстрее, чем планировали."
                ),
                situation: bi("Let the body settle into the work.", "Первые минуты — просто крутить, не разгоняться."),
                primary: prep(
                    .controlIntensity,
                    "The first minutes should feel easy",
                    "Working pace can wait — it always does",
                    "Первые минуты должны быть лёгкими",
                    "Рабочий темп подождёт"
                ),
                avoidance: bi(
                    longSession ? "The opening hour is not the finish — comparing them is a common mistake." : "Sprinting from the first corner rarely wins the session.",
                    longSession ? "Первый час — это не финиш." : "Спурт с первого поворота редко выигрывает тренировку."
                ),
                extras: [
                    prep(.steadyHydration, "Dry mouth in the first hour is a late fix", "The body usually warned you earlier", "Если пересохло в начале — поздно", "Если жажда уже была — не оставляй до старта")
                ]
            )
        )
    }

    private static func upperBodyCopy(longSession: Bool) -> SessionPrepCopy {
        strengthFamilyCopy(
            longSession: longSession,
            labelEN: "upper body session",
            labelRU: "верх тела",
            longLabelEN: "long upper body session",
            longLabelRU: "длинная — верх тела",
            closeEN: "Upper body work is close — shoulders should feel awake, not worked.",
            closeRU: "Верх тела скоро — плечи должны быть живыми, не разогретыми до максимума.",
            mobilityEN: "Shoulders and upper back waking up",
            mobilityRU: "Разомни плечи и верх спины",
            under15EN: "First sets with room left in the tank",
            under15RU: "Первые подходы — не на полную"
        )
    }

    private static func lowerBodyCopy(longSession: Bool) -> SessionPrepCopy {
        strengthFamilyCopy(
            longSession: longSession,
            labelEN: "lower body session",
            labelRU: "низ тела",
            longLabelEN: "long lower body session",
            longLabelRU: "длинная — низ тела",
            closeEN: "Lower body work is close — hips should feel ready, not heavy.",
            closeRU: "Низ тела скоро — бёдра должны быть живыми, не забитыми.",
            mobilityEN: "Hips and ankles waking up",
            mobilityRU: "Разомни бёдра и голеностоп",
            under15EN: "First sets with control, not ambition",
            under15RU: "Первые подходы — спокойно, без разгона"
        )
    }

    private static func fullBodyCopy(longSession: Bool) -> SessionPrepCopy {
        strengthFamilyCopy(
            longSession: longSession,
            labelEN: "full body session",
            labelRU: "все тело",
            longLabelEN: "long full body session",
            longLabelRU: "длинная — все тело",
            closeEN: "Full body work is close — warm and ready, not wired.",
            closeRU: "Все тело скоро — разогретый, но не перевозбуждённый.",
            mobilityEN: "Full warm-up — the body notices when you skip",
            mobilityRU: "Полная разминка — если пропустить, потом чувствуется",
            under15EN: "Early sets well inside your limit",
            under15RU: "Ранние подходы — с запасом"
        )
    }

    private static func strengthCopy(longSession: Bool) -> SessionPrepCopy {
        strengthFamilyCopy(
            longSession: longSession,
            labelEN: "strength session",
            labelRU: "силовая",
            longLabelEN: "long strength session",
            longLabelRU: "длинная силовая",
            closeEN: "Strength work is close — technique before load, always.",
            closeRU: "Силовая скоро — сначала техника, потом вес.",
            mobilityEN: "Joints that will work today",
            mobilityRU: "Суставы, которые будут работать",
            under15EN: "Leave 1–2 reps in reserve on early sets",
            under15RU: "В первых подходах оставь 1–2 повтора в запасе"
        )
    }

    private static func strengthFamilyCopy(
        longSession: Bool,
        labelEN: String,
        labelRU: String,
        longLabelEN: String,
        longLabelRU: String,
        closeEN: String,
        closeRU: String,
        mobilityEN: String,
        mobilityRU: String,
        under15EN: String,
        under15RU: String
    ) -> SessionPrepCopy {
        let main = bi("Most of what's left today rides on this \(labelEN).", "Это главная тренировка, которая у тебя ещё осталась сегодня — \(labelRU).")
        let long = bi("This is the session that will ask the most of you today.", "Самая тяжёлая тренировка на сегодня — \(longLabelRU).")

        return SessionPrepCopy(
            mainTraining: main,
            longTraining: long,
            fourPlusHours: window(
                hero: bi("Today is about quality, not proving anything", "Сегодня не надо доказывать — просто сделай нормально"),
                assessment: bi("Hours before the gym — the day should feel calm, not busy.", "До зала ещё несколько часов — день можно не забивать."),
                situation: bi("What you do now shapes how sharp you feel under the bar.", "От того, как ты себя ведёшь сейчас, зависит, как будешь чувствовать себя под штангой."),
                primary: prep(.lightFueling, "A meal 2–3 hours out gives your body time to settle", "Heavy sets on a rushed stomach rarely feel right", "Поесть за 2–3 часа до тренировки — еда успеет усвоиться", "Тяжёлые подходы на несуспевшей еде — плохая идея"),
                avoidance: bi("Pre-fatiguing the muscles you'll need later is a quiet way to lose a session.", "Устать в мышцах до зала — тихий способ испортить тренировку."),
                extras: [
                    prep(.hydrateBeforeSession, "A flat session sometimes starts with a flat morning", "Energy and fluids tend to move together", "Плоская тренировка часто начинается с плоского утра", "Если мало пил — обычно чувствуется"),
                    prep(.controlIntensity, "A lighter day often produces a sharper session", "Focus is finite — spend it in the gym", "Лёгкий день часто даёт лучшую тренировку", "Силы конечны — потрать их в зале")
                ]
            ),
            twoToFourHours: window(
                hero: bi("The session is still a few hours out", "До тренировки ещё несколько часов"),
                assessment: bi("Calm nerves and a settled body beat one more hard effort.", "Спокойные нервы и собранное тело лучше, чем ещё одно жёсткое усилие."),
                situation: bi("Mental rehearsal of the first lifts costs nothing and helps plenty.", "Мысленно пройти первые упражнения — бесплатно и помогает."),
                primary: prep(.lightFueling, "How you eat in this window sets the tone for the opening sets", "A settled stomach beats a last-minute scramble", "Как поешь сейчас — так начнёшь первые подходы", "Лучше поесть раньше, чем хватать перед залом"),
                avoidance: bi("Squeezing in another hard session first rarely helps this one.", "Вписать перед этим ещё одну тяжёлую тренировку — редко помогает."),
                extras: [
                    prep(.hydrateBeforeSession, "Thirst creeping in now is worth noticing", "Not urgent — just a signal to slow down the day", "Если жажда уже есть — не откладывай", "Не срочно, просто лучше не игнорировать"),
                    prep(.mobilityPrep, mobilityEN, "Five to ten easy minutes is often enough", mobilityRU, "Пять–десять лёгких минут часто достаточно")
                ]
            ),
            sixtyTo120Minutes: window(
                hero: bi("About an hour out", "Около часа до старта"),
                assessment: bi("Anticipation often shows up as restlessness — that's the session approaching.", "Нетерпение — нормально, тренировка близко."),
                situation: bi("Everything important should already be ready.", "Если всё собрано и готово — этого достаточно."),
                primary: prep(.mobilityPrep, "Let the joints wake up before the load arrives", "Movement now is about readiness, not effort", "Разомни суставы до нагрузки", "Сейчас это про подготовку, а не про работу"),
                avoidance: bi("Working weight on cold joints is where sessions go sideways.", "Рабочий вес на холодных суставах — частая ошибка."),
                extras: [
                    prep(.hydrateBeforeSession, "A heavy stomach before heavy sets rarely feels right", "Light and settled beats full and rushed", "Полный желудок перед тяжёлыми подходами — плохая идея", "Лёгкое и усвоённое лучше, чем полное и наспех"),
                    prep(.mobilityPrep, "Bars, clips, bench — sorted before you need them", "Fewer interruptions between warm-up and work", "Штанги, замки, скамья — готовы до того, как понадобятся", "Меньше прерываний между разминкой и работой")
                ]
            ),
            fifteenTo60Minutes: window(
                hero: bi("The session is close now", "Тренировка уже скоро"),
                assessment: bi(closeEN, closeRU),
                situation: bi("The goal is to arrive fresh, not busy.", "Постарайся сохранить то, что есть сейчас — без суеты."),
                primary: prep(.mobilityPrep, "Build into the first working sets gradually", "Strong sessions start with patience", "Плавно выходи на первые рабочие подходы", "Не спеши. Тренировка никуда не денется."),
                avoidance: bi("Chasing numbers before the body is ready is how ego steals sessions.", "Гоняться за цифрами, пока тело не готово — знакомая ошибка."),
                extras: [
                    prep(.mobilityPrep, "Setup and equipment — already in your head", "Warm-up finished before the clock hits zero", "Зона и инвентарь — уже в голове", "Разминка завершена до старта")
                ]
            ),
            under15Minutes: window(
                hero: bi("First sets set the tone", "Первые подходы задают тон"),
                assessment: bi("The session starts now — quality in the opening block matters more than load.", "Тренировка начинается — в первом блоке важнее техника, чем вес."),
                situation: bi("The warm-up confirms control — it doesn't prove strength.", "Разминка — проверить контроль, а не выкладываться."),
                primary: prep(.controlIntensity, under15EN, "Add load only when form stays clean", under15RU, "Добавляй вес только когда техника чистая"),
                avoidance: bi("Ego picking the first working weight is a familiar mistake.", "Взять слишком тяжёлый первый рабочий вес — знакомая ошибка."),
                extras: [
                    prep(.steadyHydration, "Between sets, small sips beat big gulps", "The stomach has work to do already", "Между подходами — маленькие глотки, не большие", "Желудку уже есть чем заняться")
                ]
            )
        )
    }

    private static func tennisCopy(longSession: Bool) -> SessionPrepCopy {
        racketCopy(
            longSession: longSession,
            sportEN: "tennis",
            sportRU: "теннис",
            closeEN: "Tennis is close — rhythm should arrive before the first point.",
            closeRU: "Теннис скоро — ритм лучше найти до первого розыгрыша.",
            rallyEN: "the first point",
            rallyRU: "первым розыгрышем"
        )
    }

    private static func squashCopy(longSession: Bool) -> SessionPrepCopy {
        racketCopy(
            longSession: longSession,
            sportEN: "squash",
            sportRU: "сквош",
            closeEN: "Squash is close — breathing should settle before the first rally.",
            closeRU: "Сквош скоро — дыхание лучше успокоить до первого розыгрыша.",
            rallyEN: "the first rally",
            rallyRU: "первым розыгрышем"
        )
    }

    private static func racketCopy(
        longSession: Bool,
        sportEN: String,
        sportRU: String,
        closeEN: String,
        closeRU: String,
        rallyEN: String,
        rallyRU: String
    ) -> SessionPrepCopy {
        SessionPrepCopy(
            mainTraining: bi("Most of what's left today rides on this \(sportEN) session.", "Это главная тренировка, которая у тебя ещё осталась сегодня — \(sportRU)."),
            longTraining: bi("This is the session that will ask the most of you today.", "Самая тяжёлая тренировка на сегодня — \(sportRU)."),
            fourPlusHours: window(
                hero: bi("Fresh legs are worth protecting", "Не гоняй ноги без нужды"),
                assessment: bi("Hours before the court — the day should feel calm, not busy.", "До корта ещё несколько часов — день можно не забивать."),
                situation: bi("Court sports punish legs that were spent earlier in the day.", "На корте ноги быстро устают — если их уже погонял до игры."),
                primary: prep(.lightFueling, "A meal 2–3 hours out gives your body time to settle", "Repeated accelerations need fuel that arrived early", "Поесть за 2–3 часа до корта — еда успеет усвоиться", "На корте много ускорений — лучше поесть раньше"),
                avoidance: bi("Draining legs before the court is a quiet way to lose sharpness.", "Вымотать ноги до игры — плохая идея."),
                extras: [
                    prep(.hydrateBeforeSession, "Court heat finds dehydration fast", "What you feel now shows up under pressure later", "На корте в жару быстро чувствуется, если мало пил", "Лучше не откладывать"),
                    prep(.controlIntensity, "A lighter day often produces a sharper court session", "Spring in the legs is built in quiet hours", "Лёгкий день — ноги живее на корте", "Не трать силы на лишнюю активность")
                ]
            ),
            twoToFourHours: window(
                hero: bi("The court is still a few hours out", "До корта ещё несколько часов"),
                assessment: bi("Calm legs and settled timing beat one more hard effort.", "Спокойные ноги лучше, чем ещё одно жёсткое усилие."),
                situation: bi("Everything important should already be ready.", "Если ракетка, обувь и всё остальное готово — достаточно."),
                primary: prep(.mobilityPrep, "Calves and hips waking up", "Court movement starts from the legs", "Разомни икры и бёдра", "На корте всё начинается с ног"),
                avoidance: bi("Waiting time turned into conditioning is a familiar trap.", "Превратить ожидание в тренировку — знакомая ошибка."),
                extras: [
                    prep(.hydrateBeforeSession, "Thirst creeping in now is worth noticing", "Court sessions rarely forgive running behind", "Если жажда уже есть — не откладывай", "На корте это быстро чувствуется"),
                    prep(.mobilityPrep, "Racket and shoes — grip, strings, court shoes sorted", "Fewer decisions before \(rallyEN)", "Ракетка и обувь готовы", "Меньше решений перед \(rallyRU)")
                ]
            ),
            sixtyTo120Minutes: window(
                hero: bi("About an hour out", "Около часа до игры"),
                assessment: bi("Anticipation often shows up as restlessness — that's the court approaching.", "Нетерпение — нормально, скоро на корт."),
                situation: bi("Small logistics now prevent big distractions later.", "Мелочи сейчас — меньше отвлекаться потом."),
                primary: prep(.mobilityPrep, "Court rhythm builds gradually, not in one burst", "The first minutes are for finding timing", "Ритм на корте — постепенно, не в один рывок", "Первые минуты — просто войти в игру"),
                avoidance: bi("A heavy stomach this close to the court rarely ends well.", "Плотно поесть так близко к корту — плохая идея."),
                extras: [
                    prep(.lightFueling, "Hunger that's real, not nerves", "A light bite only if the stomach is asking", "Голод или нервы", "Перекус — только если реально голоден"),
                    prep(.controlIntensity, "Dynamic warm-up — ease into court rhythm", "Strong sessions start with patience", "Динамическая разминка — без разгона", "Не спеши. Игра никуда не денется.")
                ]
            ),
            fifteenTo60Minutes: window(
                hero: bi("The court is close now", "Корт уже скоро"),
                assessment: bi(closeEN, closeRU),
                situation: bi("The goal is to arrive fresh, not busy.", "Постарайся сохранить то, что есть сейчас — без суеты."),
                primary: prep(.mobilityPrep, "First minutes for rhythm, not intensity", "Let the body settle into court movement", "Первые минуты — для ритма, не для скорости", "Просто войти в движение на корте"),
                avoidance: bi("Spiking intensity before the first rally rarely helps timing.", "Разгоняться до первого розыгрыша — редко помогает."),
                extras: [
                    prep(.mobilityPrep, "Racket and shoes — already in your head", "Warm-up finished before play starts", "Ракетка и обувь — уже в голове", "Разминка до начала игры")
                ]
            ),
            under15Minutes: window(
                hero: bi("Find rhythm early", "Ритм с самого начала"),
                assessment: bi("Play starts soon — first games are for timing, not all-out points.", "Игра скоро — первые геймы для тайминга, не для максимума."),
                situation: bi("Relaxation between movements — acceleration comes selectively.", "Между движениями — расслабление, ускоряйся выборочно."),
                primary: prep(.controlIntensity, "The opening block stays controlled", "Hard rallies chosen selectively, not by default", "Первые розыгрыши — спокойно", "Жёсткие — выборочно, не каждый"),
                avoidance: bi("Competition overriding recovery is how matches get decided early.", "Если азарт перебивает отдых — матч часто решается рано."),
                extras: [
                    prep(.steadyHydration, "Dry mouth under pressure is a late fix", "The body usually warned you earlier", "Если пересохло под давлением — поздно", "Если жажда уже была — не оставляй до старта")
                ]
            )
        )
    }

    private static func generalCopy(longSession: Bool) -> SessionPrepCopy {
        SessionPrepCopy(
            mainTraining: bi("Most of what's left today rides on this session.", "Это главная тренировка, которая у тебя ещё осталась сегодня."),
            longTraining: bi("This is the session that will ask the most of you today.", "Самая тяжёлая тренировка на сегодня — именно эта."),
            fourPlusHours: window(
                hero: bi("Most of the work is still ahead", "Основная работа ещё не началась"),
                assessment: bi("Hours before the start — the day should feel calm, not busy.", "До старта ещё несколько часов — день можно не забивать."),
                situation: bi("What you do now shapes how you feel when it counts.", "От того, как ты себя ведёшь сейчас, зависит, как будешь чувствовать себя на старте."),
                primary: prep(.lightFueling, "A meal 2–3 hours out gives your body time to settle", "Rushed fueling usually shows up as discomfort, not energy", "Поесть за 2–3 часа до старта — еда успеет усвоиться", "Если поел впритык — обычно дискомфорт, а не энергия"),
                avoidance: bi("Adding a second hard session first rarely helps this one.", "Добавить перед этим ещё одну тяжёлую тренировку — редко помогает."),
                extras: [
                    prep(.hydrateBeforeSession, "A flat morning sometimes becomes a flat session", "Energy and fluids tend to move together", "Плоская тренировка часто начинается с плоского утра", "Если мало пил — обычно чувствуется"),
                    prep(.controlIntensity, "A quieter day often produces a sharper session", "Freshness is built in calm hours", "Тихий день часто даёт лучшую тренировку", "Не трать силы на лишнюю активность")
                ]
            ),
            twoToFourHours: window(
                hero: bi("The session is still a few hours out", "До тренировки ещё несколько часов"),
                assessment: bi("Calm body and settled mind beat one more hard effort.", "Спокойное тело и ясная голова лучше, чем ещё одно жёсткое усилие."),
                situation: bi("Nothing useful comes from rushing now.", "Сейчас спешить нечего."),
                primary: prep(.lightFueling, "How you eat in this window sets the tone for the opening", "A settled stomach beats a last-minute scramble", "Как поешь сейчас — так начнёшь", "Лучше поесть раньше, чем хватать перед стартом"),
                avoidance: bi("Waiting time turned into training is a familiar trap.", "Превратить ожидание в тренировку — знакомая ошибка."),
                extras: [
                    prep(.hydrateBeforeSession, "Thirst creeping in now is worth noticing", "Catching up at the start rarely works well", "Если жажда уже есть — не откладывай", "Догонять на старте редко работает"),
                    prep(.mobilityPrep, "Everything important should already be ready", "Fewer decisions when the clock matters", "Если всё готово — достаточно", "Меньше решений, когда важны минуты")
                ]
            ),
            sixtyTo120Minutes: window(
                hero: bi("About an hour out", "Около часа до старта"),
                assessment: bi("Anticipation often shows up as restlessness — that's the session approaching.", "Нетерпение — нормально, тренировка близко."),
                situation: bi("Small logistics now prevent big distractions later.", "Мелочи сейчас — меньше отвлекаться потом."),
                primary: prep(.mobilityPrep, "Everything important should already be ready", "Gear sorted — mind on the work ahead", "Если всё собрано — достаточно", "Голова на работе впереди"),
                avoidance: bi("A heavy stomach this close to the start rarely ends well.", "Плотно поесть так близко к старту — плохая идея."),
                extras: [
                    prep(.lightFueling, "Hunger that's real, not nerves", "A light bite only if the stomach is asking", "Голод или нервы", "Перекус — только если реально голоден"),
                    prep(.mobilityPrep, "Equipment settled before the clock runs down", "No scrambling when it's time to move", "Экипировка готова до старта", "Без суеты, когда пора выходить")
                ]
            ),
            fifteenTo60Minutes: window(
                hero: bi("The session is close now", "Тренировка уже скоро"),
                assessment: bi("Energy feels available — that's the trap of starting too fast.", "Энергия есть — и именно на этом часто разгоняются слишком быстро."),
                situation: bi("The goal is to arrive fresh, not busy.", "Постарайся сохранить то, что есть сейчас — без суеты."),
                primary: prep(.controlIntensity, "What you feel right now is what you're bringing to the start", "Stillness preserves what the session will need", "Как чувствуешь себя сейчас — с таким и выйдешь", "Покой сейчас — больше сил потом"),
                avoidance: bi("A full meal at this point changes the problem, not solves it.", "Плотно поесть сейчас не решит проблему — только добавит дискомфорт."),
                extras: [
                    prep(.mobilityPrep, "Gear and warm-up — already in your head", "Ten to fifteen minutes of ease is plenty", "Сборы и разминка — уже в голове", "Десять–пятнадцать минут — достаточно")
                ]
            ),
            under15Minutes: window(
                hero: bi("Time to move", "Время начинать"),
                assessment: bi("How you open matters more than how hard you go.", "Важнее как стартуешь, а не насколько жёстко."),
                situation: bi("Let the body settle into the work.", "Первые минуты — просто войти в работу, не разгоняться."),
                primary: prep(.controlIntensity, "The first minutes should feel easy", "Strong sessions start with patience", "Первые минуты должны быть лёгкими", "Не спеши. Тренировка никуда не денется."),
                avoidance: bi("A hard opening is hard to undo.", "Жёсткий старт потом трудно откатить."),
                extras: [
                    prep(.steadyHydration, "Dry mouth early on is a late fix", "The body usually warned you earlier", "Если пересохло в начале — поздно", "Если жажда уже была — не оставляй до старта")
                ]
            )
        )
    }
}
