import Foundation

/// Enriches preparation copy with activity-specific and physiological context for human-coach tone.
enum CoachSessionPrepNarrativeBuilder {

    enum PrepTimeWindow {
        case longLead
        case imminent
    }

    struct EnrichedWindow {
        let hero: CoachSessionPrepCopyCatalog.BilingualText
        let assessment: CoachSessionPrepCopyCatalog.BilingualText
        let situation: CoachSessionPrepCopyCatalog.BilingualText
        let primary: CoachSessionPrepCopyCatalog.PrepActionCopy
        let avoidance: CoachSessionPrepCopyCatalog.BilingualText
        let extras: [CoachSessionPrepCopyCatalog.PrepActionCopy]
    }

    struct Context {
        let longSession: Bool
        let durationMinutes: Int
        let minutesUntil: Int?
        let recoveryPercent: Int
        let sleepHours: Double
        let hasHighYesterdayLoad: Bool
        let completedSeriousTrainingToday: Bool
        let caloriesBurnedSoFar: Double
        let primaryLimiter: CoachLimiter
        let fuelLimited: Bool
        let hydrationLimited: Bool
        let recoveryLimited: Bool
        let sleepLimited: Bool
    }

    static func enrich(
        activity: PlannedActivity?,
        context: Context,
        window: CoachSessionPrepCopyCatalog.PrepWindowCopy,
        baseCopy: CoachSessionPrepCopyCatalog.SessionPrepCopy,
        timeWindow: PrepTimeWindow
    ) -> EnrichedWindow {
        let modality = CoachSessionPrepCopyCatalog.modality(for: activity)
        let isImminent = timeWindow == .imminent
        let profile = physiologyProfile(context)

        let hero = isImminent
            ? window.hero
            : personalizedHero(
                activity: activity,
                modality: modality,
                longSession: context.longSession,
                durationMinutes: context.durationMinutes,
                window: window,
                baseCopy: baseCopy
            )

        let assessment: CoachSessionPrepCopyCatalog.BilingualText
        if shouldUsePhysiologicalAssessment(context: context, profile: profile, isImminent: isImminent) {
            assessment = physiologicalAssessment(
                context: context,
                profile: profile,
                modality: modality,
                window: window,
                compact: isImminent
            )
        } else {
            assessment = window.assessment
        }

        let situation = physiologicalSituation(
            context: context,
            profile: profile,
            modality: modality,
            window: window,
            compact: isImminent
        )

        let extras = personalizedExtras(
            modality: modality,
            longSession: context.longSession,
            durationMinutes: context.durationMinutes,
            timeWindow: timeWindow,
            window: window
        )

        return EnrichedWindow(
            hero: hero,
            assessment: assessment,
            situation: situation,
            primary: window.primary,
            avoidance: isImminent
                ? window.avoidance
                : personalizedAvoidance(
                    modality: modality,
                    profile: profile,
                    window: window
                ),
            extras: extras
        )
    }

    // MARK: - Physiology

    private struct PhysiologyProfile {
        let recovery: RecoveryBand
        let sleep: SleepBand
        let dayLoad: DayLoadBand

        enum RecoveryBand {
            case strong
            case moderate
            case limited
            case unknown
        }

        enum SleepBand {
            case strong
            case moderate
            case short
            case unknown
        }

        enum DayLoadBand {
            case fresh
            case highYesterday
            case trainedToday
            case heavyDay
        }
    }

    private static func physiologyProfile(_ context: Context) -> PhysiologyProfile {
        let recovery: PhysiologyProfile.RecoveryBand = {
            if context.recoveryLimited || context.recoveryPercent > 0 && context.recoveryPercent < 65 {
                return .limited
            }
            if context.recoveryPercent >= 80 {
                return .strong
            }
            if context.recoveryPercent >= 70 {
                return .moderate
            }
            if context.recoveryPercent > 0 {
                return .limited
            }
            return .unknown
        }()

        let sleep: PhysiologyProfile.SleepBand = {
            if context.sleepLimited || (context.sleepHours > 0 && context.sleepHours < 6.0) {
                return .short
            }
            if context.sleepHours >= 7.5 {
                return .strong
            }
            if context.sleepHours >= 6.5 {
                return .moderate
            }
            if context.sleepHours > 0 {
                return .short
            }
            return .unknown
        }()

        let dayLoad: PhysiologyProfile.DayLoadBand = {
            if context.completedSeriousTrainingToday {
                return .trainedToday
            }
            if context.caloriesBurnedSoFar >= 700 {
                return .heavyDay
            }
            if context.hasHighYesterdayLoad {
                return .highYesterday
            }
            return .fresh
        }()

        return PhysiologyProfile(recovery: recovery, sleep: sleep, dayLoad: dayLoad)
    }

