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
            mainTraining: bi("This run is the main training demand left today.", "Эта пробежка — главная нагрузка до конца дня."),
            longTraining: bi("This run is the biggest training stimulus left today.", "Эта пробежка — главная тренировка дня."),
            fourPlusHours: window(
                hero: bi("Save your legs for the run", "Берегите ноги к пробежке"),
                assessment: bi("There is still time — arrive ready, not already tired.", "Время ещё есть — приходите готовым, а не уже уставшим."),
                situation: bi("Plan a carb meal and easy movement; keep hard steps out of the legs.", "Запланируйте углеводный приём и лёгкое движение; не тратьте ноги заранее."),
                primary: prep(.lightFueling, "Eat a carb-focused meal", "Finish it 2-3 hours before you head out", "Сделайте углеводный приём пищи", "За 2-3 часа до выхода"),
                avoidance: bi("Do not add extra hard miles today.", "Не добавляйте сегодня лишние тяжёлые километры."),
                extras: [
                    prep(.hydrateBeforeSession, "Start steady hydration", "Sip through the afternoon", "Начните пить ровно", "Пейте понемногу до вечера"),
                    prep(.controlIntensity, "Keep the day on your feet light", "Save spring for the run", "Держите дневную активность лёгкой", "Сохраните пружину для пробежки")
                ]
            ),
            twoToFourHours: window(
                hero: bi("Ease into run prep", "Спокойно подведитесь к пробежке"),
                assessment: bi("The run is still later — fuel and calm legs matter more than extra work.", "Пробежка ещё впереди — питание и спокойные ноги важнее лишней активности."),
                situation: bi("Close the main meal, sip water, and keep the afternoon quiet.", "Закройте основной приём пищи, пейте воду и сохраните послеобеденное время спокойным."),
                primary: prep(.lightFueling, "Finish fueling for an even start", "Then stay off hard stairs and sprints", "Закройте питание для ровного старта", "Без лестниц и рывков до выхода"),
                avoidance: bi("Do not turn waiting time into a second workout.", "Не превращайте ожидание во вторую тренировку."),
                extras: [
                    prep(.hydrateBeforeSession, "Top up fluids", "Small sips, not a big bottle at once", "Допейте воду", "Маленькими глотками, не залпом"),
                    prep(.mobilityPrep, "Loosen hips and ankles", "Five easy minutes is enough", "Разомните бёдра и голеностоп", "Пять лёгких минут достаточно")
                ]
            ),
            sixtyTo120Minutes: window(
                hero: bi("Light feet, clear plan", "Лёгкие ноги, ясный план"),
                assessment: bi("Under an hour to the run — heavy legs and rush beat fresh pacing.", "До пробежки меньше часа — тяжёлые ноги и суета хуже свежего темпа."),
                situation: bi("Last window for shoes, a small top-up, and a relaxed warm-up plan.", "Последнее окно для обуви, лёгкого перекуса и спокойного плана разминки."),
                primary: prep(.hydrateBeforeSession, "Top up fluids", "Small sips, light stomach", "Допейте воду", "Маленькими глотками, лёгкий желудок"),
                avoidance: bi("Do not test fresh legs on stairs or short sprints.", "Не проверяйте свежие ноги на лестнице или коротких рывках."),
                extras: [
                    prep(.lightFueling, "Use only a light snack", "If hunger is real, not boredom", "Лёгкий перекус", "Только если голод настоящий"),
                    prep(.mobilityPrep, "Check shoes and route", "Remove decisions before the first step", "Проверьте обувь и маршрут", "Уберите решения перед первым шагом")
                ]
            ),
            fifteenTo60Minutes: window(
                hero: bi("Head out soon", "Скоро выход"),
                assessment: bi("The run is close — save energy for the miles ahead.", "Пробежка уже близко — берегите силы на дистанцию."),
                situation: bi("Sip water, lace up, and leave without rushing.", "Допейте воду, обуйтесь и выходите без спешки."),
                primary: prep(.hydrateBeforeSession, "Top up fluids", "Small sips only", "Допейте воду", "Только маленькими глотками"),
                avoidance: bi("Do not try to fix nutrition with a full meal now.", "Не пытайтесь наесться полноценной едой прямо сейчас."),
                extras: [
                    prep(.mobilityPrep, "Check shoes and route", "Laces, surface, and distance settled", "Проверьте обувь и маршрут", "Шнурки, покрытие и дистанция"),
                    prep(.controlIntensity, "Easy warm-up before you leave", "10–15 minutes is enough", "Лёгкая разминка перед выходом", "10–15 минут достаточно")
                ]
            ),
            under15Minutes: window(
                hero: bi("Time to start", "Пора выходить"),
                assessment: bi(
                    longSession ? "Long run ahead — a calm start protects the miles to come." : "Run starts now — a calm start beats a fast one.",
                    longSession ? "Впереди длинная пробежка — спокойный старт сохранит силы на километры впереди." : "Пора выходить — спокойный старт лучше резкого."
                ),
                situation: bi("Route, shoes, and breathing — then start without rush.", "Маршрут, обувь и дыхание — и стартуйте без спешки."),
                primary: prep(
                    .controlIntensity,
                    "Open slower than planned",
                    "You can always speed up later",
                    "Стартуйте медленнее плана",
                    "Ускориться всегда успеете"
                ),
                avoidance: bi(
                    longSession ? "Do not compare the opening hour to your finish pace." : "Do not sprint the first kilometre.",
                    longSession ? "Не сравнивайте первый час с финишным темпом." : "Не рваните первый километр."
                ),
                extras: [
                    prep(.steadyHydration, "Sip if thirsty", "A few mouthfuls is enough", "Если хочется пить — пару глотков", "Полный объём сейчас не обязателен")
                ]
            )
        )
    }

    private static func cyclingCopy(longSession: Bool) -> SessionPrepCopy {
        SessionPrepCopy(
            mainTraining: bi("This ride is the main training demand left today.", "Эта поездка — главная нагрузка до конца дня."),
            longTraining: bi("This ride is the biggest training stimulus left today.", "Эта поездка — главная тренировка дня."),
            fourPlusHours: window(
                hero: bi("Build toward the ride", "Подготовьте выезд"),
                assessment: bi(
                    longSession ? "Still hours out — food and rest matter more than extra miles now." : "Still hours out — food and bottles come first.",
                    longSession ? "До выезда ещё несколько часов — еда и отдых важнее лишних километров." : "До выезда ещё несколько часов — сначала еда и бутылки."
                ),
                situation: bi("Plan a meal, fill bottles, and keep the rest of the day easy.", "Запланируйте еду, наполните бутылки и сохраните день спокойным."),
                primary: prep(.lightFueling, "Plan a carb meal", "Finish it 2-3 hours before you leave", "Запланируйте углеводный приём пищи", "За 2–3 часа до выезда"),
                avoidance: bi("Do not spend your legs on another hard session first.", "Не потратьте ноги на другую тяжёлую тренировку раньше."),
                extras: [
                    prep(.hydrateBeforeSession, "Fill bottles early", "Start sipping well before the ride", "Наполните бутылки заранее", "Начните пить задолго до выезда"),
                    prep(.mobilityPrep, "Check bike and kit", "Tyres, nutrition, and tools ready", "Проверьте велосипед и экипировку", "Шины, питание и инструменты")
                ]
            ),
            twoToFourHours: window(
                hero: bi("Set up the ride", "Соберите выезд"),
                assessment: bi("The ride is still later — on-bike fuel starts with what you eat now.", "Поездка ещё впереди — питание на ходу начинается с того, что съедите сейчас."),
                situation: bi("Pack food, check the bike, and keep the next hours quiet.", "Соберите еду, проверьте велосипед и сохраните ближайшие часы спокойными."),
                primary: prep(.lightFueling, "Finish your pre-ride meal", "Then keep activity low", "Закройте еду перед выездом", "Потом держите активность низкой"),
                avoidance: bi("Do not use waiting time as extra training.", "Не превращайте ожидание в дополнительную тренировку."),
                extras: [
                    prep(.hydrateBeforeSession, "Top up fluids", "Small sips through the next hour", "Допейте воду", "Понемногу в течение часа"),
                    prep(.mobilityPrep, "Check bike and kit", "Nothing left to fix at the door", "Проверьте велосипед и экипировку", "Чтобы у двери ничего не чинить")
                ]
            ),
            sixtyTo120Minutes: window(
                hero: bi("Almost time to go", "Скоро выезд"),
                assessment: bi("About an hour left — gear and fluids beat last-minute rushing.", "До выезда около часа — сборы и вода важнее суеты."),
                situation: bi("Pack on-bike food, check bottles, and stay off hard efforts.", "Положите еду на велосипед, проверьте бутылки и без жёсткой нагрузки."),
                primary: prep(.hydrateBeforeSession, "Check bottles and sip steadily", "Keep your stomach comfortable", "Проверьте бутылки и пейте понемногу", "Чтобы желудок оставался комфортным"),
                avoidance: bi("Do not force a heavy meal this close to the ride.", "Не пытайтесь плотно поесть так близко к выезду."),
                extras: [
                    prep(.lightFueling, "Light snack only", "If you are actually hungry", "Лёгкий перекус", "Только если реально голодно"),
                    prep(.mobilityPrep, "Check route and kit", "Decide it before you leave", "Проверьте маршрут и сборы", "Решите это до выезда")
                ]
            ),
            fifteenTo60Minutes: window(
                hero: bi("Almost time to ride", "Скоро выезд"),
                assessment: bi("The ride is close — save energy for the road ahead.", "Поездка уже близко — берегите силы для дороги."),
                situation: bi("Sip water, check kit, and leave without rushing.", "Сделайте пару глотков, проверьте сборы и выезжайте без спешки."),
                primary: prep(.hydrateBeforeSession, "Top up fluids", "Small sips only", "Допейте воду", "Только маленькими глотками"),
                avoidance: bi("Do not try to fix nutrition with a full meal now.", "Не пытайтесь наесться полноценной едой прямо сейчас."),
                extras: [
                    prep(.mobilityPrep, "Check bike and nutrition", "Tyres, bottles, and food ready", "Проверьте велосипед и питание", "Шины, бутылки и еда"),
                    prep(.controlIntensity, "Easy warm-up before you leave", "10–15 minutes is enough", "Лёгкая разминка перед выездом", "10–15 минут достаточно")
                ]
            ),
            under15Minutes: window(
                hero: bi("Time to head out", "Пора выезжать"),
                assessment: bi(
                    longSession ? "Long ride ahead — a calm start protects the hours to come." : "Ride starts now — a calm start beats a fast one.",
                    longSession ? "Впереди длинная поездка — спокойный старт сохранит силы на часы впереди." : "Пора выезжать — спокойный старт лучше резкого."
                ),
                situation: bi("Bottles, route, and kit — then roll out without rush.", "Бутылки, маршрут и сборы — и выезжайте без спешки."),
                primary: prep(
                    .controlIntensity,
                    "Keep the first 15 minutes easy",
                    "Working pace can wait",
                    "Первый четверть часа — легко",
                    "Рабочий темп подождёт"
                ),
                avoidance: bi(
                    longSession ? "Do not compare the opening hour to your finish pace." : "Do not sprint away from the first corner.",
                    longSession ? "Не сравнивайте первый час с финишным темпом." : "Не рваните с первого поворота."
                ),
                extras: [
                    prep(.steadyHydration, "Sip if thirsty", "A few mouthfuls is enough", "Если хочется пить — пару глотков", "Полную бутылку сейчас не обязательно")
                ]
            )
        )
    }

    private static func upperBodyCopy(longSession: Bool) -> SessionPrepCopy {
        strengthFamilyCopy(
            longSession: longSession,
            labelEN: "upper body session",
            labelRU: "тренировка верха",
            longLabelEN: "long upper body session",
            longLabelRU: "длинная тренировка верха",
            closeEN: "Upper body work is close — warm shoulders, not max out.",
            closeRU: "Тренировка верха уже близко — разогрейте плечи, а не выкладывайтесь в разминке.",
            mobilityEN: "Open shoulders and upper back",
            mobilityRU: "Разомните плечи и верх спины",
            under15EN: "Keep the first sets submaximal",
            under15RU: "Первые подходы держите субмаксимальными"
        )
    }

    private static func lowerBodyCopy(longSession: Bool) -> SessionPrepCopy {
        strengthFamilyCopy(
            longSession: longSession,
            labelEN: "lower body session",
            labelRU: "тренировка низа",
            longLabelEN: "long lower body session",
            longLabelRU: "длинная тренировка низа",
            closeEN: "Lower body work is close — wake up hips, not fatigue.",
            closeRU: "Тренировка низа уже близко — разбудите бёдра, а не усталость.",
            mobilityEN: "Open hips and ankles",
            mobilityRU: "Разомните бёдра и голеностоп",
            under15EN: "Keep the first sets controlled",
            under15RU: "Первые подходы держите под контролем"
        )
    }

    private static func fullBodyCopy(longSession: Bool) -> SessionPrepCopy {
        strengthFamilyCopy(
            longSession: longSession,
            labelEN: "full body session",
            labelRU: "тренировка всего тела",
            longLabelEN: "long full body session",
            longLabelRU: "длинная тренировка всего тела",
            closeEN: "Full body work is close — arrive warm, not wired.",
            closeRU: "Тренировка всего тела уже близко — приходите разогретым, а не перевозбуждённым.",
            mobilityEN: "Run through the full warm-up plan",
            mobilityRU: "Пройдите полный план разминки",
            under15EN: "Keep early sets well inside your limit",
            under15RU: "Ранние подходы держите с запасом"
        )
    }

    private static func strengthCopy(longSession: Bool) -> SessionPrepCopy {
        strengthFamilyCopy(
            longSession: longSession,
            labelEN: "strength session",
            labelRU: "силовая",
            longLabelEN: "long strength session",
            longLabelRU: "длинная силовая",
            closeEN: "Strength work is close — technique first, load second.",
            closeRU: "Силовая уже близко — сначала техника, потом вес.",
            mobilityEN: "Prep the joints you will load",
            mobilityRU: "Подготовьте суставы под нагрузку",
            under15EN: "Leave 1-2 reps in reserve on early sets",
            under15RU: "В ранних подходах оставьте 1-2 повтора в запасе"
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
        let main = bi("This \(labelEN) is the main training demand left today.", "Эта \(labelRU) — главная нагрузка до конца дня.")
        let long = bi("This \(longLabelEN) is the biggest training stimulus left today.", "Эта \(longLabelRU) — главная тренировка дня.")

        return SessionPrepCopy(
            mainTraining: main,
            longTraining: long,
            fourPlusHours: window(
                hero: bi("Protect quality for later", "Сохраните качество на потом"),
                assessment: bi("There is still time — use it to arrive fresh for the lifts.", "Время ещё есть — используйте его, чтобы прийти на подходы свежим."),
                situation: bi("Eat normally, hydrate, and avoid extra fatigue before the gym.", "Ешьте нормально, пейте воду и не копите усталость до зала."),
                primary: prep(.lightFueling, "Plan a solid meal", "Finish it 2-3 hours before training", "Запланируйте полноценный приём пищи", "За 2-3 часа до тренировки"),
                avoidance: bi("Do not pre-fatigue the muscles you need later.", "Не уставьте мышцы, которые понадобятся позже."),
                extras: [
                    prep(.hydrateBeforeSession, "Stay hydrated", "Sip through the day", "Пейте воду", "Понемногу в течение дня"),
                    prep(.controlIntensity, "Keep the day lighter", "Save focus for the session", "Сделайте день легче", "Сохраните концентрацию на тренировку")
                ]
            ),
            twoToFourHours: window(
                hero: bi("Set up the session", "Подведите к тренировке"),
                assessment: bi("The session is still later — food and calm nerves beat extra work.", "Тренировка ещё впереди — еда и спокойные нервы важнее лишней активности."),
                situation: bi("Close the main meal and mentally walk through the first lifts.", "Закройте основной приём пищи и мысленно пройдите первые упражнения."),
                primary: prep(.lightFueling, "Finish fueling", "Then keep the lead-in quiet", "Закройте питание", "Потом сохраните спокойную подводку"),
                avoidance: bi("Do not squeeze in another hard session first.", "Не впишите перед этим ещё одну тяжёлую сессию."),
                extras: [
                    prep(.hydrateBeforeSession, "Top up fluids", "Small sips are enough", "Допейте воду", "Достаточно нескольких глотков"),
                    prep(.mobilityPrep, mobilityEN, "Five to ten easy minutes", mobilityRU, "Пять-десять лёгких минут")
                ]
            ),
            sixtyTo120Minutes: window(
                hero: bi("Get the gym ready", "Подготовьте зал"),
                assessment: bi("Under an hour to start — setup and warm-up beat rushing the first set.", "До старта меньше часа — сборы и разминка лучше спешки в первом подходе."),
                situation: bi("Last window to load bars, check equipment, and plan the warm-up.", "Последнее окно — загрузить штанги, проверить инвентарь и спланировать разминку."),
                primary: prep(.mobilityPrep, "Start mobility now", "Target the joints for today's lifts", "Начните мобильность сейчас", "На суставы сегодняшних упражнений"),
                avoidance: bi("Do not jump into working weight cold.", "Не выходите на рабочий вес без подготовки."),
                extras: [
                    prep(.hydrateBeforeSession, "Sip water", "Stay comfortable, not overfull", "Пейте воду", "Комфортно, без переполнения"),
                    prep(.mobilityPrep, "Check setup and equipment", "Bars, clips, and bench ready", "Проверьте зону и инвентарь", "Штанги, замки и скамья готовы")
                ]
            ),
            fifteenTo60Minutes: window(
                hero: bi("Warm up with intent", "Разминайтесь осознанно"),
                assessment: bi(closeEN, closeRU),
                situation: bi("No big meal now — mobility, equipment, and calm focus.", "Без плотной еды сейчас — мобильность, инвентарь и спокойный фокус."),
                primary: prep(.mobilityPrep, "Start warm-up now", "Build into the first working sets gradually", "Начните разминку сейчас", "Плавно выходите на первые рабочие подходы"),
                avoidance: bi("Do not chase numbers before the body is ready.", "Не гонитесь за цифрами, пока тело не готово."),
                extras: [
                    prep(.mobilityPrep, "Check setup and equipment", "Then finish warm-up before the clock hits zero", "Проверьте зону и инвентарь", "Завершите разминку до старта")
                ]
            ),
            under15Minutes: window(
                hero: bi("First sets set the tone", "Первые подходы задают тон"),
                assessment: bi("The session starts now — quality beats load in the opening block.", "Тренировка начинается — в первом блоке качество важнее веса."),
                situation: bi("Use the warm-up to confirm control, not to prove strength.", "Используйте разминку для проверки контроля, а не силы."),
                primary: prep(.controlIntensity, under15EN, "Build load only if form stays clean", under15RU, "Добавляйте вес только при чистой технике"),
                avoidance: bi("Do not let ego pick the first working weight.", "Не позволяйте эго выбрать первый рабочий вес."),
                extras: [
                    prep(.steadyHydration, "Sip if needed", "No big drinks between sets yet", "Глоток при необходимости", "Без больших порций между подходами")
                ]
            )
        )
    }

    private static func tennisCopy(longSession: Bool) -> SessionPrepCopy {
        racketCopy(
            longSession: longSession,
            sportEN: "tennis",
            sportRU: "теннис",
            closeEN: "Tennis is close — find rhythm before the first point.",
            closeRU: "Теннис уже близко — найдите ритм до первого розыгрыша.",
            rallyEN: "the first point",
            rallyRU: "первым розыгрышем"
        )
    }

    private static func squashCopy(longSession: Bool) -> SessionPrepCopy {
        racketCopy(
            longSession: longSession,
            sportEN: "squash",
            sportRU: "сквош",
            closeEN: "Squash is close — control breathing before the first rally.",
            closeRU: "Сквош уже близко — настройте дыхание до первого розыгрыша.",
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
            mainTraining: bi("This \(sportEN) session is the main training demand left today.", "Этот \(sportRU) — главная нагрузка до конца дня."),
            longTraining: bi("This \(sportEN) session is the biggest training stimulus left today.", "Этот \(sportRU) — главная тренировка дня."),
            fourPlusHours: window(
                hero: bi("Save legs for the court", "Берегите ноги к корту"),
                assessment: bi("There is still time — arrive fresh for repeated accelerations.", "Время ещё есть — приходите свежим под повторные ускорения."),
                situation: bi("Eat, hydrate, and keep the day from becoming extra leg work.", "Поезжайте, пейте и не превращайте день в лишнюю нагрузку на ноги."),
                primary: prep(.lightFueling, "Plan a balanced meal", "Finish it 2-3 hours before the court", "Запланируйте сбалансированный приём пищи", "За 2-3 часа до корта"),
                avoidance: bi("Do not drain legs before the match.", "Не опустошите ноги до игры."),
                extras: [
                    prep(.hydrateBeforeSession, "Start steady hydration", "Court heat adds demand later", "Начните пить ровно", "Жара на корте добавит нагрузку"),
                    prep(.controlIntensity, "Keep the lead-in light", "Save spring for the court", "Сделайте подводку лёгкой", "Сохраните пружину для корта")
                ]
            ),
            twoToFourHours: window(
                hero: bi("Set up for the court", "Подготовьтесь к корту"),
                assessment: bi("The session is still later — timing and calm legs matter now.", "Игра ещё впереди — сейчас важны тайминг и спокойные ноги."),
                situation: bi("Pack racket gear, sip water, and avoid unnecessary hard movement.", "Соберите экипировку, пейте воду и без лишней жёсткой активности."),
                primary: prep(.hydrateBeforeSession, "Finish hydration", "Then keep activity low", "Доведите воду до нормы", "Потом держите активность низкой"),
                avoidance: bi("Do not turn waiting time into conditioning.", "Не превращайте ожидание в кондиционирование."),
                extras: [
                    prep(.mobilityPrep, "Loosen calves and hips", "Court movement starts from the legs", "Разомните икры и бёдра", "Движение на корте начинается с ног"),
                    prep(.mobilityPrep, "Check racket and shoes", "Grip, strings, and court shoes ready", "Проверьте ракетку и обувь", "Хват, струны и кроссовки готовы")
                ]
            ),
            sixtyTo120Minutes: window(
                hero: bi("Court prep mode", "Режим подготовки к корту"),
                assessment: bi("Under an hour to play — gear, fluids, and a calm warm-up beat rushing.", "До игры меньше часа — экипировка, вода и спокойная разминка лучше суеты."),
                situation: bi("Last window for racket check, shoes, and light movement prep.", "Последнее окно — проверить ракетку, обувь и лёгкую разминку."),
                primary: prep(.hydrateBeforeSession, "Top up fluids", "Small sips, comfortable stomach", "Допейте воду", "Маленькими глотками, лёгкий желудок"),
                avoidance: bi("Do not force a heavy meal this close to the court.", "Не пытайтесь плотно поесть так близко к корту."),
                extras: [
                    prep(.mobilityPrep, "Check racket and shoes", "Remove decisions before \(rallyEN)", "Проверьте ракетку и обувь", "Уберите решения перед \(rallyRU)"),
                    prep(.controlIntensity, "Start dynamic warm-up", "Build court rhythm gradually", "Начните динамическую разминку", "Постепенно входите в кортовый ритм")
                ]
            ),
            fifteenTo60Minutes: window(
                hero: bi("Step onto court calm", "Выходите на корт спокойно"),
                assessment: bi(closeEN, closeRU),
                situation: bi("Sip water, check strings and shoes, and keep the warm-up controlled.", "Сделайте глоток воды, проверьте струны и обувь, разминку держите под контролем."),
                primary: prep(.mobilityPrep, "Start warm-up now", "Use the first minutes to find rhythm", "Начните разминку сейчас", "Первые минуты — для поиска ритма"),
                avoidance: bi("Do not spike intensity before the first rally.", "Не поднимайте интенсивность до первого розыгрыша."),
                extras: [
                    prep(.mobilityPrep, "Check racket and shoes", "Then finish warm-up before play starts", "Проверьте ракетку и обувь", "Завершите разминку до начала игры")
                ]
            ),
            under15Minutes: window(
                hero: bi("Find rhythm early", "Найдите ритм сразу"),
                assessment: bi("Play starts soon — first games are for timing, not all-out points.", "Игра скоро начнётся — первые геймы для тайминга, а не для максимума."),
                situation: bi("Stay relaxed between movements and let the body accelerate selectively.", "Оставайтесь расслабленным между движениями и ускоряйтесь выборочно."),
                primary: prep(.controlIntensity, "Keep the opening block controlled", "Choose the hard rallies selectively", "Первый блок держите под контролем", "Выбирайте тяжёлые розыгрыши"),
                avoidance: bi("Do not let competition override recovery.", "Не позволяйте азарту перебить восстановление."),
                extras: [
                    prep(.steadyHydration, "Take a few sips", "No big drinks right before play", "Сделайте несколько глотков", "Без больших порций прямо перед игрой")
                ]
            )
        )
    }

    private static func generalCopy(longSession: Bool) -> SessionPrepCopy {
        SessionPrepCopy(
            mainTraining: bi("This session is the main training demand left today.", "Эта сессия — главная нагрузка до конца дня."),
            longTraining: bi("This session is the biggest training stimulus left today.", "Эта сессия — главная тренировка дня."),
            fourPlusHours: window(
                hero: bi("Build toward the session", "Подведите к тренировке"),
                assessment: bi("There is still time — use it to arrive ready.", "Время ещё есть — используйте его, чтобы прийти готовым."),
                situation: bi("Plan food, hydration, and a quiet lead-in.", "Запланируйте еду, воду и спокойную подводку."),
                primary: prep(.lightFueling, "Plan the main meal", "Finish it 2-3 hours before the session", "Запланируйте основной приём пищи", "За 2-3 часа до старта"),
                avoidance: bi("Do not add a second hard session first.", "Не добавляйте перед этим вторую тяжёлую сессию."),
                extras: [
                    prep(.hydrateBeforeSession, "Start steady hydration", "Sip before the final hour", "Начните пить ровно", "Пейте до последнего часа"),
                    prep(.controlIntensity, "Keep the lead-in quiet", "Save freshness for the work ahead", "Сделайте подводку спокойной", "Сохраните свежесть к нагрузке")
                ]
            ),
            twoToFourHours: window(
                hero: bi("Set up the session", "Соберите подготовку"),
                assessment: bi("The session is still later today — the lead-in matters now.", "Тренировка ещё позже сегодня — сейчас важна спокойная подводка."),
                situation: bi("Close fueling, hydrate, and keep unnecessary movement low.", "Закройте питание, пейте воду и сократите лишнее движение."),
                primary: prep(.lightFueling, "Finish fueling for a controlled start", "Then keep activity low", "Закройте питание для спокойного старта", "Потом держите активность низкой"),
                avoidance: bi("Do not turn waiting time into extra training.", "Не делайте из ожидания дополнительную тренировку."),
                extras: [
                    prep(.hydrateBeforeSession, "Finish steady hydration", "Avoid catching up at the start", "Доведите воду до нормы", "Не догоняйте её на старте"),
                    prep(.mobilityPrep, "Check equipment", "Remove decisions before the start", "Проверьте экипировку", "Уберите решения перед стартом")
                ]
            ),
            sixtyTo120Minutes: window(
                hero: bi("Shift into prep mode", "Переходите к подготовке"),
                assessment: bi("About an hour to start — keep the prep simple.", "До старта около часа — не усложняйте подготовку."),
                situation: bi("Last good window for gear, fluids, and a light top-up.", "Последнее удобное окно — сборы, вода и лёгкий перекус."),
                primary: prep(.hydrateBeforeSession, "Top up fluids", "Small sips, comfortable stomach", "Допейте воду", "Маленькими глотками, лёгкий желудок"),
                avoidance: bi("Do not force a full meal this close to the start.", "Не пытайтесь плотно поесть так близко к старту."),
                extras: [
                    prep(.lightFueling, "Use only a light top-up", "If you are actually hungry", "Лёгкий перекус", "Если реально голодно"),
                    prep(.mobilityPrep, "Check equipment", "Everything ready before the clock runs down", "Проверьте экипировку", "Всё готово до старта")
                ]
            ),
            fifteenTo60Minutes: window(
                hero: bi("Arrive ready", "Выйдите на старт готовым"),
                assessment: bi("The session is close — keep the prep simple.", "Тренировка уже близко — не усложняйте подготовку."),
                situation: bi("The meal window has passed; sip, check gear, and stay calm.", "Окно для еды прошло — допейте, проверьте сборы и оставайтесь спокойным."),
                primary: prep(.hydrateBeforeSession, "Finish final hydration", "Small sips only", "Допейте воду перед стартом", "Только маленькими глотками"),
                avoidance: bi("Do not fix fueling with a full meal now.", "Не пытайтесь наесться полноценной едой прямо сейчас."),
                extras: [
                    prep(.mobilityPrep, "Check equipment", "Then start warm-up 10-15 minutes before the start", "Проверьте экипировку", "Затем разминка за 10–15 минут до старта")
                ]
            ),
            under15Minutes: window(
                hero: bi("Time to start", "Пора начинать"),
                assessment: bi("Session starts now — how you open matters more than how hard you go.", "Тренировка начинается — важнее как вы стартуете, а не насколько жёстко."),
                situation: bi("Gear checked, mind calm — then begin without rush.", "Сборы проверены, голова спокойна — начинайте без спешки."),
                primary: prep(.controlIntensity, "First 10–15 minutes easy", "Build only when the body feels ready", "Первые 10–15 минут легко", "Ускоряйтесь, когда тело готово"),
                avoidance: bi("A hard opening is hard to undo.", "Жёсткий старт потом трудно откатить."),
                extras: [
                    prep(.steadyHydration, "Sip if thirsty", "A few mouthfuls is enough", "Если хочется пить — пару глотков", "Полный объём сейчас не обязателен")
                ]
            )
        )
    }
}