    private static func shouldUsePhysiologicalAssessment(
        context: Context,
        profile: PhysiologyProfile,
        isImminent: Bool
    ) -> Bool {
        if !isImminent { return true }
        return context.fuelLimited ||
            context.hydrationLimited ||
            context.recoveryLimited ||
            context.sleepLimited ||
            profile.dayLoad == .highYesterday ||
            profile.dayLoad == .trainedToday ||
            context.longSession
    }

    private static func physiologicalAssessment(
        context: Context,
        profile: PhysiologyProfile,
        modality: CoachSessionPrepCopyCatalog.Modality,
        window: CoachSessionPrepCopyCatalog.PrepWindowCopy,
        compact: Bool
    ) -> CoachSessionPrepCopyCatalog.BilingualText {
        let opener = physiologicalOpener(profile: profile, context: context, modality: modality, compact: compact)
        let focus = prepFocus(
            profile: profile,
            context: context,
            modality: modality,
            compact: compact
        )
        return bi("\(opener.english) \(focus.english)", "\(opener.russian) \(focus.russian)")
    }

    private static func physiologicalOpener(
        profile: PhysiologyProfile,
        context: Context,
        modality: CoachSessionPrepCopyCatalog.Modality,
        compact: Bool
    ) -> CoachSessionPrepCopyCatalog.BilingualText {
        if profile.dayLoad == .highYesterday &&
            (profile.recovery == .limited || profile.recovery == .moderate) {
            return enduranceOpening(
                modality: modality,
                english: "After yesterday's load, the body is still rebuilding.",
                russian: "После вчерашней нагрузки организм ещё восстанавливается.",
                compactEnglish: "Yesterday's load is still in the legs.",
                compactRussian: "Вчерашняя нагрузка ещё чувствуется.",
                compact: compact
            )
        }

        if profile.sleep == .short && profile.recovery == .limited {
            return bi(
                compact
                    ? "Short sleep and limited recovery set today's ceiling."
                    : "Sleep was short and recovery is still catching up.",
                compact
                    ? "Короткий сон и ограниченное восстановление снижают потолок дня."
                    : "Сон был коротким, и восстановление ещё не полностью вернулось."
            )
        }

        if profile.sleep == .short {
            return bi(
                compact ? "Last night was short — keep today's effort measured." : "Last night was short, so today's ceiling is a little lower.",
                compact ? "Прошлая ночь была короткой — держите день в меру." : "Прошлая ночь была короткой — сегодня потолок чуть ниже."
            )
        }

        if profile.dayLoad == .trainedToday {
            return bi(
                compact ? "You already have meaningful work in the legs today." : "There is already meaningful training stress in today's legs.",
                compact ? "Сегодня в ногах уже есть заметная работа." : "Сегодня в ногах уже есть заметная тренировочная нагрузка."
            )
        }

        if profile.recovery == .limited {
            return bi(
                compact ? "Recovery is still limited today." : "Recovery is still limited, so the useful move is staying conservative early.",
                compact ? "Восстановление сегодня ещё ограничено." : "Восстановление пока ограничено — полезнее начать спокойно."
            )
        }

        if profile.sleep == .strong && profile.recovery == .strong {
            return bi(
                compact ? "Sleep and recovery are in a good place." : "Sleep and recovery are in a good place today.",
                compact ? "Сон и восстановление на хорошем уровне." : "Сон и восстановление сегодня на хорошем уровне."
            )
        }

        if profile.recovery == .strong {
            return bi(
                compact ? "Recovery supports the full plan today." : "Recovery is solid enough to carry the full planned work today.",
                compact ? "Восстановление позволяет идти по плану." : "Сегодня восстановление позволяет выполнить полный объём работы."
            )
        }

        if profile.sleep == .strong {
            return bi(
                "Sleep supports the session ahead.",
                "Сон поддерживает предстоящую сессию."
            )
        }

        return bi(
            compact ? "The day is manageable if you prepare calmly." : "The day is manageable — calm preparation matters more than rushing.",
            compact ? "День посильный, если готовиться спокойно." : "День посильный — спокойная подготовка важнее спешки."
        )
    }

    private static func prepFocus(
        profile: PhysiologyProfile,
        context: Context,
        modality: CoachSessionPrepCopyCatalog.Modality,
        compact: Bool
    ) -> CoachSessionPrepCopyCatalog.BilingualText {
        let sessionEN = sessionDescriptorEN(modality: modality, longSession: context.longSession)
        let sessionRU = sessionDescriptorRU(modality: modality, longSession: context.longSession)

        if context.fuelLimited && context.hydrationLimited {
            return bi(
                compact
                    ? "Build food and fluids before \(sessionEN) starts."
                    : "The main job now is building food and fluid reserves before \(sessionEN) starts.",
                compact
                    ? "Наберите еду и воду до старта \(sessionRU)."
                    : "Сейчас главное — обеспечить запас еды и воды до старта \(sessionRU)."
            )
        }

        if context.fuelLimited {
            if context.longSession {
                return bi(
                    compact
                        ? "Build an energy reserve before the long \(sessionEN) starts."
                        : "For the long \(sessionEN) ahead, the main job now is building an energy reserve before start.",
                    compact
                        ? "Наберите запас энергии до длинной \(sessionRU)."
                        : "Для длительной \(sessionRU) сейчас важнее всего обеспечить достаточный запас энергии до старта."
                )
            }
            return bi(
                compact
                    ? "Eat steadily before \(sessionEN) — it will make the opening easier."
                    : "Steady fueling before \(sessionEN) will make the opening feel easier.",
                compact
                    ? "Питайтесь до старта — так начало будет легче."
                    : "Спокойное питание до \(sessionRU) сделает начало легче."
            )
        }

        if context.hydrationLimited {
            return bi(
                compact
                    ? "Bring fluids online before \(sessionEN) starts."
                    : "The useful move now is bringing fluids online before \(sessionEN) starts.",
                compact
                    ? "Начните пить до старта \(sessionRU)."
                    : "Сейчас полезно наладить питьевой режим до старта \(sessionRU)."
            )
        }

        if profile.dayLoad == .highYesterday && isEndurance(modality) {
            return bi(
                compact
                    ? "Open at a comfortable pace and adjust by feel."
                    : "So keep the first part at a comfortable pace and adjust from there.",
                compact
                    ? "Стартуйте в комфортном темпе и ориентируйтесь на ощущения."
                    : "Поэтому первые километры лучше провести в комфортном темпе."
            )
        }

        if profile.dayLoad == .highYesterday || profile.recovery == .limited {
            return enduranceOpening(
                modality: modality,
                english: "Keep the opening conservative and let the body settle in.",
                russian: "Начните спокойно и дайте организму войти в работу.",
                compactEnglish: "Open conservatively and adjust by feel.",
                compactRussian: "Стартуйте спокойно и ориентируйтесь на ощущения.",
                compact: compact
            )
        }

        if context.longSession && profile.recovery == .strong {
            return bi(
                compact
                    ? "Arrive rested and fueled for the long \(sessionEN)."
                    : "The long \(sessionEN) is the main work left — arrive rested and fueled.",
                compact
                    ? "Приходите отдохнувшим и сытым на длинную \(sessionRU)."
                    : "Длинная \(sessionRU) — главная работа дня; приходите отдохнувшим и с запасом энергии."
            )
        }

        if profile.sleep == .strong && profile.recovery == .strong &&
            (context.longSession || context.durationMinutes >= 75) {
            return bi(
                compact
                    ? "Prepare fuel and hydration for the long work ahead."
                    : "The main job now is preparing fuel and hydration for the long work ahead.",
                compact
                    ? "Подготовьте питание и воду к длительной работе."
                    : "Основная задача сейчас — подготовить питание и гидратацию для длительной работы."
            )
        }

        if context.longSession {
            return bi(
                compact ? "Keep the lead-in quiet before the long \(sessionEN)." : "Keep the lead-in quiet and protect freshness for the long \(sessionEN).",
                compact ? "Сохраните спокойную подводку к длинной \(sessionRU)." : "Держите подводку спокойной и сохраните свежесть к длинной \(sessionRU)."
            )
        }

        return bi(
            compact ? "Arrive ready, not already spent." : "The useful move is arriving ready, not already spent.",
            compact ? "Приходите готовым, а не уже уставшим." : "Полезнее прийти готовым, а не уже уставшим."
        )
    }

    private static func physiologicalSituation(
        context: Context,
        profile: PhysiologyProfile,
        modality: CoachSessionPrepCopyCatalog.Modality,
        window: CoachSessionPrepCopyCatalog.PrepWindowCopy,
        compact: Bool
    ) -> CoachSessionPrepCopyCatalog.BilingualText {
        if context.fuelLimited && context.hydrationLimited {
            return bi(
                "Close food and fluids calmly, then keep the rest of the day easy.",
                "Спокойно закройте еду и воду, затем сохраните день лёгким."
            )
        }

        if context.fuelLimited {
            return bi(
                compact
                    ? "Eat on time so energy is available when you start."
                    : "Eat on time now so energy is available when the session starts.",
                compact
                    ? "Питайтесь вовремя, чтобы к старту была энергия."
                    : "Питайтесь сейчас вовремя, чтобы к старту была энергия."
            )
        }

        if context.hydrationLimited {
            return bi(
                "Sip steadily through the next hour — do not wait until the start line.",
                "Пейте понемногу в ближайший час — не откладывайте до старта."
            )
        }

        if profile.dayLoad == .highYesterday && isEndurance(modality) {
            return bi(
                "Keep the first part comfortable — intensity can come later if the body responds.",
                "Первую часть держите комфортной — интенсивность добавите позже, если тело ответит."
            )
        }

        return window.situation
    }

    // MARK: - Hero

    private static func personalizedHero(
        activity: PlannedActivity?,
        modality: CoachSessionPrepCopyCatalog.Modality,
        longSession: Bool,
        durationMinutes: Int,
        window: CoachSessionPrepCopyCatalog.PrepWindowCopy,
        baseCopy: CoachSessionPrepCopyCatalog.SessionPrepCopy
    ) -> CoachSessionPrepCopyCatalog.BilingualText {
        switch modality {
        case .cycling where longSession && durationMinutes >= 120:
            return bi("Long ride is the main work today", "Длинная велосессия — главная тренировка дня")
        case .running where longSession:
            return bi("Long run is the main work today", "Длинная пробежка — главная тренировка дня")
        case .upperBody, .lowerBody, .fullBody, .strength where longSession:
            return bi("Strength session is the focus today", "Силовая сегодня — в центре плана")
        case .tennis:
            return bi("Tennis is the main session today", "Теннис сегодня — главная сессия")
        case .squash:
            return bi("Squash is the main session today", "Сквош сегодня — главная сессия")
        default:
            if longSession, let duration = CoachNaturalTimePhrase.sessionDuration(minutes: durationMinutes) {
                return bi(
                    "Today's key session is \(duration.english)",
                    "Ключевая сессия сегодня — \(duration.russian)"
                )
            }
            return window.hero
        }
    }

    // MARK: - Avoidance & actions

    private static func personalizedAvoidance(
        modality: CoachSessionPrepCopyCatalog.Modality,
        profile: PhysiologyProfile,
        window: CoachSessionPrepCopyCatalog.PrepWindowCopy
    ) -> CoachSessionPrepCopyCatalog.BilingualText {
        if profile.dayLoad == .highYesterday || profile.recovery == .limited {
            return enduranceOpening(
                modality: modality,
                english: "Do not spend freshness before the body is ready to work.",
                russian: "Не тратьте свежесть, пока организм не готов работать.",
                compactEnglish: "Do not spend freshness too early.",
                compactRussian: "Не тратьте свежесть слишком рано.",
                compact: false
            )
        }

        switch modality {
        case .cycling, .running:
            return bi(
                "Save your legs for the main session.",
                "Сохраните силы для основной тренировки."
            )
        case .upperBody, .lowerBody, .fullBody, .strength:
            return bi(
                "Do not add extra hard work before the lifts.",
                "Не добавляйте лишнюю нагрузку до тренировки."
            )
        case .tennis, .squash:
            return bi(
                "Keep the lead-in light — the court work is still ahead.",
                "Держите подводку лёгкой — основная работа ещё впереди."
            )
        case .general:
            return window.avoidance
        }
    }

    private static func personalizedExtras(
        modality: CoachSessionPrepCopyCatalog.Modality,
        longSession: Bool,
        durationMinutes: Int,
        timeWindow: PrepTimeWindow,
        window: CoachSessionPrepCopyCatalog.PrepWindowCopy
    ) -> [CoachSessionPrepCopyCatalog.PrepActionCopy] {
        guard timeWindow == .longLead else {
            return window.extras
        }

        switch modality {
        case .cycling where longSession || durationMinutes >= 90:
            return [
                prep(
                    .hydrateBeforeSession,
                    "Prepare bottles or mix for the first hours",
                    "Have fluids ready before you roll out",
                    "Подготовьте воду или изотоник на первые часы",
                    "Наполните фляги до выезда"
                ),
                prep(
                    .mobilityPrep,
                    "Check tyre pressure and device charge",
                    "Remove small surprises on the road",
                    "Проверьте давление в шинах и заряд устройств",
                    "Мелочи на дороге не должны отвлекать"
                )
            ]

        case .running where longSession || durationMinutes >= 75:
            return [
                prep(
                    .hydrateBeforeSession,
                    "Drink 300–500 ml in the hour before you leave",
                    "Small sips, comfortable stomach",
                    "Выпейте 300–500 мл воды за час до старта",
                    "Маленькими глотками, без переполнения"
                ),
                prep(
                    .mobilityPrep,
                    "Prepare gear for the conditions",
                    "Shoes, layer, and route decided early",
                    "Подготовьте экипировку под погоду",
                    "Обувь, слой и маршрут — заранее"
                )
            ]

        case .upperBody, .lowerBody, .fullBody, .strength:
            return [
                prep(
                    .mobilityPrep,
                    "Set working weights and equipment",
                    "Bars, clips, and bench ready before you start",
                    "Подготовьте рабочий вес и оборудование",
                    "Штанги, замки и инвентарь — до первого подхода"
                ),
                prep(
                    .lightFueling,
                    "Plan protein after the session",
                    "Recovery starts when the last set ends",
                    "Запланируйте белок после тренировки",
                    "Восстановление начинается с последнего подхода"
                )
            ]

        default:
            return window.extras
        }
    }

    // MARK: - Labels

    private static func sessionDescriptorEN(
        modality: CoachSessionPrepCopyCatalog.Modality,
        longSession: Bool
    ) -> String {
        switch modality {
        case .cycling: return longSession ? "ride" : "cycling session"
        case .running: return longSession ? "run" : "run"
        case .upperBody: return "upper body session"
        case .lowerBody: return "lower body session"
        case .fullBody: return "full body session"
        case .strength: return "strength session"
        case .tennis: return "tennis session"
        case .squash: return "squash session"
        case .general: return longSession ? "session" : "workout"
        }
    }

    private static func sessionDescriptorRU(
        modality: CoachSessionPrepCopyCatalog.Modality,
        longSession: Bool
    ) -> String {
        switch modality {
        case .cycling: return longSession ? "велосессии" : "велосессии"
        case .running: return longSession ? "пробежки" : "пробежки"
        case .upperBody: return "тренировки верха"
        case .lowerBody: return "тренировки низа"
        case .fullBody: return "тренировки всего тела"
        case .strength: return "силовой"
        case .tennis: return "тенниса"
        case .squash: return "сквоша"
        case .general: return longSession ? "сессии" : "тренировки"
        }
    }

    private static func isEndurance(_ modality: CoachSessionPrepCopyCatalog.Modality) -> Bool {
        modality == .cycling || modality == .running
    }

    private static func enduranceOpening(
        modality: CoachSessionPrepCopyCatalog.Modality,
        english: String,
        russian: String,
        compactEnglish: String,
        compactRussian: String,
        compact: Bool
    ) -> CoachSessionPrepCopyCatalog.BilingualText {
        if isEndurance(modality), !compact {
            return bi(english, russian)
        }
        return bi(compact ? compactEnglish : english, compact ? compactRussian : russian)
    }

    private static func bi(_ english: String, _ russian: String) -> CoachSessionPrepCopyCatalog.BilingualText {
        CoachSessionPrepCopyCatalog.BilingualText(english: english, russian: russian)
    }

    private static func prep(
        _ type: CoachSupportActionTypeV3,
        _ titleEN: String,
        _ subtitleEN: String,
        _ titleRU: String,
        _ subtitleRU: String
    ) -> CoachSessionPrepCopyCatalog.PrepActionCopy {
        CoachSessionPrepCopyCatalog.PrepActionCopy(
            type: type,
            title: bi(titleEN, titleRU),
            subtitle: bi(subtitleEN, subtitleRU)
        )
    }
}
