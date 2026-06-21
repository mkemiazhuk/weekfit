import Foundation
import SwiftUI

enum CoachFinalStoryBuilder {
    typealias Display = (stateLabel: String, title: String, message: String, recommendation: String, icon: String, color: Color)

    /// True only when sleep duration/quality evidence supports a deficit diagnosis — not late-night protection framing.
    static func hasSleepDeficitEvidence(_ input: CoachInputSnapshot) -> Bool {
        if input.brain.sleep == .short || input.brain.sleep == .veryShort {
            return true
        }
        let hours = input.recoveryContext.sleepHours
        return hours > 0 && hours < 6.5
    }

    static func hasSleepDeficitEvidence(sleepHours: Double) -> Bool {
        sleepHours > 0 && sleepHours < 6.5
    }

    static func isLateEveningWindDownPhase(_ phase: CoachFinalDecisionTimeOfDay) -> Bool {
        phase == .evening || phase == .lateEvening || phase == .night
    }

    static func isLateEveningWindDown(_ input: CoachInputSnapshot) -> Bool {
        isLateEveningWindDownPhase(finalDecisionTimeOfDay(input.now))
    }

    private struct HumanStory {
        let title: CoachFinalStoryText
        let whatHappened: CoachFinalStoryText
        let whatMattersNow: CoachFinalStoryText
        let whatToDoNext: CoachFinalStoryText
        let whatToAvoid: CoachFinalStoryText
    }

    private enum ActiveSessionAssessment {
        case normalActive
        case activeWithCaution
        case activeAfterOverload
        case activeRecoveryOnly
        case activeSleepRisk
    }

    private enum FinalCopyTheme: String, CaseIterable, Hashable {
        case hydration
        case fuel
        case protein
        case recovery
        case sleep
        case completedLoad
        case upcomingActivity
        case tomorrowDemand
        case flexibility
        case intensityControl
        case saunaHeat
        case cooldown
        case mobility
    }

    private enum CoachActionPool {
        case beforeHardWorkout
        case duringEnduranceSession
        case afterStrengthWorkout
        case afterLongEndurance
        case recoveryDay
        case lowRecoveryPoorReadiness
        case tomorrowBigWorkout
        case optionalRecoveryTools
    }

    private struct CoachActionRecommendation: Hashable {
        let type: CoachSupportActionTypeV3
        let englishTitle: String
        let englishSubtitle: String
        let russianTitle: String
        let russianSubtitle: String
    }

    private enum CoachV4TrainPermission: Hashable {
        case train
        case trainControlled
        case recoveryOnly
        case noTraining
        case noActionNeeded
    }

    private enum CoachV4RecommendedIntensity: Hashable {
        case none
        case easy
        case conversational
        case reduced
        case planned
    }

    private enum CoachV4ActivityClass: Hashable {
        case none
        case recovery
        case training
        case seriousTraining
        case heat
        case nutrition
    }

    private enum CoachV4SeriousTrainingState: Hashable {
        case none
        case upcoming
        case active
        case completed
        case tomorrow
    }

    private enum CoachV4ActivityFamily: Hashable {
        case breathing
        case stretching
        case yoga
        case mobility
        case walk
        case sauna
        case endurance
        case strength
        case racket
        case other
    }

    private enum CoachV4SessionPhase: Hashable {
        case pre
        case during
        case post
        case none
    }

    private enum CoachV4DurationBand: Hashable {
        case shortUnder60
        case medium60To120
        case longOver120
        case none
    }

    private enum CoachV4TimeToSessionWindow: Hashable {
        case fourPlusHours
        case twoToFourHours
        case sixtyTo120Minutes
        case fifteenTo60Minutes
        case under15Minutes
        case none
    }

    private struct CoachV4DayLoadContext {
        let timePhase: CoachFinalDecisionTimeOfDay
        let caloriesBurnedSoFar: Double
        let completedSeriousTrainingToday: Bool
        let completedRecoveryVolumeToday: Int
        let nextImportantActivityToday: PlannedActivity?
        let focusActivity: PlannedActivity?
        let referenceNow: Date
        let recoveryPercent: Int
        let sleepHours: Double
        let hasHighYesterdayLoad: Bool
        let hoursUntilNextImportantActivity: Double?
        let timeToNextImportantSession: CoachV4TimeToSessionWindow
        let tomorrowDemand: CoachTomorrowDemand
        let shouldProtectUpcomingSession: Bool
        let shouldProtectTomorrow: Bool
        let tomorrowRecoveryPlanSummary: CoachTomorrowPlanReadBuilder.RecoveryPlanSummary?
        let todayPlanSummary: CoachDayPlanReadBuilder.DayPlanSummary?
        let needsRecoveryNutrition: Bool
    }

    private struct CoachV4DecisionFrame {
        let storyOwner: CoachFinalStoryOwner
        let trainPermission: CoachV4TrainPermission
        let recommendedIntensity: CoachV4RecommendedIntensity
        let objective: CoachObjective
        let primaryLimiter: CoachLimiter
        let activityClass: CoachV4ActivityClass
        let activityFamily: CoachV4ActivityFamily
        let sessionPhase: CoachV4SessionPhase
        let durationBand: CoachV4DurationBand
        let seriousTrainingState: CoachV4SeriousTrainingState
        let dayLoadContext: CoachV4DayLoadContext
        let timePhase: CoachFinalDecisionTimeOfDay
        let hero: CoachFinalStoryText
        let assessment: CoachFinalStoryText
        let situation: CoachFinalStoryText
        let primaryAction: CoachActionRecommendation
        let avoidance: CoachFinalStoryText
        let actions: [CoachActionRecommendation]
        let reasons: [CoachV4Reason]
        let preservesAuthoritativePlanChangeNarrative: Bool
    }

    private struct CoachV4PlaybookOutput {
        let hero: CoachFinalStoryText
        let assessment: CoachFinalStoryText
        let situation: CoachFinalStoryText
        let primaryAction: CoachActionRecommendation
        let avoidance: CoachFinalStoryText
        let actions: [CoachActionRecommendation]
        let reasons: [CoachV4Reason]
    }

    private struct CoachV4Reason: Hashable {
        let kind: CoachFinalStoryReason.Kind
        let english: String
        let russian: String
        let icon: String
        let colorFamily: CoachFinalStoryColorFamily
    }

    private struct CoachActionLibrary {
        static func recommendations(for pool: CoachActionPool) -> [CoachActionRecommendation] {
            switch pool {
            case .beforeHardWorkout:
                return [
                    action(.hydrateBeforeSession, "Drink another 300-500 ml", "Over the next hour", "Постарайтесь попить воды", "В ближайший час, без залпа"),
                    action(.lightFueling, "Finish the main meal with carbs", "2-3 hours before the workout", "Если ещё не поели — сейчас лучше полноценный приём", "За пару часов до старта"),
                    action(.controlIntensity, "Avoid extra activity", "Keep the time before the session quiet", "Сейчас лучше не добавлять активность", "До тренировки"),
                    action(.controlIntensity, "Start with 10 minutes easy", "Let the warm-up set the first rhythm", "Первые минуты лучше спокойнее", "Разминка задаёт ритм"),
                    action(.hydrateBeforeSession, "Prepare hydration and nutrition", "Set it up before you leave", "Возьмите воду и перекус заранее", "До выхода"),
                    action(.lightRecoveryMovement, "Keep your legs fresh", "Save them for the main work ahead", "Сохраните силы в ногах", "Для главной работы")
                ]
            case .duringEnduranceSession:
                return [
                    action(.controlIntensity, "Hold the next 10 minutes controlled", "Skip surges while breathing and legs settle", "Следующие минуты лучше ровнее", "Пока дыхание и ноги не успокоятся — без рывков"),
                    action(.controlIntensity, "Keep the next block below hard effort", "Save intensity for the planned work", "Следующий отрезок без геройства", "Сохраните силы на главную часть"),
                    action(.sustainEnergy, "Fuel before hunger appears", "Check nutrition before the first dip", "Сейчас лучше не ждать голода", "До того, как упадёт энергия"),
                    action(.steadyHydration, "Drink in small amounts", "Take regular small sips", "По чуть-чуть воду", "Весь путь, маленькими глотками"),
                    action(.controlIntensity, "Hold a steady rhythm", "Keep the session smooth, not spiky", "Ровный темп сейчас лучше", "Без резких ускорений")
                ]
            case .afterStrengthWorkout:
                return [
                    action(.recoveryMeal, "Aim for 25-40 g protein", "Within the next hour", "Добавьте белок в следующий приём", "В ближайший час"),
                    action(.rehydrateGradually, "Drink 300-700 ml fluid", "After the workout", "Постарайтесь попить воды", "После тренировки"),
                    action(.cooldown, "Finish 5-10 minutes easy", "Use it as a cooldown", "Несколько минут лёгкой заминки", "В конце тренировки"),
                    action(.controlIntensity, "Avoid another hard workout", "Keep the rest of today lighter", "Сегодня лучше без ещё одной тяжёлой тренировки", "Сегодня"),
                    action(.recoveryMeal, "Have a complete meal", "Within the next 2 hours", "Полноценный приём пищи скорее всего поможет", "В течение пары часов")
                ]
            case .afterLongEndurance:
                return [
                    action(.recoveryMeal, "Eat within 1 hour", "Do not delay the first recovery meal", "Постарайтесь поесть в ближайший час", "После длинной работы"),
                    action(.recoveryMeal, "Add carbs and protein", "Put both into the next meal", "В следующий приём — еда и белок", "В ближайший приём пищи"),
                    action(.rehydrateGradually, "Rehydrate through the evening", "Keep fluids moving gradually", "Постепенно попейте воды", "В течение вечера"),
                    action(.controlIntensity, "Keep the rest of the day calm", "Avoid stacking more load", "Остаток дня лучше спокойный", "Без дополнительной нагрузки"),
                    action(.sleepPriority, "Make sleep part of recovery", "Tonight matters after long work", "Сон сегодня — часть восстановления", "Сегодня ночью")
                ]
            case .recoveryDay:
                return [
                    action(.lightRecoveryMovement, "Walk 20-40 minutes easy", "Keep it conversational", "Лёгкая прогулка — если хочется", "В комфортном темпе"),
                    action(.controlIntensity, "Keep the effort comfortable", "No hard blocks today", "Держите всё комфортно", "Без тяжёлых отрезков"),
                    action(.mobilityPrep, "Add 5-10 minutes mobility", "Keep the range easy", "Несколько минут мобильности", "Без силовой нагрузки"),
                    action(.controlIntensity, "Do not turn this into training", "Stop before it becomes work", "Сегодня лучше не превращать отдых в тренировку", "Остановитесь до утомления"),
                    action(.controlIntensity, "Finish without extra load", "Keep the day recovery-focused", "Завершите день без дополнительной нагрузки", "Оставьте день восстановительным")
                ]
            case .lowRecoveryPoorReadiness:
                return [
                    action(.controlIntensity, "Reduce intensity by one level", "Use this before the main set", "Сейчас лучше чуть легче обычного", "Перед основной частью"),
                    action(.controlIntensity, "Start 10-15 minutes easier", "Then reassess after warm-up", "Первые минуты легче обычного", "После разминки оцените, как чувствуете себя"),
                    action(.controlIntensity, "Reassess after warm-up", "Decide from breathing, legs, and control", "После разминки обратите внимание на самочувствие", "По дыханию, ногам и контролю"),
                    action(.controlIntensity, "Prioritize quality over volume", "Stop chasing extra work", "Качество сейчас важнее объёма", "Без догонки плана любой ценой"),
                    action(.controlIntensity, "Consider shortening the session", "Cut the least important block first", "Можно сократить тренировку", "Сначала уберите наименее важный блок")
                ]
            case .tomorrowBigWorkout:
                return [
                    action(.sleepPriority, "Aim for 7-8 hours sleep", "Make tonight the main recovery block", "Постарайтесь выспаться", "Сегодня ночью"),
                    action(.controlIntensity, "Avoid another workout today", "Keep the remaining load low", "Сегодня лучше без ещё одной тренировки", "Сегодня"),
                    action(.sleepPriority, "Finish hard activity early", "Leave several hours before bedtime", "Интенсивную активность лучше завершить заранее", "За несколько часов до сна"),
                    action(.controlIntensity, "Save energy for tomorrow", "Do not spend it tonight", "Сохраните силы на завтра", "Не тратьте их сегодня вечером"),
                    action(.downshiftNervousSystem, "Keep the evening calm", "Make the morning easier to start", "Вечер лучше максимально спокойный", "Чтобы утром было легче начать")
                ]
            case .optionalRecoveryTools:
                return [
                    action(.mobilityPrep, "Stretch 5-10 minutes easy", "Keep it light", "Несколько минут лёгкой растяжки", "Без усилия"),
                    action(.mobilityPrep, "Do 5-10 minutes mobility", "Keep the movement relaxed", "Несколько минут мобильности", "Спокойно, без нагрузки"),
                    action(.downshiftNervousSystem, "Take a cool shower", "Useful after training in heat", "Прохладный душ", "После тренировки в жару"),
                    action(.lightRecoveryMovement, "Walk easy after dinner", "Keep it short and relaxed", "Лёгкая прогулка после ужина", "Коротко и спокойно"),
                    action(.sleepPriority, "Go to bed earlier", "Use it as recovery, not a bonus", "Ранний отход ко сну", "Как часть восстановления")
                ]
            }
        }

        private static func action(
            _ type: CoachSupportActionTypeV3,
            _ englishTitle: String,
            _ englishSubtitle: String,
            _ russianTitle: String,
            _ russianSubtitle: String
        ) -> CoachActionRecommendation {
            CoachActionRecommendation(
                type: type,
                englishTitle: englishTitle,
                englishSubtitle: englishSubtitle,
                russianTitle: russianTitle,
                russianSubtitle: russianSubtitle
            )
        }

        static func noAction(reasonEnglish: String, reasonRussian: String) -> CoachActionRecommendation {
            action(
                .stayConsistent,
                "Do nothing extra",
                reasonEnglish,
                "Дополнительно ничего не нужно",
                reasonRussian
            )
        }
    }

    private struct FinalCopyPlan {
        let humanStory: HumanStory
        let reasons: [CoachFinalStoryReason]
        let supportActions: [CoachSupportActionV3]
    }

    private enum CoachV4ActivityPlaybook {

        static func resolve(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            if frame.storyOwner == .tomorrowProtection || frame.storyOwner == .stableOverview || frame.storyOwner == .readiness {
                return base(frame)
            }
            if frame.activityClass == .heat {
                return sauna(frame)
            }
            if frame.storyOwner == .recovery {
                return base(frame)
            }
            if frame.trainPermission == .noTraining {
                return base(frame)
            }
            if frame.sessionPhase == .during,
               frame.trainPermission == .trainControlled || frame.primaryLimiter == .recovery || frame.primaryLimiter == .accumulatedFatigue {
                return base(frame)
            }

            switch frame.activityFamily {
            case .breathing, .stretching, .yoga, .mobility, .walk:
                return recoveryModality(frame)
            case .sauna:
                return sauna(frame)
            case .endurance:
                return endurance(frame)
            case .strength:
                return strength(frame)
            case .racket:
                return racket(frame)
            case .other:
                return base(frame)
            }
        }

        private static func base(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            let assessment = frame.preservesAuthoritativePlanChangeNarrative
                ? frame.assessment
                : holisticAssessment(frame: frame, tactical: frame.assessment)
            return CoachV4PlaybookOutput(
                hero: frame.hero,
                assessment: assessment,
                situation: frame.situation,
                primaryAction: frame.primaryAction,
                avoidance: frame.avoidance,
                actions: frame.actions,
                reasons: defaultReasons(frame)
            )
        }

        private static func recoveryModality(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            let name = recoveryFamilyName(frame.activityFamily)
            let next = frame.dayLoadContext.nextImportantActivityToday
            let nextName = next.map { CoachFinalStoryBuilder.displayName($0).lowercased() } ?? "next important session"
            let hasNext = next != nil

            let hero: CoachFinalStoryText
            let assessment: CoachFinalStoryText
            let situation: CoachFinalStoryText
            let primary: CoachActionRecommendation
            let avoidance: CoachFinalStoryText

            switch frame.sessionPhase {
            case .pre:
                hero = CoachFinalStoryBuilder.dynamicText("Use \(name.english) as support", russian: "\(name.russian) — как поддержка")
                assessment = hasNext
                    ? CoachFinalStoryBuilder.dynamicText("This can prepare the body, but the important \(nextName) is still ahead.", russian: "Размять тело можно, но главная тренировка ещё впереди.")
                    : CoachFinalStoryBuilder.dynamicText("This is useful recovery work, not a training target.", russian: "Это для отдыха, а не замена тренировки.")
                situation = CoachFinalStoryBuilder.dynamicText("Keep it easy enough to leave the body fresher after it.", russian: "Так легко, чтобы после стало свежее.")
                primary = action(.lightRecoveryMovement, "Keep it easy", hasNext ? "Save energy for the session ahead" : "Stop before it becomes work", "Держите легко", hasNext ? "Сохраните силы на следующую тренировку" : "Остановитесь до утомления")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not turn this into training.", russian: "Сегодня лучше не превращать это в тренировку.")

            case .during:
                hero = CoachFinalStoryBuilder.dynamicText("Keep \(name.english) relaxed", russian: "Пусть \(name.russian) будет спокойной")
                assessment = hasNext
                    ? CoachFinalStoryBuilder.dynamicText("The important \(nextName) is still ahead, so this \(name.english) should stay easy.", russian: "Главная тренировка ещё впереди — \(name.russian) лучше лёгкой.")
                    : frame.dayLoadContext.completedSeriousTrainingToday
                    ? CoachFinalStoryBuilder.dynamicText("Today already has training stress, so this should only help recovery.", russian: "Сегодня уже была тренировка — это только для отдыха.")
                    : CoachFinalStoryBuilder.dynamicText("This is low-strain work inside the bigger training day.", russian: "Это лёгкая работа в рамках тренировочного дня.")
                situation = hasNext
                    ? CoachFinalStoryBuilder.dynamicText("Save energy for the session ahead.", russian: "Сохраните силы на следующую тренировку.")
                    : CoachFinalStoryBuilder.dynamicText("Stay comfortable and finish with more control than you started.", russian: "Оставайтесь в комфорте и завершите с запасом.")
                primary = hasNext
                    ? action(.controlIntensity, "Keep it easy", "Save energy for the session ahead", "Держите легко", "Сохраните силы для следующей тренировки")
                    : action(.controlIntensity, "Stay conversational", "Keep effort relaxed the whole time", "Темп, в котором можете разговаривать", "Всё время без напряжения")
                avoidance = hasNext
                    ? CoachFinalStoryBuilder.dynamicText("Do not turn this into training.", russian: "Сегодня лучше не превращать это в тренировку.")
                    : CoachFinalStoryBuilder.dynamicText("Do not compete with the recovery work.", russian: "Не превращайте это в соревнование с отдыхом.")

            case .post:
                hero = CoachFinalStoryBuilder.dynamicText("\(capitalized(name.english)) supported recovery", russian: "\(capitalized(name.russian)) помогла отдохнуть")
                assessment = CoachFinalStoryBuilder.dynamicText("This helped recovery without adding meaningful training strain.", russian: "Помогло отдохнуть, без лишней усталости.")
                situation = hasNext
                    ? CoachFinalStoryBuilder.dynamicText("The next important work still matters more than this completed \(name.english).", russian: "Следующая тренировка всё ещё важнее.")
                    : CoachFinalStoryBuilder.dynamicText("Treat it as support for the day, not as the main work.", russian: "Это поддержка дня, а не основная работа.")
                primary = action(.stayConsistent, hasNext ? "Save energy for later" : "Do nothing extra", hasNext ? "Keep the rest of the day quiet enough for the next session" : "No recovery alert is needed from this alone", hasNext ? "Сохраните силы на потом" : "Дополнительно ничего не нужно", hasNext ? "Оставьте день спокойным для следующей тренировки" : "Одна такая активность восстановления не требует")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not count this as the main workout.", russian: "Не считайте это главной тренировкой.")

            case .none:
                hero = CoachFinalStoryBuilder.dynamicText("Use recovery work carefully", russian: "Лёгкая активность — без фанатизма")
                assessment = CoachFinalStoryBuilder.dynamicText("Recovery work should support the day, not replace the plan.", russian: "Лёгкая активность поддерживает день, а не заменяет план.")
                situation = CoachFinalStoryBuilder.dynamicText("Let the bigger day context decide how much is useful.", russian: "Общий контекст дня подскажет, сколько будет полезно.")
                primary = action(.lightRecoveryMovement, "Keep it light", "Use only the amount that leaves you fresher", "Держите легко", "Только тот объём, после которого свежее")
                avoidance = CoachFinalStoryBuilder.dynamicText("Do not add load without a reason.", russian: "Лишнего без причины лучше не добавлять.")
            }

            return output(
                frame: frame,
                hero: hero,
                assessment: assessment,
                situation: situation,
                primary: primary,
                avoidance: avoidance,
                extras: recoveryExtras(frame)
            )
        }

        private static func sauna(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            let hero: CoachFinalStoryText
            let assessment: CoachFinalStoryText
            let situation: CoachFinalStoryText
            let primary: CoachActionRecommendation
            let avoidance: CoachFinalStoryText

            switch frame.sessionPhase {
            case .pre, .none:
                hero = CoachFinalStoryBuilder.dynamicText("Before sauna — drink up", russian: "Перед сауной — попейте воды")
                assessment = CoachFinalStoryBuilder.dynamicText("Sauna still stresses your body, even when it feels relaxing.", russian: "Сауна всё равно берёт силы, даже если расслабляет.")
                situation = frame.dayLoadContext.shouldProtectTomorrow
                    ? CoachFinalStoryBuilder.dynamicText("Go easy tonight — tomorrow has training.", russian: "Сегодня вечером сохраните силы — завтра тренировка.")
                    : CoachFinalStoryBuilder.dynamicText("Drink enough water and sauna will help. Skip it and it will cost you.", russian: "С водой сауна скорее всего поможет. Без воды — заберёт силы.")
                primary = action(.hydrateBeforeSession, "Drink 300-500 ml water", "In the hour before sauna", "Попейте воды", "В час перед сауной")
                avoidance = CoachFinalStoryBuilder.dynamicText("Don't go in thirsty or push through fatigue.", russian: "С жаждой лучше не заходить — усталость не терпите.")
            case .during:
                hero = CoachFinalStoryBuilder.dynamicText("Keep the heat moderate", russian: "Тепло лучше умеренное")
                assessment = CoachFinalStoryBuilder.dynamicText("Right now the load is heat, not training.", russian: "Сейчас главное — тепло, а не тренировка.")
                situation = CoachFinalStoryBuilder.dynamicText("Leave before you feel worn out.", russian: "Выйдите, пока не почувствуете усталость.")
                primary = action(.controlIntensity, "Leave before fatigue hits", "Keep the heat moderate", "Выйдите до усталости", "Тепло лучше умеренное")
                avoidance = CoachFinalStoryBuilder.dynamicText("Don't add more heat stress today.", russian: "Лишний тепловой стресс сегодня лучше не добавлять.")
            case .post:
                if let planHero = CoachDayPlanReadBuilder.postHeatHero(summary: frame.dayLoadContext.todayPlanSummary) {
                    hero = CoachFinalStoryBuilder.dynamicText(planHero.english, russian: planHero.russian)
                } else {
                    hero = CoachFinalStoryBuilder.dynamicText("After sauna — drink and rest", russian: "После сауны — вода и отдых")
                }
                assessment = CoachFinalStoryBuilder.dynamicText("Sauna can feel good, but you still need to replace the fluids you lost.", russian: "Сауна может расслабить, но воду всё равно нужно восполнить.")
                if let balance = frame.dayLoadContext.todayPlanSummary.flatMap({
                    CoachDayPlanReadBuilder.postSessionBalanceClause(summary: $0, isPostHeat: true)
                }) {
                    situation = CoachFinalStoryBuilder.dynamicText(balance.english, russian: balance.russian)
                } else {
                    situation = CoachFinalStoryBuilder.dynamicText("Drink water and keep the evening calm.", russian: "Попейте воды и держите вечер спокойным.")
                }
                primary = action(.rehydrateGradually, "Drink 300-700 ml slowly", "Sip after sauna", "Постепенно попейте воды", "После сауны небольшими глотками")
                avoidance = CoachFinalStoryBuilder.dynamicText("Don't do hard work right after sauna.", russian: "Тяжёлую работу сразу после сауны лучше не делать.")
            }

            return output(frame: frame, hero: hero, assessment: assessment, situation: situation, primary: primary, avoidance: avoidance, extras: saunaExtras(frame))
        }

        private static func catalogAction(_ copy: CoachEnduranceDuringPostCopyCatalog.ActionCopy) -> CoachActionRecommendation {
            action(
                copy.type,
                copy.title.english,
                copy.subtitle.english,
                copy.title.russian,
                copy.subtitle.russian
            )
        }

        private static func catalogReasons(_ copies: [CoachEnduranceDuringPostCopyCatalog.ReasonCopy]) -> [CoachV4Reason] {
            copies.map {
                reason($0.kind, $0.english, $0.russian, icon: $0.icon, colorFamily: $0.colorFamily)
            }
        }

        private static func holisticReadContext(from frame: CoachV4DecisionFrame) -> CoachHolisticReadBuilder.Context {
            let next = frame.dayLoadContext.nextImportantActivityToday
            let heroEnglish = frame.hero.fallback.lowercased()
            let heroRussian = frame.hero.russianFallback.lowercased()
            let heroNamesUpcomingPlan = heroEnglish.contains("plan starts with") ||
                heroEnglish.contains("next up is") ||
                heroRussian.contains("плану начинается") ||
                heroRussian.contains("дальше по плану")
            let isCalmOverviewDay = (frame.storyOwner == .readiness || frame.storyOwner == .stableOverview) &&
                frame.trainPermission == .noActionNeeded
            let isPostHeatRecovery = frame.sessionPhase == .post &&
                (frame.activityClass == .heat || frame.activityFamily == .sauna)
            return CoachHolisticReadBuilder.Context(
                owner: frame.storyOwner,
                isPreSession: frame.sessionPhase == .pre,
                isDuringSession: frame.sessionPhase == .during,
                isPostSession: frame.sessionPhase == .post,
                recoveryPercent: frame.dayLoadContext.recoveryPercent,
                caloriesBurned: frame.dayLoadContext.caloriesBurnedSoFar,
                completedSeriousTrainingToday: frame.dayLoadContext.completedSeriousTrainingToday,
                sleepLimited: CoachFinalStoryBuilder.hasSleepDeficitEvidence(
                    sleepHours: frame.dayLoadContext.sleepHours
                ),
                recoveryLimited: frame.primaryLimiter == .recovery,
                hydrationLimited: frame.primaryLimiter == .hydration,
                fuelLimited: frame.primaryLimiter == .fueling,
                nextActivityTitle: next.map { CoachFinalStoryBuilder.displayName($0) },
                hoursUntilNextActivity: frame.dayLoadContext.hoursUntilNextImportantActivity,
                hasUpcomingSessionToday: frame.dayLoadContext.nextImportantActivityToday != nil,
                shouldProtectTomorrow: frame.dayLoadContext.shouldProtectTomorrow,
                shouldProtectUpcomingSession: frame.dayLoadContext.shouldProtectUpcomingSession,
                tomorrowRecoveryPlanSummary: frame.dayLoadContext.tomorrowRecoveryPlanSummary,
                timePhase: frame.dayLoadContext.timePhase,
                heroNamesUpcomingPlan: heroNamesUpcomingPlan,
                isCalmOverviewDay: isCalmOverviewDay,
                isPostHeatRecovery: isPostHeatRecovery,
                todayPlanSummary: frame.dayLoadContext.todayPlanSummary
            )
        }

        private static func holisticAssessment(
            frame: CoachV4DecisionFrame,
            tacticalEN: String,
            tacticalRU: String
        ) -> CoachFinalStoryText {
            let read = CoachHolisticReadBuilder.compose(
                context: holisticReadContext(from: frame),
                tactical: CoachHolisticReadBuilder.Copy(english: tacticalEN, russian: tacticalRU)
            )
            return CoachFinalStoryBuilder.dynamicText(read.english, russian: read.russian)
        }

        private static func holisticAssessment(
            frame: CoachV4DecisionFrame,
            tactical: CoachFinalStoryText
        ) -> CoachFinalStoryText {
            holisticAssessment(
                frame: frame,
                tacticalEN: tactical.fallback,
                tacticalRU: tactical.russianFallback
            )
        }

        private static func catalogPlaybook(
            window: CoachEnduranceDuringPostCopyCatalog.WindowCopy,
            phase: CoachEnduranceDuringPostCopyCatalog.Phase,
            frame: CoachV4DecisionFrame
        ) -> CoachV4PlaybookOutput {
            let activity = frame.dayLoadContext.focusActivity
            let longSession = frame.durationBand == .longOver120
            let elapsed = CoachEnduranceDuringPostCopyCatalog.elapsedMinutes(
                activity: activity,
                now: frame.dayLoadContext.referenceNow
            )
            let remaining = CoachEnduranceDuringPostCopyCatalog.remainingMinutes(
                activity: activity,
                now: frame.dayLoadContext.referenceNow
            )
            let minutesSinceEnd = frame.sessionPhase == .post
                ? CoachEnduranceDuringPostCopyCatalog.minutesSinceEnd(
                    activity: activity,
                    now: frame.dayLoadContext.referenceNow
                )
                : 0
            let catalogExtras = CoachEnduranceDuringPostCopyCatalog.extras(
                for: phase,
                activity: activity,
                longSession: longSession,
                minutesSinceEnd: minutesSinceEnd
            )
            let reasons = CoachEnduranceDuringPostCopyCatalog.reasons(
                for: phase,
                activity: activity,
                elapsedMinutes: elapsed,
                remainingMinutes: remaining,
                recoveryPercent: frame.dayLoadContext.recoveryPercent,
                caloriesBurned: frame.dayLoadContext.caloriesBurnedSoFar,
                shouldProtectTomorrow: frame.dayLoadContext.shouldProtectTomorrow,
                minutesSinceEnd: minutesSinceEnd
            )
            return playbookOnlyOutput(
                hero: CoachFinalStoryBuilder.dynamicText(window.hero.english, russian: window.hero.russian),
                assessment: holisticAssessment(
                    frame: frame,
                    tacticalEN: window.assessment.english,
                    tacticalRU: window.assessment.russian
                ),
                situation: CoachFinalStoryBuilder.dynamicText(window.situation.english, russian: window.situation.russian),
                primary: catalogAction(window.primary),
                avoidance: CoachFinalStoryBuilder.dynamicText(window.avoidance.english, russian: window.avoidance.russian),
                extras: catalogExtras.map(catalogAction),
                reasons: catalogReasons(reasons)
            )
        }

        private static func endurance(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            if frame.sessionPhase == .pre {
                return preSession(frame)
            }

            let activity = frame.dayLoadContext.focusActivity
            let longSession = frame.durationBand == .longOver120

            switch (frame.sessionPhase, frame.durationBand) {
            case (.during, _):
                switch frame.storyOwner {
                case .fuelingDuringActivity:
                    let window = CoachEnduranceDuringPostCopyCatalog.window(for: .fueling, activity: activity, longSession: longSession)
                    return catalogPlaybook(window: window, phase: .fueling, frame: frame)
                case .hydrationExecution:
                    let window = CoachEnduranceDuringPostCopyCatalog.window(for: .hydration, activity: activity, longSession: longSession)
                    return catalogPlaybook(window: window, phase: .hydration, frame: frame)
                case .pacingExecution:
                    let window = CoachEnduranceDuringPostCopyCatalog.window(for: .pacing, activity: activity, longSession: longSession)
                    return catalogPlaybook(window: window, phase: .pacing, frame: frame)
                case .sustainableExecution:
                    let window = CoachEnduranceDuringPostCopyCatalog.window(for: .sustainable, activity: activity, longSession: longSession)
                    return catalogPlaybook(window: window, phase: .sustainable, frame: frame)
                default:
                    let window = CoachEnduranceDuringPostCopyCatalog.window(for: .sustainable, activity: activity, longSession: longSession)
                    return catalogPlaybook(window: window, phase: .sustainable, frame: frame)
                }
            case (.post, .longOver120):
                let minutesSinceEnd = CoachEnduranceDuringPostCopyCatalog.minutesSinceEnd(
                    activity: activity,
                    now: frame.dayLoadContext.referenceNow
                )
                let postContext = CoachEnduranceDuringPostCopyCatalog.PostContext(
                    recoveryPercent: frame.dayLoadContext.recoveryPercent,
                    caloriesBurned: frame.dayLoadContext.caloriesBurnedSoFar,
                    shouldProtectTomorrow: frame.dayLoadContext.shouldProtectTomorrow,
                    timePhase: frame.dayLoadContext.timePhase
                )
                let window = CoachEnduranceDuringPostCopyCatalog.window(
                    for: .postLong,
                    activity: activity,
                    longSession: true,
                    minutesSinceEnd: minutesSinceEnd,
                    postContext: postContext
                )
                return catalogPlaybook(window: window, phase: .postLong, frame: frame)
            case (.post, .medium60To120):
                let minutesSinceEnd = CoachEnduranceDuringPostCopyCatalog.minutesSinceEnd(
                    activity: activity,
                    now: frame.dayLoadContext.referenceNow
                )
                let postContext = CoachEnduranceDuringPostCopyCatalog.PostContext(
                    recoveryPercent: frame.dayLoadContext.recoveryPercent,
                    caloriesBurned: frame.dayLoadContext.caloriesBurnedSoFar,
                    shouldProtectTomorrow: frame.dayLoadContext.shouldProtectTomorrow,
                    timePhase: frame.dayLoadContext.timePhase
                )
                let window = CoachEnduranceDuringPostCopyCatalog.window(
                    for: .postMedium,
                    activity: activity,
                    longSession: false,
                    minutesSinceEnd: minutesSinceEnd,
                    postContext: postContext
                )
                return catalogPlaybook(window: window, phase: .postMedium, frame: frame)
            case (.post, .shortUnder60), (.post, .none):
                let minutesSinceEnd = CoachEnduranceDuringPostCopyCatalog.minutesSinceEnd(
                    activity: activity,
                    now: frame.dayLoadContext.referenceNow
                )
                let postContext = CoachEnduranceDuringPostCopyCatalog.PostContext(
                    recoveryPercent: frame.dayLoadContext.recoveryPercent,
                    caloriesBurned: frame.dayLoadContext.caloriesBurnedSoFar,
                    shouldProtectTomorrow: frame.dayLoadContext.shouldProtectTomorrow,
                    timePhase: frame.dayLoadContext.timePhase
                )
                let window = CoachEnduranceDuringPostCopyCatalog.window(
                    for: .postShort,
                    activity: activity,
                    longSession: false,
                    minutesSinceEnd: minutesSinceEnd,
                    postContext: postContext
                )
                return catalogPlaybook(window: window, phase: .postShort, frame: frame)
            case (.pre, _):
                return preSession(frame)
            case (.none, _):
                return base(frame)
            }
        }

        private static func preSession(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            let activity = frame.dayLoadContext.nextImportantActivityToday
            let longSession = frame.durationBand == .longOver120
            let copy = CoachSessionPrepCopyCatalog.copy(for: activity, longSession: longSession)

            let window: CoachSessionPrepCopyCatalog.PrepWindowCopy
            let prepTimeWindow: CoachSessionPrepNarrativeBuilder.PrepTimeWindow
            switch frame.dayLoadContext.timeToNextImportantSession {
            case .fourPlusHours:
                window = copy.fourPlusHours
                prepTimeWindow = .longLead
            case .twoToFourHours:
                window = copy.twoToFourHours
                prepTimeWindow = .longLead
            case .sixtyTo120Minutes:
                window = copy.sixtyTo120Minutes
                prepTimeWindow = .imminent
            case .fifteenTo60Minutes:
                window = copy.fifteenTo60Minutes
                prepTimeWindow = .imminent
            case .under15Minutes:
                window = copy.under15Minutes
                prepTimeWindow = .imminent
            case .none:
                window = copy.fifteenTo60Minutes
                prepTimeWindow = .imminent
            }

            let enriched = CoachSessionPrepNarrativeBuilder.enrich(
                activity: activity,
                context: CoachSessionPrepNarrativeBuilder.Context(
                    longSession: longSession,
                    durationMinutes: activity?.effectiveDurationMinutes ?? 0,
                    minutesUntil: frame.dayLoadContext.hoursUntilNextImportantActivity
                        .map { Int(($0 * 60).rounded()) },
                    recoveryPercent: frame.dayLoadContext.recoveryPercent,
                    sleepHours: frame.dayLoadContext.sleepHours,
                    hasHighYesterdayLoad: frame.dayLoadContext.hasHighYesterdayLoad,
                    completedSeriousTrainingToday: frame.dayLoadContext.completedSeriousTrainingToday,
                    caloriesBurnedSoFar: frame.dayLoadContext.caloriesBurnedSoFar,
                    primaryLimiter: frame.primaryLimiter,
                    fuelLimited: frame.primaryLimiter == .fueling,
                    hydrationLimited: frame.primaryLimiter == .hydration,
                    recoveryLimited: frame.primaryLimiter == .recovery ||
                        frame.primaryLimiter == .accumulatedFatigue,
                    sleepLimited: CoachFinalStoryBuilder.hasSleepDeficitEvidence(
                        sleepHours: frame.dayLoadContext.sleepHours
                    )
                ),
                window: window,
                baseCopy: copy,
                timeWindow: prepTimeWindow
            )
            let actionExtras = enriched.extras.isEmpty ? window.extras : enriched.extras

            return playbookOnlyOutput(
                hero: CoachFinalStoryBuilder.dynamicText(enriched.hero.english, russian: enriched.hero.russian),
                assessment: holisticAssessment(
                    frame: frame,
                    tacticalEN: enriched.assessment.english,
                    tacticalRU: enriched.assessment.russian
                ),
                situation: CoachFinalStoryBuilder.dynamicText(enriched.situation.english, russian: enriched.situation.russian),
                primary: action(
                    enriched.primary.type,
                    enriched.primary.title.english,
                    enriched.primary.subtitle.english,
                    enriched.primary.title.russian,
                    enriched.primary.subtitle.russian
                ),
                avoidance: CoachFinalStoryBuilder.dynamicText(enriched.avoidance.english, russian: enriched.avoidance.russian),
                extras: actionExtras.map {
                    action($0.type, $0.title.english, $0.subtitle.english, $0.title.russian, $0.subtitle.russian)
                },
                reasons: preSessionReasons(frame)
            )
        }

        private static func strength(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            if frame.sessionPhase == .pre {
                return preSession(frame)
            }

            let post = frame.sessionPhase == .post
            let fuelLimited = frame.primaryLimiter == .fueling || (post && frame.dayLoadContext.needsRecoveryNutrition)
            let hero = post
                ? (fuelLimited
                    ? CoachFinalStoryBuilder.dynamicText("Refuel after strength", russian: "После силовой — пора поесть")
                    : CoachFinalStoryBuilder.dynamicText("Strength work behind you", russian: "Силовая позади"))
                : CoachFinalStoryBuilder.dynamicText("Keep strength controlled", russian: "Силовую лучше держать под контролем")
            let assessment = post
                ? (fuelLimited
                    ? CoachFinalStoryBuilder.dynamicText("Strength work needs protein and a proper meal now.", russian: "После силовой нужны белок и полноценный приём пищи.")
                    : CoachFinalStoryBuilder.dynamicText("Nutrition looks on track — protect the rest of the day.", russian: "Питание в порядке — берегите остаток дня."))
                : CoachFinalStoryBuilder.dynamicText("Form and reserve matter more than forcing load today.", russian: "Техника и запас сегодня важнее, чем гнаться за весом.")
            let situation = frame.dayLoadContext.shouldProtectTomorrow
                ? CoachFinalStoryBuilder.dynamicText("Tomorrow's work should influence how much you spend now.", russian: "Завтрашняя тренировка должна ограничивать сегодняшний расход.")
                : CoachFinalStoryBuilder.dynamicText("Useful strength should finish with control left.", russian: "Хорошая силовая заканчивается с запасом.")
            let primary = post
                ? (fuelLimited
                    ? action(.recoveryMeal, "Target 25-40 g protein", "In the next meal", "Добавьте белок в следующий приём", "В ближайший приём пищи")
                    : action(.sleepPriority, "Keep the rest of the day easy", "Recovery is mostly about calm now", "Остаток дня лучше лёгкий", "Сейчас важнее спокойствие"))
                : action(.controlIntensity, "Leave 1-2 reps in reserve", "Keep form clean", "Оставьте пару повторов в запасе", "Держите технику чистой")
            let avoidance = CoachFinalStoryBuilder.dynamicText("Do not add sloppy volume.", russian: "Объём ценой техники лучше не добавлять.")
            let extras = post
                ? [
                    action(.cooldown, "Finish 5-10 minutes easy", "Let the body come down", "Несколько минут легко", "Дайте телу спокойно снизить темп"),
                    action(.rehydrateGradually, "Drink 300-700 ml fluid", "During the next hour", "Постарайтесь попить воды", "В ближайший час, без залпа")
                ]
                : []
            if post {
                let minutesSinceEnd = CoachEnduranceDuringPostCopyCatalog.minutesSinceEnd(
                    activity: frame.dayLoadContext.focusActivity,
                    now: frame.dayLoadContext.referenceNow
                )
                let postTiming = CoachEnduranceDuringPostCopyCatalog.PostTiming.from(minutesSinceEnd: minutesSinceEnd)
                let postHero = postTiming == .stale
                    ? CoachFinalStoryBuilder.dynamicText(
                        CoachTimeOfDayFraming.strengthPostStaleHero(timePhase: frame.dayLoadContext.timePhase).english,
                        russian: CoachTimeOfDayFraming.strengthPostStaleHero(timePhase: frame.dayLoadContext.timePhase).russian
                    )
                    : postTiming == .settled
                    ? CoachFinalStoryBuilder.dynamicText("Strength work behind you", russian: "Силовая позади")
                    : hero
                let postAssessment = postTiming == .stale
                    ? CoachFinalStoryBuilder.dynamicText(
                        "The heavy work is hours behind you now — sleep and a calm evening matter most.",
                        russian: "Тяжёлая работа уже несколько часов позади — сейчас важнее сон и спокойный вечер."
                    )
                    : postTiming == .settled
                    ? CoachFinalStoryBuilder.dynamicText(
                        "Strength is done for now — protect the rest of the day.",
                        russian: "Силовая на сегодня сделана — берегите остаток дня."
                    )
                    : assessment
                let postPrimary = postTiming == .immediate
                    ? primary
                    : action(.sleepPriority, "Keep the rest of the day easy", "No need to keep acting like the session just ended", "Остаток дня лучше лёгкий", "Не нужно жить так, будто тренировка только что закончилась")
                let postExtras = postTiming == .immediate ? extras : [
                    action(.sleepPriority, "Protect sleep tonight", "That is where strength recovery finishes", "Берегите сон сегодня", "Там завершается восстановление после силовой")
                ]
                return playbookOnlyOutput(
                    hero: postHero,
                    assessment: holisticAssessment(frame: frame, tactical: postAssessment),
                    situation: situation,
                    primary: postPrimary,
                    avoidance: avoidance,
                    extras: postExtras,
                    reasons: []
                )
            }
            return output(frame: frame, hero: hero, assessment: assessment, situation: situation, primary: primary, avoidance: avoidance, extras: extras)
        }

        private static func racket(_ frame: CoachV4DecisionFrame) -> CoachV4PlaybookOutput {
            if frame.sessionPhase == .pre {
                return preSession(frame)
            }

            let hero = CoachFinalStoryBuilder.dynamicText("Control the court load", russian: "На корте лучше держать нагрузку под контролем")
            let assessment = CoachFinalStoryBuilder.dynamicText("Racket sessions can become hard through repeated accelerations.", russian: "Игра может стать тяжёлой из-за постоянных ускорений.")
            let situation = CoachFinalStoryBuilder.dynamicText("Keep movement sharp without chasing every extra point.", russian: "Движение резкое, но не гонитесь за каждым лишним очком.")
            let primary = action(.controlIntensity, "Cap repeated sprints", "Keep the hardest rallies selective", "Повторные рывки лучше ограничить", "Выбирайте самые тяжёлые розыгрыши")
            let avoidance = CoachFinalStoryBuilder.dynamicText("Do not let competition override recovery.", russian: "Азарт не должен перебить восстановление.")
            return output(frame: frame, hero: hero, assessment: assessment, situation: situation, primary: primary, avoidance: avoidance, extras: [])
        }

        private static func output(
            frame: CoachV4DecisionFrame,
            hero: CoachFinalStoryText,
            assessment: CoachFinalStoryText,
            situation: CoachFinalStoryText,
            primary: CoachActionRecommendation,
            avoidance: CoachFinalStoryText,
            extras: [CoachActionRecommendation]
        ) -> CoachV4PlaybookOutput {
            let actions = CoachFinalStoryBuilder.dedupedRecommendations([primary] + extras + frame.actions)
            return CoachV4PlaybookOutput(
                hero: hero,
                assessment: holisticAssessment(frame: frame, tactical: assessment),
                situation: situation,
                primaryAction: primary,
                avoidance: avoidance,
                actions: actions,
                reasons: defaultReasons(frame)
            )
        }

        private static func playbookOnlyOutput(
            hero: CoachFinalStoryText,
            assessment: CoachFinalStoryText,
            situation: CoachFinalStoryText,
            primary: CoachActionRecommendation,
            avoidance: CoachFinalStoryText,
            extras: [CoachActionRecommendation],
            reasons: [CoachV4Reason]
        ) -> CoachV4PlaybookOutput {
            let actions = CoachFinalStoryBuilder.dedupedRecommendations(extras)
            return CoachV4PlaybookOutput(
                hero: hero,
                assessment: assessment,
                situation: situation,
                primaryAction: primary,
                avoidance: avoidance,
                actions: actions,
                reasons: reasons
            )
        }

        private static func preSessionReasons(_ frame: CoachV4DecisionFrame) -> [CoachV4Reason] {
            var reasons: [CoachV4Reason] = []

            if frame.dayLoadContext.timeToNextImportantSession == .under15Minutes {
                reasons.append(reason(.time, "Start is almost here.", "Старт уже на носу.", icon: "clock.fill", colorFamily: .ready))
            } else if let minutes = frame.dayLoadContext.hoursUntilNextImportantActivity.map({ Int(($0 * 60).rounded()) }) {
                let timeCopy = timeUntilStartReason(minutes: max(minutes, 1))
                reasons.append(reason(.time, timeCopy.english, timeCopy.russian, icon: "clock.fill", colorFamily: .ready))
            }

            if frame.primaryLimiter == .recovery {
                reasons.append(reason(.recovery, "Recovery is the limiting factor today.", "Сегодня лучше не перегружаться.", icon: "heart.fill", colorFamily: .recovery))
            } else {
                reasons.append(reason(.recovery, "Recovery looks good enough for the planned session.", "Сегодня самочувствие позволяет идти по плану.", icon: "heart.fill", colorFamily: .recovery))
            }

            return reasons
        }

        private static func timeUntilStartReason(minutes: Int) -> (english: String, russian: String) {
            CoachNaturalTimePhrase.untilStart(minutes: minutes)
        }

        private static func defaultReasons(_ frame: CoachV4DecisionFrame) -> [CoachV4Reason] {
            if frame.storyOwner == .readiness || frame.storyOwner == .stableOverview {
                return stableOverviewReasons(frame)
            }

            if frame.sessionPhase == .post,
               frame.activityClass == .heat || frame.activityFamily == .sauna {
                return heatPostReasons(frame)
            }

            var reasons: [CoachV4Reason] = []

            if frame.activityClass == .heat || frame.activityFamily == .sauna {
                if frame.sessionPhase == .pre,
                   let minutes = frame.dayLoadContext.hoursUntilNextImportantActivity.map({ Int(($0 * 60).rounded()) }) {
                    reasons.append(reason(.time, "Sauna starts in about \(max(minutes, 1)) minutes.", "До сауны осталось примерно \(max(minutes, 1)) минут.", icon: "clock.fill", colorFamily: .ready))
                } else {
                    reasons.append(
                        frame.storyOwner == .tomorrowProtection
                            ? reason(.constraint, "Heat adds stress before tomorrow's session.", "Тепло добавляет стресс перед завтрашней тренировкой.", icon: "flame.fill", colorFamily: .warning)
                            : reason(.training, "Heat is the main stressor in this block.", "В этом блоке главное — тепло.", icon: "flame.fill", colorFamily: .activity)
                    )
                }
                reasons.append(
                    frame.storyOwner == .tomorrowProtection
                        ? reason(.constraint, "Going in underhydrated would make tomorrow harder.", "Если зайти без воды, завтра будет тяжелее.", icon: "drop.fill", colorFamily: .warning)
                        : reason(.hydration, "Hydration matters before heat exposure.", "Перед теплом важно попить воды.", icon: "drop.fill", colorFamily: .hydration)
                )
                if frame.primaryLimiter == .sleep || frame.primaryLimiter == .recovery {
                    reasons.append(reason(.sleep, "Sleep was shorter than usual.", "Сон был короче обычного.", icon: "moon.fill", colorFamily: .recovery))
                } else {
                    reasons.append(reason(.recovery, "You're recovered enough for a light sauna.", "Сил хватает для умеренной сауны.", icon: "heart.fill", colorFamily: .recovery))
                }
                return Array(reasons.prefix(3))
            }

            if frame.dayLoadContext.completedSeriousTrainingToday {
                reasons.append(reason(.training, "You already did the main workout today.", "Главная тренировка сегодня уже была.", icon: "checkmark.circle.fill", colorFamily: .activity))
            }

            if frame.dayLoadContext.shouldProtectTomorrow {
                reasons.append(
                    activeOwnerAllowsOnlyExecutionReasons(frame)
                        ? reason(.constraint, "Tomorrow's training demand reduces today's margin.", "Завтра тяжёлая тренировка — сегодня сохраните силы.", icon: "calendar", colorFamily: .warning)
                        : reason(.tomorrow, "Tomorrow has a hard session waiting.", "Завтра ждёт серьёзная тренировка.", icon: "calendar", colorFamily: .activity)
                )
            } else if frame.dayLoadContext.nextImportantActivityToday != nil {
                reasons.append(reason(.training, "Your next session is still ahead.", "Следующая тренировка ещё впереди.", icon: "figure.run", colorFamily: .activity))
            }

            switch frame.primaryLimiter {
            case .recovery:
                reasons.append(reason(.recovery, "Recovery is holding back how much you can do today.", "Сегодня лучше не перегружаться.", icon: "heart.fill", colorFamily: .recovery))
            case .sleep:
                reasons.append(reason(.sleep, "You didn't sleep enough last night.", "Прошлой ночью вы недоспали.", icon: "moon.fill", colorFamily: .recovery))
            case .hydration:
                reasons.append(reason(.hydration, "You're low on water for this session.", "Воды маловато для этой тренировки.", icon: "drop.fill", colorFamily: .hydration))
            case .fueling:
                reasons.append(reason(.fuel, "You haven't eaten enough for this session.", "Еды маловато для этой тренировки.", icon: "bolt.fill", colorFamily: .fuel))
            default:
                reasons.append(reason(.recovery, "Recovery looks good enough to keep going.", "Самочувствие нормальное — можно спокойно продолжать.", icon: "heart.fill", colorFamily: .recovery))
            }

            if frame.dayLoadContext.caloriesBurnedSoFar >= 700 {
                reasons.append(reason(.constraint, "The day already carries a noticeable energy cost.", "Сегодня уже было достаточно тяжело.", icon: "flame.fill", colorFamily: .warning))
            } else if reasons.count < 3 {
                reasons.append(
                    frame.storyOwner == .tomorrowProtection || activeOwnerAllowsOnlyExecutionReasons(frame)
                        ? reason(.constraint, "Extra load today would not help tomorrow.", "Сегодня лишнее не поможет завтра.", icon: "shield.fill", colorFamily: .warning)
                        : reason(.stability, "No need to add extra work today.", "Сегодня не нужно добавлять лишнего.", icon: "shield.fill", colorFamily: .stable)
                )
            }

            return Array(reasons.prefix(3))
        }

        private static func stableOverviewReasons(_ frame: CoachV4DecisionFrame) -> [CoachV4Reason] {
            var reasons: [CoachV4Reason] = []
            let heroEnglish = frame.hero.fallback.lowercased()
            let heroRussian = frame.hero.russianFallback.lowercased()
            let heroNamesUpcomingPlan = heroEnglish.contains("plan starts with") ||
                heroEnglish.contains("next up is") ||
                heroRussian.contains("плану начинается") ||
                heroRussian.contains("дальше по плану")
            let calmDay = frame.trainPermission == .noActionNeeded
            let recovery = frame.dayLoadContext.recoveryPercent
            let sleepHours = frame.dayLoadContext.sleepHours
            let moderateRecovery = recovery >= 60 && recovery < 75
            let sleepDeficit = hasSleepDeficitEvidence(sleepHours: sleepHours)
            let lateEveningWindDown = isLateEveningWindDownPhase(frame.timePhase)
            let hasWorkoutContext = frame.dayLoadContext.nextImportantActivityToday != nil ||
                frame.dayLoadContext.completedSeriousTrainingToday ||
                frame.dayLoadContext.shouldProtectTomorrow

            if moderateRecovery && calmDay && !hasWorkoutContext {
                if sleepHours >= 6.0 {
                    reasons.append(
                        reason(
                            .sleep,
                            "Sleep quality supported recovery overnight.",
                            "Качество сна помогло восстановиться за ночь.",
                            icon: "moon.fill",
                            colorFamily: .recovery
                        )
                    )
                }
                reasons.append(
                    reason(
                        .recovery,
                        "HRV and resting heart rate suggest your body is still finishing recovery.",
                        "HRV и пульс покоя говорят, что тело ещё завершает восстановление.",
                        icon: "waveform.path.ecg",
                        colorFamily: .recovery
                    )
                )
            } else if calmDay && !hasWorkoutContext && !sleepDeficit && lateEveningWindDown && recovery >= 75 {
                reasons.append(
                    reason(
                        .recovery,
                        "Recovery was strong enough for a normal day.",
                        "Восстановления хватило на обычный день.",
                        icon: "heart.fill",
                        colorFamily: .recovery
                    )
                )
                reasons.append(
                    reason(
                        .time,
                        "Late evening is better used for sleep protection than extra load.",
                        "Поздний вечер лучше использовать для защиты сна, а не для нагрузки.",
                        icon: "moon.fill",
                        colorFamily: .recovery
                    )
                )
            } else {
                switch frame.primaryLimiter {
                case .sleep where sleepDeficit:
                    reasons.append(reason(.sleep, "You didn't sleep enough last night.", "Прошлой ночью вы недоспали.", icon: "moon.fill", colorFamily: .recovery))
                case .recovery where moderateRecovery:
                    reasons.append(reason(.recovery, "Recovery looks reasonable today.", "Сегодня самочувствие выглядит нормальным.", icon: "heart.fill", colorFamily: .recovery))
                case .recovery:
                    reasons.append(reason(.recovery, "Recovery is holding back how much you can do today.", "Сегодня лучше не перегружаться.", icon: "heart.fill", colorFamily: .recovery))
                case .hydration where hasWorkoutContext:
                    reasons.append(reason(.hydration, "You're low on water for this session.", "Воды маловато для этой тренировки.", icon: "drop.fill", colorFamily: .hydration))
                case .fueling where !calmDay && hasWorkoutContext:
                    reasons.append(reason(.fuel, "You haven't eaten enough for this session.", "Еды маловато для этой тренировки.", icon: "bolt.fill", colorFamily: .fuel))
                default:
                    reasons.append(reason(.recovery, "Recovery looks good enough to keep going.", "Самочувствие нормальное — можно спокойно продолжать.", icon: "heart.fill", colorFamily: .recovery))
                }

                if reasons.isEmpty {
                    reasons.append(reason(.recovery, "Recovery looks good enough to keep going.", "Самочувствие нормальное — можно спокойно продолжать.", icon: "heart.fill", colorFamily: .recovery))
                }
            }

            if frame.dayLoadContext.shouldProtectTomorrow {
                reasons.append(reason(.tomorrow, "Tomorrow has a real training demand.", "Завтра серьёзная тренировка.", icon: "calendar", colorFamily: .activity))
            } else if !heroNamesUpcomingPlan,
                      frame.dayLoadContext.nextImportantActivityToday != nil {
                reasons.append(reason(.training, "Your next session is still ahead.", "Следующая тренировка ещё впереди.", icon: "figure.run", colorFamily: .activity))
            }

            if !calmDay,
               hasWorkoutContext,
               reasons.count < 2 {
                reasons.append(reason(.stability, "No need to add extra work today.", "Сегодня не нужно добавлять лишнего.", icon: "shield.fill", colorFamily: .stable))
            }

            return Array(reasons.prefix(calmDay ? 2 : 3))
        }

        private static func heatPostReasons(_ frame: CoachV4DecisionFrame) -> [CoachV4Reason] {
            var reasons: [CoachV4Reason] = []
            if let summary = frame.dayLoadContext.todayPlanSummary,
               let completed = CoachDayPlanReadBuilder.completedDayClause(summary) {
                reasons.append(reason(.time, completed.english, completed.russian, icon: "calendar", colorFamily: .stable))
            }
            reasons.append(reason(.hydration, "Drink water slowly after the heat.", "После тепла попейте воды небольшими глотками.", icon: "drop.fill", colorFamily: .hydration))
            if let summary = frame.dayLoadContext.todayPlanSummary,
               let remaining = CoachDayPlanReadBuilder.remainingDayClause(summary) {
                reasons.append(reason(.training, remaining.english, remaining.russian, icon: "figure.run", colorFamily: .activity))
            } else if frame.dayLoadContext.recoveryPercent > 0 && frame.dayLoadContext.recoveryPercent < 70 {
                reasons.append(reason(.recovery, "You're still catching up after the heat.", "После тепла вы ещё восстанавливаете.", icon: "heart.fill", colorFamily: .recovery))
            } else {
                reasons.append(reason(.recovery, "Take it easy next — no need for more load.", "Дальше лучше спокойно — лишняя нагрузка не нужна.", icon: "heart.fill", colorFamily: .recovery))
            }
            return Array(reasons.prefix(3))
        }

        private static func activeOwnerAllowsOnlyExecutionReasons(_ frame: CoachV4DecisionFrame) -> Bool {
            switch frame.storyOwner {
            case .activeActivity, .pacingExecution, .sustainableExecution, .fuelingDuringActivity, .hydrationExecution:
                return true
            default:
                return false
            }
        }

        private static func reason(
            _ kind: CoachFinalStoryReason.Kind,
            _ english: String,
            _ russian: String,
            icon: String,
            colorFamily: CoachFinalStoryColorFamily
        ) -> CoachV4Reason {
            CoachV4Reason(
                kind: kind,
                english: english,
                russian: russian,
                icon: icon,
                colorFamily: colorFamily
            )
        }

        private static func recoveryExtras(_ frame: CoachV4DecisionFrame) -> [CoachActionRecommendation] {
            var actions: [CoachActionRecommendation] = [
                action(.controlIntensity, "Keep effort comfortable", "No hard blocks", "Держите всё комфортно", "Без тяжёлых отрезков")
            ]
            if frame.dayLoadContext.shouldProtectUpcomingSession {
                actions.append(action(.stayConsistent, "Save energy for later", "Keep this from costing the next session", "Сохраните силы на потом", "Не забирайте силы у следующей тренировки"))
            }
            if frame.dayLoadContext.shouldProtectTomorrow || frame.timePhase == .evening || frame.timePhase == .lateEvening {
                actions.append(action(.sleepPriority, "Keep the evening calm", "Let recovery do the work", "Вечер лучше спокойный", "Пусть тело отдохнёт"))
            }
            return actions
        }

        private static func saunaExtras(_ frame: CoachV4DecisionFrame) -> [CoachActionRecommendation] {
            var actions = [
                action(.steadyHydration, "Sip to comfort", "Do not drink everything at once", "Попейте до комфорта", "Не выпивайте всё залпом")
            ]
            if frame.dayLoadContext.shouldProtectTomorrow || frame.primaryLimiter == .recovery {
                actions.append(action(.sleepPriority, "Protect sleep tonight", "Keep heat and evening stress low", "Берегите сон сегодня", "Тепло и вечерний стресс лучше ниже"))
            }
            return actions
        }

        private static func enduranceExtras(_ frame: CoachV4DecisionFrame) -> [CoachActionRecommendation] {
            var actions: [CoachActionRecommendation] = []
            if frame.sessionPhase == .pre && frame.durationBand != .shortUnder60 {
                actions.append(action(.hydrateBeforeSession, "Drink 300-500 ml water", "Over the next hour", "Попейте воды воды", "В ближайший час, без залпа"))
            }
            if frame.sessionPhase == .during && frame.durationBand != .shortUnder60 {
                actions.append(action(.sustainEnergy, "Take carbs every 20-30 minutes", "Use a schedule, not hunger", "Еда по графику, не по голоду", "По расписанию, не когда уже голоден"))
            }
            if frame.sessionPhase == .post && (frame.durationBand == .longOver120 || frame.dayLoadContext.caloriesBurnedSoFar >= 750) {
                actions.append(action(.rehydrateGradually, "Drink 500-750 ml fluid", "During the next hour", "Постепенно попейте воды", "В ближайший час, без залпа"))
                actions.append(action(.sleepPriority, "Make sleep part of recovery", "Tonight matters after endurance work", "Сон сегодня — часть восстановления", "Сегодня ночью"))
            }
            return actions
        }

        private static func recoveryFamilyName(_ family: CoachV4ActivityFamily) -> (english: String, russian: String) {
            switch family {
            case .breathing:
                return ("breathing", "дыхание")
            case .stretching:
                return ("stretching", "растяжка")
            case .yoga:
                return ("yoga", "йога")
            case .mobility:
                return ("mobility", "мобильность")
            case .walk:
                return ("walk", "прогулка")
            default:
                return ("recovery work", "лёгкая активность")
            }
        }

        private static func capitalized(_ value: String) -> String {
            guard let first = value.first else { return value }
            return first.uppercased() + value.dropFirst()
        }

        private static func action(
            _ type: CoachSupportActionTypeV3,
            _ englishTitle: String,
            _ englishSubtitle: String,
            _ russianTitle: String,
            _ russianSubtitle: String
        ) -> CoachActionRecommendation {
            CoachActionRecommendation(
                type: type,
                englishTitle: englishTitle,
                englishSubtitle: englishSubtitle,
                russianTitle: russianTitle,
                russianSubtitle: russianSubtitle
            )
        }
    }

    private static func humanStory(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        titleFallback: CoachFinalStoryText,
        whatHappenedFallback: CoachFinalStoryText,
        whatToDoNextFallback: CoachFinalStoryText,
        whatToAvoidFallback: CoachFinalStoryText
    ) -> HumanStory {
        let title = humanTitle(owner: owner, input: input, guidance: guidance, fallback: titleFallback)
        let happened = whatHappenedText(owner: owner, input: input, guidance: guidance, fallback: whatHappenedFallback)
        let matters = whatMattersNowText(owner: owner, input: input, guidance: guidance, fallback: happened)
        let next = whatToDoNextText(owner: owner, input: input, guidance: guidance, fallback: whatToDoNextFallback)
        let avoid = whatToAvoidText(owner: owner, input: input, guidance: guidance, fallback: whatToAvoidFallback)

        return HumanStory(
            title: title,
            whatHappened: happened,
            whatMattersNow: matters,
            whatToDoNext: next,
            whatToAvoid: avoid
        )
    }

    private static func coachActionText(_ recommendation: CoachActionRecommendation) -> CoachFinalStoryText {
        let englishSubtitle = recommendation.englishSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let russianSubtitle = recommendation.russianSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let english = englishSubtitle.isEmpty
            ? recommendation.englishTitle
            : "\(recommendation.englishTitle). \(englishSubtitle)."
        let russian = russianSubtitle.isEmpty
            ? recommendation.russianTitle
            : "\(recommendation.russianTitle). \(russianSubtitle)."
        return dynamicText(english, russian: russian)
    }

    private static func localizedTitle(_ recommendation: CoachActionRecommendation) -> String {
        localizedAction(english: recommendation.englishTitle, russian: recommendation.russianTitle)
    }

    private static func localizedSubtitle(_ recommendation: CoachActionRecommendation) -> String {
        localizedAction(english: recommendation.englishSubtitle, russian: recommendation.russianSubtitle)
    }

    private static func humanTitle(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        fallback: CoachFinalStoryText
    ) -> CoachFinalStoryText {
        if usesCoachV4DecisionFrame(input: input, guidance: guidance) {
            return coachV4DecisionFrame(owner: owner, input: input, guidance: guidance).hero
        }

        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeAfterOverload, .activeSleepRisk:
                return dynamicText("I would not continue today.", russian: "Сегодня лучше не продолжать.")
            case .activeRecoveryOnly:
                return dynamicText("Use this only to cool down.", russian: "Это только как заминка.")
            case .activeWithCaution:
                return dynamicText("Keep this session controlled.", russian: "Эту тренировку лучше держать под контролем.")
            case .normalActive:
                return dynamicText("Settle the first block.", russian: "Начните спокойно.")
            }
        }

        if owner == .postActivityRecovery {
            return dynamicText("Protect today's work", russian: "День лучше закрыть на восстановление")
        }

        if owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance) {
            if isHeatActivity(activity) {
                return dynamicText("Make sauna easier", russian: "Сауну лучше сделать легче")
            }
            let name = localizedActivityName(for: activity, grammaticalCase: .dative)
            return dynamicText(
                "Prepare for \(name.english)",
                russian: "Постарайтесь подготовиться к \(name.russian)"
            )
        }

        if owner == .tomorrowProtection,
           let activity = tomorrowProtectionActivity(input: input, guidance: guidance) {
            let labels = enduranceDisplayLabels(for: activity)
            return dynamicText(
                "Protect tomorrow's \(labels.english)",
                russian: "Сохраните силы на завтрашний \(labels.russian)"
            )
        }

        return fallback
    }

    private static func whatHappenedText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        fallback: CoachFinalStoryText
    ) -> CoachFinalStoryText {
        if usesCoachV4DecisionFrame(input: input, guidance: guidance) {
            return coachV4DecisionFrame(owner: owner, input: input, guidance: guidance).assessment
        }

        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeAfterOverload:
                return dynamicText(
                    "Today's load is already high for your current recovery.",
                    russian: "Сегодня уже достаточно тяжело для вашего восстановления."
                )
            case .activeSleepRisk:
                return dynamicText(
                    "Sleep and recovery are the main limits right now.",
                    russian: "Сон и отдых сейчас главные ограничения."
                )
            case .activeRecoveryOnly:
                return dynamicText(
                    "Your current state supports only very light work.",
                    russian: "Сейчас подходит только очень лёгкая работа."
                )
            case .activeWithCaution:
                return dynamicText(
                    "Readiness is not fully reliable, so this should stay controlled.",
                    russian: "Самочувствие не совсем надёжное — тренировку лучше держать под контролем."
                )
            case .normalActive:
                return dynamicText(
                    "Recovery looks stable enough for a controlled \(displayName(activity).lowercased()).",
                    russian: "Самочувствие позволяет контролируемую тренировку."
                )
            }
        }

        if owner == .postActivityRecovery {
            if eveningSleepRecoveryShouldLead(input: input, guidance: guidance) {
                return dynamicText(
                    "Today's main training work is complete.",
                    russian: "Главная тренировка на сегодня завершена."
                )
            }
            if let activity = completedActivity(input: input, guidance: guidance) {
                return completedLoadText(activity: activity, input: input)
            }
            return dynamicText(
                "Today's training already delivered the main load.",
                russian: "Главная тренировка на сегодня уже выполнена."
            )
        }

        if owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance) {
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            if kind == .heat {
                return dynamicText(
                    minutesUntil(activity, from: input.now).map { $0 <= 30 } == true
                        ? "Sauna is soon, and water is low."
                        : "Sauna is later today, and water is low.",
                    russian: minutesUntil(activity, from: input.now).map { $0 <= 30 } == true
                        ? "До сауны мало времени, а воды пока мало."
                        : "Сауна сегодня позже, а воды пока мало."
                )
            }
            let isLong = kind == .endurance || activity.effectiveDurationMinutes >= 75
            let name = displayName(activity).lowercased()
            return dynamicText(
                isLong ? "A long \(name) is coming soon." : "\(displayName(activity)) is coming soon.",
                russian: "Скоро начнётся главная тренировка дня."
            )
        }

        if owner == .tomorrowProtection,
           let activity = tomorrowProtectionActivity(input: input, guidance: guidance) {
            let labels = enduranceDisplayLabels(for: activity)
            let duration = activity.effectiveDurationMinutes
            return dynamicText(
                "Tomorrow has a \(duration)-minute \(labels.english) planned.",
                russian: "Завтра запланирован \(labels.russian) на \(duration) минут."
            )
        }

        if (owner == .readiness || owner == .stableOverview) && recoveryLooksStrong(input) {
            return dynamicText(
                "Your body is in a good place today.",
                russian: "Сегодня вы в хорошем состоянии."
            )
        }

        if let read = specificText(guidance.screenStory?.myRead) {
            return dynamicText(read, russian: fallback.russianFallback)
        }

        return fallback
    }

    private static func whatMattersNowText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        fallback: CoachFinalStoryText
    ) -> CoachFinalStoryText {
        if usesCoachV4DecisionFrame(input: input, guidance: guidance) {
            return coachV4DecisionFrame(owner: owner, input: input, guidance: guidance).situation
        }

        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeSleepRisk:
                return dynamicText(
                    "This is not the moment to add intensity; sleep is the useful lever now.",
                    russian: "Сейчас не время добавлять интенсивность — главное сон."
                )
            case .activeAfterOverload:
                return dynamicText(
                    "The training load is already high; more work will cost more than it gives.",
                    russian: "Уже достаточно тяжело — дополнительная тренировка даст меньше, чем заберёт."
                )
            case .activeRecoveryOnly:
                return dynamicText(
                    "This can help recovery only if it stays very easy.",
                    russian: "Для восстановления всё должно оставаться лёгким."
                )
            case .activeWithCaution:
                return dynamicText(
                    "Use the first minutes to check readiness, not to chase intensity.",
                    russian: "Начните плавно и оцените свои ощущения."
                )
            case .normalActive:
                return dynamicText(
                    "Pace it well instead of adding extra goals.",
                    russian: "Ровный темп лучше, чем лишние цели."
                )
            }
        }

        if owner == .postActivityRecovery {
            if eveningSleepRecoveryShouldLead(input: input, guidance: guidance) {
                return dynamicText(
                    "Recovery now depends mostly on the evening and sleep.",
                    russian: "Сейчас главный приоритет — сон и отдых"
                )
            }
            return dynamicText(
                "Recovery is the objective now: absorb the load and keep the benefit.",
                russian: "Тренировка сделала своё — отдых завершит работу."
            )
        }

        if owner == .activityPreparation {
            if let activity = upcomingActivity(input: input, guidance: guidance),
               isHeatActivity(activity) {
                return dynamicText(
                    "Do not go in dry; make it lighter.",
                    russian: "Без воды лучше не заходить — постарайтесь сделать легче."
                )
            }
            return dynamicText(
                "Start controlled so the session stays useful.",
                russian: "Начните спокойно, чтобы всё осталось полезным."
            )
        }

        if owner == .tomorrowProtection,
           let activity = tomorrowProtectionActivity(input: input, guidance: guidance) {
            let labels = enduranceDisplayLabels(for: activity)
            return dynamicText(
                "Tonight should make tomorrow's \(labels.english) easier to start.",
                russian: "Сегодняшний вечер должен облегчить завтрашний \(labels.russian)."
            )
        }

        if owner == .readiness || owner == .stableOverview {
            return dynamicText(
                "Keep the day consistent.",
                russian: "Ровный ритм до конца дня."
            )
        }

        if let why = specificText(guidance.screenStory?.whyThisMatters ?? guidance.priority.whyThisMatters) {
            return dynamicText(why, russian: fallback.russianFallback)
        }

        return fallback
    }

    private static func whatToDoNextText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        fallback: CoachFinalStoryText
    ) -> CoachFinalStoryText {
        if let actionText = primaryCoachActionText(owner: owner, input: input, guidance: guidance) {
            return actionText
        }

        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeSleepRisk:
                return dynamicText(
                    "Keep it short or stop, then protect sleep.",
                    russian: "Сейчас сон важнее нагрузки."
                )
            case .activeAfterOverload:
                return dynamicText(
                    "Stay consistent rather than aggressive.",
                    russian: "Стабильно, а не резко."
                )
            case .activeRecoveryOnly:
                return dynamicText(
                    "Keep the effort under control.",
                    russian: "Усилие лучше держать под контролем."
                )
            case .activeWithCaution:
                return dynamicText(
                    "Hold a steady rhythm.",
                    russian: "Сохраняйте ровный ритм."
                )
            case .normalActive:
                return dynamicText(
                    "Keep the effort under control.",
                    russian: "Усилие лучше держать под контролем."
                )
            }
        }

        if owner == .postActivityRecovery {
            if eveningSleepRecoveryShouldLead(input: input, guidance: guidance) {
                return dynamicText(
                    "Keep the rest of the day calm.",
                    russian: "Остаток дня лучше спокойный."
                )
            }
            return dynamicText(
                "Give your body time to start recovering.",
                russian: "Дайте телу начать восстановление."
            )
        }

        if owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance) {
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            if kind == .heat {
                return dynamicText(
                    "Sip 300-500 ml, keep sauna light, and do not drink it all at once.",
                    russian: "Попейте воды небольшими глотками, сауну легче и воду не залпом."
                )
            }
            if kind == .endurance || activity.effectiveDurationMinutes >= 75 {
                return dynamicText(
                    "Take quick carbs and drink a small amount before the start, then keep the first 15 minutes easy.",
                    russian: "Перед стартом — еда и вода, первые минуты легко."
                )
            }
            return dynamicText(
                "Start easy and let your body settle into the session.",
                russian: "Начните спокойно и дайте телу войти в работу."
            )
        }

        if owner == .tomorrowProtection,
           tomorrowProtectionActivity(input: input, guidance: guidance) != nil {
            return dynamicText(
                "Save your energy for tomorrow's work.",
                russian: "Сохраните силы на завтра."
            )
        }

        if owner == .stableOverview || owner == .readiness ||
            owner == .recovery && recoveryLooksStrong(input) {
            return dynamicText("Leave the plan unchanged today.", russian: "Сегодня план без изменений.")
        }

        if let action = concreteActionText(guidance) {
            return dynamicText(action, russian: fallback.russianFallback)
        }

        return fallback
    }

    private static func whatToAvoidText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        fallback: CoachFinalStoryText
    ) -> CoachFinalStoryText {
        if usesCoachV4DecisionFrame(input: input, guidance: guidance) {
            return coachV4DecisionFrame(owner: owner, input: input, guidance: guidance).avoidance
        }

        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeSleepRisk:
                return dynamicText(
                    "Do not turn a late evening into another hard session.",
                    russian: "Поздним вечером лучше без ещё одной тяжёлой нагрузки."
                )
            case .activeAfterOverload:
                return dynamicText(
                    "Do not continue building load today.",
                    russian: "Сегодня лучше не наращивать нагрузку."
                )
            case .activeRecoveryOnly:
                return dynamicText(
                    "Do not turn this into training.",
                    russian: "Из этого лучше не делать тренировку."
                )
            case .activeWithCaution:
                return dynamicText(
                    "Do not chase intensity if readiness feels off.",
                    russian: "Не гонитесь за интенсивностью, если самочувствие не надёжное."
                )
            case .normalActive:
                return dynamicText(
                    "Do not rush the opening minutes.",
                    russian: "Не спешите в первые минуты."
                )
            }
        }

        if owner == .tomorrowProtection,
           let activity = tomorrowProtectionActivity(input: input, guidance: guidance) {
            let labels = enduranceDisplayLabels(for: activity)
            return dynamicText(
                "Do not spend tomorrow's \(labels.english) capacity tonight.",
                russian: "Не тратьте сегодня силы на завтрашний \(labels.russian)."
            )
        }

        if owner == .postActivityRecovery {
            if eveningSleepRecoveryShouldLead(input: input, guidance: guidance) {
                return dynamicText(
                    "Do not add another hard effort this evening.",
                    russian: "Вечером лучше без ещё одной тяжёлой нагрузки."
                )
            }
            return dynamicText(
                "Do not add another hard session today.",
                russian: "Сегодня лучше без ещё одной тяжёлой тренировки."
            )
        }

        if owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance),
           CoachActivityContextResolverV3.kind(for: activity) == .endurance || activity.effectiveDurationMinutes >= 75 {
            return dynamicText(
                "Do not chase intensity in the first 15 minutes.",
                russian: "В первые минуты не гонитесь за интенсивностью."
            )
        }

        if !usesCoachV4DecisionFrame(input: input, guidance: guidance),
           owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance),
           isHeatActivity(activity) {
            return dynamicText(
                "Do not drink it all at once.",
                russian: "Воду лучше не догонять одним большим объёмом."
            )
        }

        if owner == .stableOverview || owner == .readiness ||
            owner == .recovery && recoveryLooksStrong(input) {
            return dynamicText(
                "Do not add intensity just because the day looks easy.",
                russian: "Интенсивность лучше не добавлять только потому, что день выглядит лёгким."
            )
        }

        if let avoid = specificText(guidance.avoidNotes.first ?? guidance.screenStory?.beCarefulWith) {
            return dynamicText(avoid, russian: fallback.russianFallback)
        }

        return fallback
    }

    private static func usesCoachV4DecisionFrame(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        true
    }

    private static func coachV4DecisionFrame(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachV4DecisionFrame {
        let timePhase = finalDecisionTimeOfDay(input.now)
        let rawActive = activeActivity(input: input, guidance: guidance) ?? ongoingV4Activity(input: input)
        let active = rawActive.flatMap { activity in
            if isSignificantCoachActivityV4(activity) ||
                isHeatActivity(activity) ||
                coachV4ActivityFamily(for: activity) == .sauna {
                return activity
            }
            if isActive(activity, now: input.now),
               CoachLightRecoveryStableDayPolicy.isLightRecoveryModality(activity) {
                return activity
            }
            return nil
        }
        let upcomingHeat = upcomingV4RecoveryOrHeatActivity(input: input)
        let rawUpcoming = upcomingActivity(input: input, guidance: guidance)
        let upcoming = rawUpcoming.flatMap { isSignificantCoachActivityV4($0) ? $0 : nil } ??
            nextImportantActivityToday(input: input, guidance: guidance)
        let seriousCompleted = recentlyCompletedSeriousTraining(input: input, guidance: guidance)
        let rawLatestCompleted = usesStableDayPlanningFrame(input: input, guidance: guidance)
            ? nil
            : (latestCompletedActivity(input: input, guidance: guidance) ?? latestCompletedV4Activity(input: input))
        let latestCompleted = rawLatestCompleted.flatMap { activity in
            isSignificantCoachActivityV4(activity) ||
                isHeatActivity(activity) ||
                coachV4ActivityFamily(for: activity) == .sauna
                ? activity
                : nil
        }
        let recentPostFocus = recentlyEndedCoachFocusActivity(input)
        let tomorrow = tomorrowProtectionActivity(input: input, guidance: guidance)
        let fallbackSelected = usesStableDayPlanningFrame(input: input, guidance: guidance)
            ? nil
            : selectedCoachActivity(input: input, guidance: guidance).flatMap { isSignificantCoachActivityV4($0) ? $0 : nil }
        let selected = coachV4FrameSelectedActivity(
            input: input,
            guidance: guidance,
            active: active,
            seriousCompleted: seriousCompleted,
            upcoming: upcoming,
            latestCompleted: latestCompleted,
            recentPostFocus: recentPostFocus,
            tomorrow: tomorrow,
            upcomingHeat: upcomingHeat,
            fallbackSelected: fallbackSelected
        )
        let activityClass = selected.map { v4ActivityClass(for: $0) } ?? .none
        let activityFamily = selected.map { coachV4ActivityFamily(for: $0) } ?? .other
        let sessionPhase = coachV4SessionPhase(
            selected: selected,
            active: active,
            upcoming: upcoming ?? upcomingHeat,
            now: input.now,
            latestCompleted: latestCompleted
        )
        let durationBand = selected.map { coachV4DurationBand(for: $0) } ?? .none
        let dayLoadContext = coachV4DayLoadContext(
            input: input,
            guidance: guidance,
            timePhase: timePhase,
            seriousCompleted: seriousCompleted,
            focusActivity: active ?? upcoming ?? seriousCompleted ?? latestCompleted
        )
        let lowRecovery = lowRecoveryOrReadiness(input)
        let sleepDeficitEvidence = hasSleepDeficitEvidence(input)
        let hasTomorrowDemand = input.dayPriorityModel.tomorrowDemand == .hard || owner == .tomorrowProtection
        let hasUpcomingSerious = upcoming.map(isSeriousTraining) == true
        let hasActiveSerious = active.map(isSeriousTraining) == true
        let completedSerious = seriousCompleted != nil

        let focusForFuel = active ?? upcoming ?? selected
        let limiter: CoachLimiter = {
            let contextActivity = active ?? upcoming ?? selected
            if calmDailyOverviewWithoutWorkout(
                input: input,
                guidance: guidance,
                selected: contextActivity
            ),
               !severelyLimitedRecovery(input) {
                if moderateRecoveryScore(input) {
                    if hasVisibleMorningNutritionOrHydrationGap(input) {
                        if CoachLightRecoveryStableDayPolicy.caloriesCriticallyLow(input) {
                            return .fueling
                        }
                        let water = input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters
                        let waterGoal = input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters
                        if water <= 0.05 || ratio(current: water, goal: waterGoal) < 0.10 {
                            return .hydration
                        }
                    }
                    return .none
                }
                if recoveryLooksStrong(input) && !sleepDeficitEvidence {
                    return .none
                }
                if !sleepDeficitEvidence &&
                    !lowRecovery &&
                    isLateEveningWindDown(input) {
                    return .none
                }
            }
            if lowRecovery { return .recovery }
            if sleepDeficitEvidence { return .sleep }
            if completedSerious { return .accumulatedFatigue }
            if hasTomorrowDemand { return .upcomingTraining }
            if fuelingNeedsPreWorkoutAction(input, guidance: guidance, activity: focusForFuel),
               upcoming != nil || active != nil {
                return .fueling
            }
            if hydrationNeedsPreWorkoutAction(input), upcoming != nil || active != nil { return .hydration }
            let baseLimiter = guidance.priority.limiter
            if baseLimiter == .sleep && !sleepDeficitEvidence {
                return .none
            }
            if baseLimiter == .fueling,
               !CoachLightRecoveryStableDayPolicy.shouldShowFuelWarning(
                   input: input,
                   guidance: guidance,
                   activity: focusForFuel
               ) {
                return .none
            }
            return baseLimiter
        }()

        let seriousState: CoachV4SeriousTrainingState = {
            if completedSerious { return .completed }
            if hasActiveSerious { return .active }
            if hasUpcomingSerious { return .upcoming }
            if hasTomorrowDemand { return .tomorrow }
            return .none
        }()
        let proposedStoryOwner = coachV4StoryOwner(
            baseOwner: owner,
            input: input,
            guidance: guidance,
            selected: selected,
            active: active,
            sessionPhase: sessionPhase,
            durationBand: durationBand,
            activityFamily: activityFamily,
            dayLoadContext: dayLoadContext
        )
        let storyOwner = normalizedV4StoryOwner(
            proposedOwner: proposedStoryOwner,
            baseOwner: owner,
            input: input,
            guidance: guidance,
            selected: selected
        )
        let recoveryOnlyCompletionWithoutDeficit = currentOrLastRecoveryTierOnlyActivity(input: input, guidance: guidance) != nil &&
            !recoveryOwnerIsIndependentlyJustified(input: input, guidance: guidance)
        logV4OwnerNormalization(
            source: "coachV4DecisionFrame",
            ownerBefore: proposedStoryOwner,
            ownerAfter: storyOwner,
            baseOwner: owner,
            input: input,
            guidance: guidance,
            selected: selected,
            reasonKinds: []
        )

        let permission: CoachV4TrainPermission = {
            if completedSerious && active.map(isRecoveryActivityV4) != true { return active == nil ? .recoveryOnly : .noTraining }
            if hasTomorrowDemand && (timePhase == .evening || timePhase == .lateEvening || lowRecovery) { return .noTraining }
            if active != nil && lowRecovery { return .trainControlled }
            if upcoming != nil && lowRecovery { return .trainControlled }
            if recoveryOnlyCompletionWithoutDeficit && storyOwner == .stableOverview { return .noActionNeeded }
            if storyOwner == .recovery { return .recoveryOnly }
            if sessionPhase == .post,
               selected.map({ isHeatActivity($0) || coachV4ActivityFamily(for: $0) == .sauna }) == true {
                return .noActionNeeded
            }
            if active == nil && upcoming == nil && !hasTomorrowDemand && !lowRecovery {
                return .noActionNeeded
            }
            if owner == .stableOverview && recoveryLooksStrong(input) && upcoming == nil && !hasTomorrowDemand && input.actualLoad.activeCalories < 500 {
                return .noActionNeeded
            }
            return .train
        }()

        let intensity: CoachV4RecommendedIntensity = {
            switch permission {
            case .noActionNeeded, .noTraining:
                return .none
            case .recoveryOnly:
                return .easy
            case .trainControlled:
                return .reduced
            case .train:
                if active.map(isEnduranceLike) == true { return .conversational }
                return .planned
            }
        }()

        let objective: CoachObjective = {
            switch permission {
            case .noActionNeeded:
                return .completeDay
            case .noTraining:
                return hasTomorrowDemand ? .protectTomorrow : .recoveryDay
            case .recoveryOnly:
                return completedSerious ? .recoverFromActivity : .recoveryDay
            case .trainControlled:
                return active != nil ? .executeActivity : .prepareActivity
            case .train:
                if active != nil { return .executeActivity }
                if upcoming != nil { return .prepareActivity }
                return .buildReadiness
            }
        }()

        let actions = coachV4RankedActions(
            owner: storyOwner,
            input: input,
            guidance: guidance,
            permission: permission,
            seriousTrainingState: seriousState
        )
        let primaryAction = actions.first ?? CoachActionLibrary.noAction(
            reasonEnglish: "No useful change is needed right now",
            reasonRussian: "Сейчас нет полезного изменения"
        )
        let preservesAuthoritativePlanChangeNarrative = authoritativePlanChangeNarrative(guidance: guidance) != nil

        let baseFrame = CoachV4DecisionFrame(
            storyOwner: storyOwner,
            trainPermission: permission,
            recommendedIntensity: intensity,
            objective: objective,
            primaryLimiter: limiter,
            activityClass: activityClass,
            activityFamily: activityFamily,
            sessionPhase: sessionPhase,
            durationBand: durationBand,
            seriousTrainingState: seriousState,
            dayLoadContext: dayLoadContext,
            timePhase: timePhase,
            hero: coachV4HeroText(
                owner: storyOwner,
                input: input,
                guidance: guidance,
                selectedActivity: selected,
                permission: permission,
                seriousTrainingState: seriousState
            ),
            assessment: coachV4AssessmentText(
                owner: storyOwner,
                input: input,
                guidance: guidance,
                selectedActivity: selected,
                seriousCompleted: seriousCompleted,
                limiter: limiter,
                permission: permission
            ),
            situation: coachV4SituationText(
                owner: storyOwner,
                input: input,
                selectedActivity: selected,
                limiter: limiter,
                permission: permission,
                seriousTrainingState: seriousState
            ),
            primaryAction: primaryAction,
            avoidance: coachV4AvoidanceText(
                input: input,
                guidance: guidance,
                selectedActivity: selected,
                limiter: limiter,
                permission: permission,
                seriousTrainingState: seriousState
            ),
            actions: actions,
            reasons: [],
            preservesAuthoritativePlanChangeNarrative: preservesAuthoritativePlanChangeNarrative
        )

        let playbook = CoachV4ActivityPlaybook.resolve(baseFrame)

        return CoachV4DecisionFrame(
            storyOwner: baseFrame.storyOwner,
            trainPermission: baseFrame.trainPermission,
            recommendedIntensity: baseFrame.recommendedIntensity,
            objective: baseFrame.objective,
            primaryLimiter: baseFrame.primaryLimiter,
            activityClass: baseFrame.activityClass,
            activityFamily: baseFrame.activityFamily,
            sessionPhase: baseFrame.sessionPhase,
            durationBand: baseFrame.durationBand,
            seriousTrainingState: baseFrame.seriousTrainingState,
            dayLoadContext: baseFrame.dayLoadContext,
            timePhase: baseFrame.timePhase,
            hero: playbook.hero,
            assessment: playbook.assessment,
            situation: playbook.situation,
            primaryAction: playbook.primaryAction,
            avoidance: playbook.avoidance,
            actions: playbook.actions,
            reasons: playbook.reasons,
            preservesAuthoritativePlanChangeNarrative: baseFrame.preservesAuthoritativePlanChangeNarrative
        )
    }

    private struct AuthoritativePlanChangeNarrative {
        let title: String
        let message: String
    }

    private static func authoritativePlanChangeNarrative(
        guidance: CoachGuidanceV3
    ) -> AuthoritativePlanChangeNarrative? {
        guard let frame = guidance.dayDecisionFrame,
              frame.shouldOwnNarrative,
              frame.planStatus.requiresPlanChange else {
            return nil
        }

        let title = guidance.screenStory?.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let message = guidance.screenStory?.myRead
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = (title?.isEmpty == false ? title : nil) ?? {
            let fallback = frame.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return fallback.isEmpty ? nil : fallback
        }()
        let resolvedMessage = (message?.isEmpty == false ? message : nil) ?? {
            let fallback = frame.diagnosisText.trimmingCharacters(in: .whitespacesAndNewlines)
            return fallback.isEmpty ? nil : fallback
        }()

        guard let resolvedTitle, let resolvedMessage else { return nil }
        return AuthoritativePlanChangeNarrative(title: resolvedTitle, message: resolvedMessage)
    }

    private static func coachV4StoryOwner(
        baseOwner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        selected: PlannedActivity?,
        active: PlannedActivity?,
        sessionPhase: CoachV4SessionPhase,
        durationBand: CoachV4DurationBand,
        activityFamily: CoachV4ActivityFamily,
        dayLoadContext: CoachV4DayLoadContext
    ) -> CoachFinalStoryOwner {
        if let active,
           !active.isCompleted,
           isActive(active, now: input.now),
           baseOwner == .activeActivity || guidance.priority.focus == .activeActivity {
            return baseOwner
        }

        if usesStableDayPlanningFrame(input: input, guidance: guidance) {
            return baseOwner
        }

        let selectedIsSignificant = selected.map(isSignificantCoachActivityV4) == true
        let selectedIsHeat = selected.map { isHeatActivity($0) || coachV4ActivityFamily(for: $0) == .sauna } == true
        let selectedIsTomorrow = selected.map { !Calendar.current.isDate($0.date, inSameDayAs: input.now) } == true
        let recoveryOnlyCompletionWithoutDeficit = currentOrLastRecoveryTierOnlyActivity(input: input, guidance: guidance) != nil &&
            !recoveryOwnerIsIndependentlyJustified(input: input, guidance: guidance)

        if sessionPhase == .during,
           let active,
           !selectedIsSignificant,
           CoachLightRecoveryStableDayPolicy.isLightRecoveryModality(active) {
            return .activeActivity
        }

        if sessionPhase == .during,
           let active,
           selectedIsSignificant {
            if activityFamily == .endurance {
                if dayLoadContext.completedSeriousTrainingToday ||
                    lowRecoveryOrReadiness(input) {
                    return .activeActivity
                }

                let elapsed = activeElapsedMinutes(active, now: input.now)
                let longEnoughForFueling = elapsed >= 90 || durationBand == .longOver120 && elapsed >= 75
                let fuelRisk = enduranceFuelingIsBiggestLimiter(input: input, active: active, elapsedMinutes: elapsed)
                let hydrationRisk = enduranceHydrationIsBiggestLimiter(input: input, active: active, elapsedMinutes: elapsed)

                if longEnoughForFueling && fuelRisk {
                    return .fuelingDuringActivity
                }
                if elapsed >= 45 && hydrationRisk {
                    return .hydrationExecution
                }
                if elapsed < 30 {
                    return .pacingExecution
                }
                return .sustainableExecution
            }

            return .activeActivity
        }

        if sessionPhase == .post,
           selectedIsHeat {
            return .recovery
        }

        if sessionPhase == .post,
           selected.map(isRecoveryActivityV4) == true,
           !selectedIsSignificant {
            return lowRecoveryOrReadiness(input) ? .recovery : .stableOverview
        }

        if sessionPhase == .post,
           selectedIsSignificant {
            return dayLoadContext.shouldProtectTomorrow || baseOwner == .tomorrowProtection
                ? .tomorrowProtection
                : .postActivityRecovery
        }

        if selectedIsTomorrow && (baseOwner == .tomorrowProtection || dayLoadContext.shouldProtectTomorrow) {
            return .tomorrowProtection
        }

        if authoritativePlanChangeNarrative(guidance: guidance) != nil {
            return .readiness
        }

        if sessionPhase == .pre,
           selectedIsSignificant {
            return .activityPreparation
        }

        if baseOwner == .tomorrowProtection || dayLoadContext.shouldProtectTomorrow {
            return .tomorrowProtection
        }

        if recoveryOnlyCompletionWithoutDeficit,
           baseOwner == .recovery || baseOwner == .postActivityRecovery || selected == nil || selected.map(isRecoveryActivityV4) == true {
            return .stableOverview
        }

        if selectedIsHeat {
            switch sessionPhase {
            case .pre:
                return .activityPreparation
            case .during:
                return .activeActivity
            case .post:
                return .recovery
            case .none:
                return baseOwner
            }
        }

        if selected.map(isRecoveryActivityV4) == true {
            return lowRecoveryOrReadiness(input) ? .recovery : .stableOverview
        }

        if baseOwner == .readiness,
           guidance.priority.focus == .trainingReadinessWarning || lowRecoveryOrReadiness(input) {
            return .readiness
        }

        if lowRecoveryOrReadiness(input) {
            return .recovery
        }

        if !recoveryOnlyCompletionWithoutDeficit &&
            (input.dayContext.completedTrainingStressScore >= 2 || input.actualLoad.activeCalories >= 900) {
            return .recovery
        }

        guard selected != nil else {
            return .stableOverview
        }

        return baseOwner
    }

    private static func activeElapsedMinutes(_ activity: PlannedActivity, now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(activity.date) / 60))
    }

    private static func normalizedV4StoryOwner(
        proposedOwner: CoachFinalStoryOwner,
        baseOwner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        selected: PlannedActivity?
    ) -> CoachFinalStoryOwner {
        let recoveryTierActivity = currentOrLastRecoveryTierOnlyActivity(input: input, guidance: guidance)
        let blockedByV4Contract = proposedOwner == .recovery &&
            (isStableDailyOverview(input: input, guidance: guidance) ||
                CoachLightRecoveryStableDayPolicy.shouldForceStableOverview(input: input, guidance: guidance)) &&
            recoveryTierActivity != nil &&
            !hasSignificantWorkoutContext(input: input, guidance: guidance, selected: selected) &&
            !recoveryOwnerIsIndependentlyJustified(input: input, guidance: guidance)

        guard blockedByV4Contract else {
            return proposedOwner
        }

        return baseOwner == .readiness ? .readiness : .stableOverview
    }

    private static func isPriorityStableDailyOverview(_ guidance: CoachGuidanceV3) -> Bool {
        guidance.priority.priority == .stable && guidance.priority.focus == .dailyOverview
    }

    private static func isStableDailyOverview(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        guard isPriorityStableDailyOverview(guidance) else {
            return false
        }
        if case .stable = guidance.phase {
            return true
        }
        return false
    }

    private static func hasSignificantWorkoutContext(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        selected: PlannedActivity?
    ) -> Bool {
        if selected.map(isSignificantCoachActivityV4) == true { return true }
        if activeActivity(input: input, guidance: guidance).map(isSignificantCoachActivityV4) == true { return true }
        if ongoingV4Activity(input: input).map(isSignificantCoachActivityV4) == true { return true }
        if upcomingActivity(input: input, guidance: guidance).map(isSignificantCoachActivityV4) == true { return true }
        if nextImportantActivityToday(input: input, guidance: guidance) != nil { return true }
        if tomorrowProtectionActivity(input: input, guidance: guidance).map(isSignificantCoachActivityV4) == true { return true }
        if recentlyCompletedSeriousTraining(input: input, guidance: guidance) != nil { return true }
        if latestCompletedActivity(input: input, guidance: guidance).map(isSignificantCoachActivityV4) == true { return true }
        return false
    }

    private static func currentOrLastRecoveryTierOnlyActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        completedOrActiveRecoveryTierActivities(input: input, guidance: guidance)
            .sorted { $0.date > $1.date }
            .first
    }

    private static func completedOrActiveRecoveryTierActivities(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> [PlannedActivity] {
        var candidates: [PlannedActivity] = []

        switch guidance.phase {
        case .active(let activity, _),
             .recovering(let activity, _, _),
             .preparing(let activity, _, _):
            if isRecoveryActivityV4(activity), !isSeriousTraining(activity) {
                candidates.append(activity)
            }
        case .stable:
            break
        }

        candidates.append(contentsOf: input.dayContext.completedActivities)
        candidates.append(contentsOf: input.plannedActivities.filter {
            ($0.isCompleted || $0.isActive(at: input.now)) &&
                isRecoveryActivityV4($0) &&
                !isSeriousTraining($0)
        })

        return candidates
            .filter { isRecoveryActivityV4($0) && !isSeriousTraining($0) }
            .filter { $0.isCompleted || $0.isActive(at: input.now) }
    }

    private static func hasCompletedPlannedActivityToday(_ input: CoachInputSnapshot) -> Bool {
        let calendar = Calendar.current
        return input.plannedActivities.contains { activity in
            calendar.isDate(activity.date, inSameDayAs: input.now) &&
                activity.isCompleted &&
                !activity.isSkipped
        }
    }

    private static func nextUpcomingPlanActivityToday(_ input: CoachInputSnapshot) -> PlannedActivity? {
        let calendar = Calendar.current
        return input.plannedActivities
            .filter { activity in
                calendar.isDate(activity.date, inSameDayAs: input.now) &&
                    !activity.isCompleted &&
                    !activity.isSkipped &&
                    activity.date >= input.now
            }
            .sorted { $0.date < $1.date }
            .first
    }

    private static func nextUpcomingRecoveryPlanActivity(_ input: CoachInputSnapshot) -> PlannedActivity? {
        let calendar = Calendar.current
        return input.plannedActivities
            .filter { activity in
                calendar.isDate(activity.date, inSameDayAs: input.now) &&
                    !activity.isCompleted &&
                    !activity.isSkipped &&
                    activity.date >= input.now &&
                    (isRecoveryActivityV4(activity) ||
                        isHeatActivity(activity) ||
                        coachV4ActivityFamily(for: activity) == .sauna)
            }
            .sorted { $0.date < $1.date }
            .first
    }

    private static func usesStableDayPlanningFrame(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        stableDayPlanningOverviewContext(guidance) ||
            stableDayOverviewWithoutAcknowledgedTraining(input: input, guidance: guidance) ||
            completedRecoveryDayOverviewContext(input: input, guidance: guidance)
    }

    private static func completedRecoveryDayOverviewContext(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        guard isPriorityStableDailyOverview(guidance) || guidance.priority.focus == .dailyOverview else {
            return false
        }
        guard let summary = CoachDayPlanReadBuilder.build(input: input) else { return false }
        guard !summary.hasRemainingToday else { return false }
        guard summary.completedLabels.count >= 2 else { return false }
        let phase = finalDecisionTimeOfDay(input.now)
        guard phase == .afternoon || phase == .evening || phase == .lateEvening || phase == .night else {
            return false
        }
        return !hasCompletedPlannedSeriousTrainingToday(input)
    }

    private static func resolvedLatestCompletedActivity(
        _ latestCompleted: PlannedActivity?,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        guard let latestCompleted else { return nil }
        if isPostHeatFocusActivity(latestCompleted),
           !shouldFocusRecentPostSession(latestCompleted, input: input, guidance: guidance) {
            return nil
        }
        return latestCompleted
    }

    private static func coachV4FrameSelectedActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        active: PlannedActivity?,
        seriousCompleted: PlannedActivity?,
        upcoming: PlannedActivity?,
        latestCompleted: PlannedActivity?,
        recentPostFocus: PlannedActivity?,
        tomorrow: PlannedActivity?,
        upcomingHeat: PlannedActivity?,
        fallbackSelected: PlannedActivity?
    ) -> PlannedActivity? {
        if let active {
            return active
        }
        if let recentPostFocus,
           isPostHeatFocusActivity(recentPostFocus),
           shouldFocusRecentPostSession(recentPostFocus, input: input, guidance: guidance) {
            return recentPostFocus
        }
        if usesStableDayPlanningFrame(input: input, guidance: guidance) {
            return upcoming ?? upcomingHeat ?? nextUpcomingPlanActivityToday(input) ?? nextUpcomingRecoveryPlanActivity(input)
        }
        if let recentPostFocus,
           shouldFocusRecentPostSession(recentPostFocus, input: input, guidance: guidance) {
            return recentPostFocus
        }
        let resolvedLatestCompleted = resolvedLatestCompletedActivity(
            latestCompleted,
            input: input,
            guidance: guidance
        )
        return seriousCompleted ?? upcoming ?? resolvedLatestCompleted ?? tomorrow ?? upcomingHeat ?? fallbackSelected
    }

    private static func isPostHeatFocusActivity(_ activity: PlannedActivity) -> Bool {
        isHeatActivity(activity) || coachV4ActivityFamily(for: activity) == .sauna
    }

    private static func shouldFocusRecentPostSession(
        _ activity: PlannedActivity,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        let elapsed = minutesSinceCoachActivityEnd(activity, now: input.now)
        guard elapsed <= postSessionFocusMinutes(for: activity) else {
            return false
        }
        if isPostHeatFocusActivity(activity) {
            if elapsed > immediateHeatRehydrationFocusMinutes {
                if let summary = CoachDayPlanReadBuilder.build(input: input) {
                    if summary.hasRemainingToday {
                        return false
                    }
                    if summary.completedLabels.count >= 2 {
                        return false
                    }
                }
                let phase = finalDecisionTimeOfDay(input.now)
                if phase == .afternoon || phase == .evening || phase == .lateEvening || phase == .night {
                    return false
                }
            }
            return true
        }
        if isRecoveryActivityV4(activity) {
            if usesStableDayPlanningFrame(input: input, guidance: guidance) {
                return false
            }
            if let summary = CoachDayPlanReadBuilder.build(input: input), summary.hasRemainingToday {
                return false
            }
            return true
        }
        return false
    }

    private static let immediateHeatRehydrationFocusMinutes = 45

    private static func postSessionFocusMinutes(for activity: PlannedActivity) -> Int {
        if isHeatActivity(activity) || coachV4ActivityFamily(for: activity) == .sauna {
            return 90
        }
        return 45
    }

    private static func minutesSinceCoachActivityEnd(_ activity: PlannedActivity, now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(coachV4EndDate(for: activity)) / 60))
    }

    private static func recentlyEndedCoachFocusActivity(_ input: CoachInputSnapshot) -> PlannedActivity? {
        input.dayContext.completedActivities
            .sorted { coachV4EndDate(for: $0) > coachV4EndDate(for: $1) }
            .first { minutesSinceCoachActivityEnd($0, now: input.now) <= postSessionFocusMinutes(for: $0) }
    }

    private static func hasCompletedPlannedSeriousTrainingToday(_ input: CoachInputSnapshot) -> Bool {
        let calendar = Calendar.current
        return input.plannedActivities.contains { activity in
            calendar.isDate(activity.date, inSameDayAs: input.now) &&
                activity.isCompleted &&
                !activity.isSkipped &&
                isSeriousTraining(activity)
        }
    }

    private static func stableDayPlanningOverviewContext(_ guidance: CoachGuidanceV3) -> Bool {
        isPriorityStableDailyOverview(guidance) && guidance.priority.activity == nil
    }

    private static func stableDayOverviewWithoutAcknowledgedTraining(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        guard isPriorityStableDailyOverview(guidance) else { return false }
        return !hasCompletedPlannedSeriousTrainingToday(input)
    }

    private static func recoveryDayMorningPlanningContext(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        guard isStableDailyOverview(input: input, guidance: guidance) else { return false }
        guard finalDecisionTimeOfDay(input.now) == .morning else { return false }
        guard !hasCompletedPlannedActivityToday(input) else { return false }
        return nextUpcomingRecoveryPlanActivity(input) != nil
    }

    private static func logV4OwnerNormalization(
        source: String,
        ownerBefore: CoachFinalStoryOwner,
        ownerAfter: CoachFinalStoryOwner,
        baseOwner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        selected: PlannedActivity?,
        reasonKinds: [CoachFinalStoryReason.Kind],
        usedFallback: Bool = false,
        fallbackSource: String = "none"
    ) {
        #if DEBUG
        let recoveryTierActivity = currentOrLastRecoveryTierOnlyActivity(input: input, guidance: guidance)
        let hasIndependentRecoveryDeficit = recoveryOwnerIsIndependentlyJustified(input: input, guidance: guidance)
        let blockedByV4Contract = ownerBefore == .recovery &&
            ownerAfter != .recovery &&
            isStableDailyOverview(input: input, guidance: guidance) &&
            recoveryTierActivity != nil &&
            !hasIndependentRecoveryDeficit
        CoachLogger.trace(
            "[CoachV4OwnerContract]",
            [
                "source=\(source)",
                "ownerBefore=\(ownerBefore.rawValue)",
                "ownerAfter=\(ownerAfter.rawValue)",
                "baseOwner=\(baseOwner.rawValue)",
                "priority=\(guidance.priority.priority)/\(guidance.priority.focus)",
                "phase=\(guidance.phase)",
                "activity=\(recoveryTierActivity?.title ?? selected?.title ?? "nil")",
                "activityState=\(recoveryTierActivity?.isCompleted == true ? "completed" : selected?.isCompleted == true ? "completed" : "unknown")",
                "reasonKinds=\(reasonKinds.map(\.rawValue).joined(separator: ","))",
                "isRecoveryTierActivity=\(recoveryTierActivity != nil)",
                "hasIndependentRecoveryDeficit=\(hasIndependentRecoveryDeficit)",
                "usedFallback=\(usedFallback)",
                "fallbackSource=\(fallbackSource)",
                "blockedByV4Contract=\(blockedByV4Contract)"
            ].joined(separator: " ")
        )
        #endif
    }

    private static func enduranceFuelingIsBiggestLimiter(
        input: CoachInputSnapshot,
        active: PlannedActivity,
        elapsedMinutes: Int
    ) -> Bool {
        let caloriesBurned = max(input.actualLoad.activeCalories, input.brain.metrics.activeCalories)
        let caloriesConsumed = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
        let carbs = input.nutritionContext?.carbsCurrent ?? input.brain.metrics.carbs
        let energyDeficit = caloriesBurned - caloriesConsumed
        return elapsedMinutes >= 90 &&
            (energyDeficit >= 500 || caloriesBurned >= 1_200 && caloriesConsumed < 0.70 * caloriesBurned || carbs < 80) &&
            active.effectiveDurationMinutes >= 90
    }

    private static func enduranceHydrationIsBiggestLimiter(
        input: CoachInputSnapshot,
        active: PlannedActivity,
        elapsedMinutes: Int
    ) -> Bool {
        let water = input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters
        let waterGoal = input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        let ratio = ratio(current: water, goal: waterGoal)
        return elapsedMinutes >= 45 &&
            active.effectiveDurationMinutes >= 75 &&
            (ratio < 0.35 || input.brain.hydration == .depleted)
    }

    private static func coachV4HeroText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        selectedActivity: PlannedActivity?,
        permission: CoachV4TrainPermission,
        seriousTrainingState: CoachV4SeriousTrainingState
    ) -> CoachFinalStoryText {
        if let narrative = authoritativePlanChangeNarrative(guidance: guidance) {
            return dynamicText(narrative.title, russian: narrative.title)
        }

        if owner == .activeActivity,
           let activity = activeActivity(input: input, guidance: guidance) {
            switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
            case .activeAfterOverload, .activeSleepRisk:
                return dynamicText("I would not continue today.", russian: "Сегодня лучше не продолжать.")
            case .activeRecoveryOnly:
                return dynamicText("Use this only to cool down.", russian: "Это только как заминка.")
            case .activeWithCaution:
                return dynamicText("Keep this session controlled.", russian: "Эту тренировку лучше держать под контролем.")
            case .normalActive:
                return dynamicText("Settle the first block.", russian: "Первый отрезок — спокойно.")
            }
        }

        if owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance) {
            if isHeatActivity(activity) {
                return dynamicText("Make sauna easier", russian: "Сауну лучше сделать легче")
            }
            let name = localizedActivityName(for: activity, grammaticalCase: .dative)
            return dynamicText(
                "Prepare for \(name.english)",
                russian: "Постарайтесь подготовиться к \(name.russian)"
            )
        }

        if owner == .tomorrowProtection {
            if let activity = tomorrowProtectionActivity(input: input, guidance: guidance) {
                let labels = enduranceDisplayLabels(for: activity)
                return dynamicText(
                    "Protect tomorrow's \(labels.english)",
                    russian: "Сохраните силы на завтрашний \(labels.russian)"
                )
            }
            return dynamicText("Protect tomorrow's session", russian: "Сохраните силы на завтрашнюю тренировку")
        }
        if owner == .hydration {
            return dynamicText("Hydrate before the day builds", russian: "Начните день с воды")
        }
        if owner == .fuel {
            return dynamicText("Start with fuel this morning", russian: "Утром лучше начать с еды")
        }
        if seriousTrainingState == .completed {
            return dynamicText("Protect today's work", russian: "Закрепите результат дня")
        }
        if permission == .noTraining {
            return dynamicText("Save the work for later", russian: "Сохраните силы на потом")
        }
        if owner == .stableOverview || owner == .readiness,
           let hero = dayPlanOverviewHero(input: input) {
            return hero
        }
        if owner == .stableOverview || owner == .readiness,
           calmDailyOverviewWithoutWorkout(input: input, guidance: guidance, selected: selectedActivity),
           finalDecisionTimeOfDay(input.now) == .morning,
           !hasCompletedPlannedActivityToday(input) {
            if let next = nextUpcomingPlanActivityToday(input) ?? nextUpcomingRecoveryPlanActivity(input) ?? nextImportantActivityToday(input: input, guidance: guidance) {
                let name = localizedActivityName(for: next)
                return dynamicText(
                    "Today's plan starts with \(name.english)",
                    russian: "Сегодня по плану начинается: \(name.russian)"
                )
            }
            return calmMorningHeroText(input)
        }
        if owner == .stableOverview || owner == .readiness,
           isPriorityStableDailyOverview(guidance) {
            if finalDecisionTimeOfDay(input.now) == .morning {
                if hasCompletedPlannedActivityToday(input),
                   let hero = dayPlanOverviewHero(input: input) {
                    return hero
                }
                if let next = nextUpcomingPlanActivityToday(input) ?? nextUpcomingRecoveryPlanActivity(input) ?? nextImportantActivityToday(input: input, guidance: guidance) {
                    let name = localizedActivityName(for: next)
                    return dynamicText(
                        "Today's plan starts with \(name.english)",
                        russian: "Сегодня по плану начинается: \(name.russian)"
                    )
                }
                return calmMorningHeroText(input)
            }
            if let next = nextUpcomingPlanActivityToday(input) ?? nextUpcomingRecoveryPlanActivity(input) ?? nextImportantActivityToday(input: input, guidance: guidance) {
                let name = localizedActivityName(for: next)
                return dynamicText(
                    "Next up is \(name.english)",
                    russian: "Дальше по плану: \(name.russian)"
                )
            }
            return dynamicText("Today's going fine", russian: "День идёт ровно")
        }
        if owner == .stableOverview || owner == .readiness,
           recoveryDayMorningPlanningContext(input: input, guidance: guidance) {
            if let next = nextUpcomingPlanActivityToday(input) ?? nextUpcomingRecoveryPlanActivity(input) {
                let name = localizedActivityName(for: next)
                return dynamicText(
                    "Today's plan starts with \(name.english)",
                    russian: "Сегодня по плану начинается: \(name.russian)"
                )
            }
            return dynamicText("Morning's going fine", russian: "Утро идёт ровно")
        }
        if owner == .stableOverview || owner == .readiness || owner == .recovery,
           let hero = dayPlanOverviewHero(input: input) {
            return hero
        }
        if let activity = selectedActivity {
            return fallbackHeroText(for: activity, now: input.now)
        }
        if owner == .recovery {
            return recoveryHeroText(input)
        }
        if (owner == .stableOverview || owner == .readiness),
           permission == .noActionNeeded,
           calmDailyOverviewWithoutWorkout(input: input, guidance: guidance, selected: selectedActivity),
           isLateEveningWindDown(input),
           input.recoveryContext.recoveryPercent >= 75,
           !hasSleepDeficitEvidence(input) {
            return dynamicText("Wind the day down", russian: "Завершите день спокойно")
        }
        return dynamicText("Pretty quiet day", russian: "День выглядит достаточно ровно")
    }

    private static func fallbackHeroText(for activity: PlannedActivity, now: Date) -> CoachFinalStoryText {
        let name = displayName(activity).lowercased()
        let label = displayName(activity)
        if CoachLightRecoveryStableDayPolicy.isActuallyCompleted(activity, now: now) {
            if CoachLightRecoveryStableDayPolicy.isLightRecoveryModality(activity) {
                let calm = CoachLightRecoveryStableDayPolicy.calmHero(for: activity)
                return dynamicText(calm.english, russian: calm.russian)
            }
            return dynamicText("Finished \(name) — take it easy next", russian: "\(label) сделана — дальше без спешки")
        }
        if activity.date > now || coachV4EndDate(for: activity) > now {
            return dynamicText("Next up: \(name)", russian: "Дальше: \(label)")
        }
        return dynamicText("Next up: \(name)", russian: "Дальше: \(label)")
    }

    private static func dayPlanOverviewHero(input: CoachInputSnapshot) -> CoachFinalStoryText? {
        guard let summary = CoachDayPlanReadBuilder.build(input: input) else { return nil }
        if let remaining = summary.remainingLabels.first {
            if summary.completedLabels.isEmpty || summary.completedLabels.last?.english == remaining.english {
                let hero = CoachLightRecoveryStableDayPolicy.plannedRemainingHero(label: remaining)
                return dynamicText(hero.english, russian: hero.russian)
            }
            let doneEN = summary.completedLabels.last?.english ?? "session"
            let doneRU = summary.completedLabels.last?.russian ?? "сессия"
            return dynamicText(
                "\(doneEN.capitalized) done — \(remaining.english) is still on today's plan",
                russian: "\(doneRU) сделана — \(remaining.russian) ещё в плане"
            )
        }
        if summary.completedLabels.count == 1,
           let only = summary.completedLabels.first,
           only.english == "walk" || only.english == "yoga" || only.english == "stretching" ||
           only.english == "mobility" || only.english == "breathing" {
            let calm = CoachLightRecoveryStableDayPolicy.calmHero(for: input.dayContext.lastCompletedActivity)
            return dynamicText(calm.english, russian: calm.russian)
        }
        if summary.completedLabels.count >= 2 {
            let onlyLightRecovery = summary.completedLabels.allSatisfy {
                ["walk", "yoga", "stretching", "mobility", "breathing"].contains($0.english)
            }
            if onlyLightRecovery {
                let calm = CoachLightRecoveryStableDayPolicy.calmDayHero(completedCount: summary.completedLabels.count)
                return dynamicText(calm.english, russian: calm.russian)
            }
            return dynamicText(
                "Good progress today — take it easy for the rest",
                russian: "Хороший прогресс сегодня."
            )
        }
        return nil
    }

    private static func coachV4AssessmentText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        selectedActivity: PlannedActivity?,
        seriousCompleted: PlannedActivity?,
        limiter: CoachLimiter,
        permission: CoachV4TrainPermission
    ) -> CoachFinalStoryText {
        if let narrative = authoritativePlanChangeNarrative(guidance: guidance) {
            return dynamicText(narrative.message, russian: narrative.message)
        }

        if let completed = seriousCompleted {
            let labels = recoveryActivityName(completed)
            return dynamicText(
                "The completed \(labels.english) created meaningful training stress.",
                russian: "Завершённая \(labels.russian) дала заметную нагрузку."
            )
        }

        if owner == .tomorrowProtection {
            return dynamicText(
                "The best training move now is to keep this evening quiet.",
                russian: "Сейчас лучше сделать вечер спокойным."
            )
        }

        if limiter == .sleep {
            if hasSleepDeficitEvidence(input) {
                return dynamicText(
                    "Sleep is reducing today's readiness.",
                    russian: "Сон сегодня снижает готовность."
                )
            }
            if isLateEveningWindDown(input),
               input.recoveryContext.recoveryPercent >= 75,
               !hasSleepDeficitEvidence(input) {
                return dynamicText(
                    "Recovery looked solid today. The main job now is to protect tomorrow.",
                    russian: "Сегодня восстановление выглядело хорошим. Главное сейчас — беречь завтра."
                )
            }
            return dynamicText("", russian: "")
        }

        if limiter == .recovery {
            if input.recoveryContext.recoveryPercent >= 80 && !lowRecoveryOrReadiness(input) {
                return dynamicText("", russian: "")
            }
            if moderateRecoveryScore(input),
               calmDailyOverviewWithoutWorkout(input: input, guidance: guidance, selected: selectedActivity) {
                return dynamicText("", russian: "")
            }
            return dynamicText(
                "Recovery is limiting how much useful training you can absorb today.",
                russian: "Сегодня лучше не перегружаться."
            )
        }

        if permission == .noActionNeeded {
            if owner == .readiness || owner == .stableOverview {
                return dynamicText("", russian: "")
            }
            return dynamicText(
                "Nothing important needs attention right now.",
                russian: "Сейчас ничего особенного не требует внимания."
            )
        }

        if selectedActivity.map(isRecoveryActivityV4) == true {
            return dynamicText(
                "This is recovery work, not a training session.",
                russian: "Это лёгкая активность, а не тренировка."
            )
        }

        if let activity = selectedActivity {
            return dynamicText(
                "Recovery looks stable enough for a controlled \(displayName(activity).lowercased()).",
                russian: "Самочувствие позволяет контролируемую тренировку."
            )
        }

        return dynamicText(
            "The day does not need a training decision right now.",
            russian: "Сейчас день не требует тренировочного решения."
        )
    }

    private static func coachV4SituationText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        selectedActivity: PlannedActivity?,
        limiter: CoachLimiter,
        permission: CoachV4TrainPermission,
        seriousTrainingState: CoachV4SeriousTrainingState
    ) -> CoachFinalStoryText {
        switch permission {
        case .noActionNeeded:
            if owner == .readiness || owner == .stableOverview {
                return dynamicText("", russian: "")
            }
            return dynamicText("Nothing useful needs changing now.", russian: "Сейчас ничего полезного менять не нужно.")
        case .noTraining:
            if input.dayPriorityModel.tomorrowDemand == .hard || localHour(input.now) >= 20 {
                return dynamicText("Sleep is the useful lever now.", russian: "Сейчас главное — выспаться.")
            }
            return dynamicText("The useful move is to save capacity, not spend it.", russian: "Сейчас лучше беречь силы, а не тратить их.")
        case .recoveryOnly:
            return seriousTrainingState == .completed
                ? dynamicText("The work is done; recovery determines the benefit from here.", russian: "Тренировка сделана — дальше важен отдых.")
                : dynamicText("Movement should help recovery, not become training.", russian: "Движение должно помогать отдыху, а не заменять тренировку.")
        case .trainControlled:
            return dynamicText("Training can happen, but the ceiling is lower today.", russian: "Тренироваться можно, но потолок сегодня ниже.")
        case .train:
            if selectedActivity != nil {
                return dynamicText("Use the opening minutes to confirm the body is responding well.", russian: "Первые минуты — чтобы проверить, как чувствуете себя.")
            }
            return dynamicText("Recovery looks fine today.", russian: "Самочувствие сегодня нормальное.")
        }
    }

    private static func coachV4AvoidanceText(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        selectedActivity: PlannedActivity?,
        limiter: CoachLimiter,
        permission: CoachV4TrainPermission,
        seriousTrainingState: CoachV4SeriousTrainingState
    ) -> CoachFinalStoryText {
        if seriousTrainingState == .completed {
            if localHour(input.now) >= 20 {
                return dynamicText("Do not turn a late evening into another hard session.", russian: "Поздним вечером лучше без ещё одной тяжёлой тренировки.")
            }
            return dynamicText("Do not add another hard session today.", russian: "Сегодня лучше без ещё одной тяжёлой тренировки.")
        }
        if permission == .noActionNeeded {
            if calmDailyOverviewWithoutWorkout(input: input, guidance: guidance, selected: selectedActivity) {
                return calmDailyOverviewAvoidanceText(input)
            }
            return dynamicText("Do not add work just to close a number.", russian: "Нагрузку лучше не добавлять только ради цифры.")
        }
        if calmDailyOverviewWithoutWorkout(input: input, guidance: guidance, selected: selectedActivity) {
            return calmDailyOverviewAvoidanceText(input)
        }
        if limiter == .hydration {
            return dynamicText("Do not start the workout dehydrated.", russian: "Тренировку лучше не начинать без воды.")
        }
        if limiter == .fueling {
            return dynamicText("Do not start the hard part under-fueled.", russian: "Тяжёлую часть лучше не начинать без энергии.")
        }
        if input.dayPriorityModel.tomorrowDemand == .hard {
            return dynamicText("Do not spend tomorrow's readiness tonight.", russian: "Не тратьте силы сегодня — завтра тяжёлая тренировка.")
        }
        if limiter == .sleep, hasSleepDeficitEvidence(input) {
            return dynamicText("Do not spend tomorrow's readiness tonight.", russian: "Не тратьте силы сегодня — завтра тяжёлая тренировка.")
        }
        if isLateEveningWindDown(input),
           input.recoveryContext.recoveryPercent >= 75,
           !hasSleepDeficitEvidence(input),
           calmDailyOverviewWithoutWorkout(input: input, guidance: guidance, selected: selectedActivity) {
            return dynamicText(
                "Do not add extra work this late unless it is already planned.",
                russian: "Не добавляйте лишнюю нагрузку так поздно, если этого нет в плане."
            )
        }
        if selectedActivity.map(isRecoveryActivityV4) == true {
            return dynamicText("Do not turn recovery work into a workout.", russian: "Сегодня лучше не превращать это в тренировку.")
        }
        if !hasSignificantWorkoutContext(input: input, guidance: guidance, selected: selectedActivity) {
            return dynamicText("Do not add work just to close a number.", russian: "Нагрузку лучше не добавлять только ради цифры.")
        }
        return dynamicText("Do not add intensity before the body confirms it.", russian: "Интенсивность лучше не добавлять, пока тело не подтвердило готовность.")
    }

    private static func concreteActionText(_ guidance: CoachGuidanceV3) -> String? {
        guard !WeekFitCurrentLocale().identifier.hasPrefix("ru") else { return nil }
        let screenTitles = guidance.screenStory?.primaryActions.map(\.title) ?? []
        let supportTitles = guidance.supportActions.map(\.title)
        let titles = (screenTitles.isEmpty ? supportTitles : screenTitles)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isGenericActionText($0) }

        guard let first = titles.first else { return nil }
        if let second = titles.dropFirst().first, !isDuplicateAction(first, second) {
            return "\(first), then \(lowercasedFirst(second))."
        }
        return first
    }

    private static func primaryCoachActionText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachFinalStoryText? {
        coachActionText(coachV4DecisionFrame(owner: owner, input: input, guidance: guidance).primaryAction)
    }

    private static func coachActionSupportActions(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        colorFamily: CoachFinalStoryColorFamily
    ) -> [CoachSupportActionV3] {
        coachV4DecisionFrame(owner: owner, input: input, guidance: guidance).actions.map { recommendation in
            supportAction(
                recommendation.type,
                title: localizedTitle(recommendation),
                subtitle: localizedSubtitle(recommendation),
                colorFamily: colorFamily
            )
        }
    }

    private static func coachV4RankedActions(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        permission: CoachV4TrainPermission,
        seriousTrainingState: CoachV4SeriousTrainingState
    ) -> [CoachActionRecommendation] {
        var recommendations: [CoachActionRecommendation] = []

        func append(_ pool: CoachActionPool, where shouldInclude: (CoachActionRecommendation) -> Bool = { _ in true }) {
            recommendations.append(contentsOf: CoachActionLibrary.recommendations(for: pool).filter(shouldInclude))
        }

        if let last = input.dayContext.lastCompletedActivity,
           (isHeatActivity(last) || coachV4ActivityFamily(for: last) == .sauna),
           minutesSinceCoachActivityEnd(last, now: input.now) <= postSessionFocusMinutes(for: last) {
            return []
        }

        if permission == .noActionNeeded {
            if owner == .readiness || owner == .stableOverview {
                if CoachLightRecoveryStableDayPolicy.caloriesCriticallyLow(input) {
                    return [
                        CoachActionRecommendation(
                            type: .lightFueling,
                            englishTitle: "Eat something before the day builds",
                            englishSubtitle: "A simple breakfast is enough to start",
                            russianTitle: "Поездайте, пока день не разогнался",
                            russianSubtitle: "Простого завтрака для старта достаточно"
                        )
                    ]
                }
                let water = input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters
                let waterGoal = input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters
                if water <= 0.05 || ratio(current: water, goal: waterGoal) < 0.10 {
                    return [
                        CoachActionRecommendation(
                            type: .hydrateBeforeSession,
                            englishTitle: "Drink a glass of water now",
                            englishSubtitle: "Start hydration before the day gets busy",
                            russianTitle: "Выпейте стакан воды",
                            russianSubtitle: "Начните с воды, пока день не разогнался"
                        )
                    ]
                }
                if moderateRecoveryScore(input),
                   calmDailyOverviewWithoutWorkout(
                       input: input,
                       guidance: guidance,
                       selected: upcomingActivity(input: input, guidance: guidance) ??
                           activeActivity(input: input, guidance: guidance)
                   ) {
                    return [moderateReadinessOverviewAction()]
                }
                if isLateEveningWindDown(input),
                   input.recoveryContext.recoveryPercent >= 75,
                   !hasSleepDeficitEvidence(input),
                   calmDailyOverviewWithoutWorkout(
                       input: input,
                       guidance: guidance,
                       selected: upcomingActivity(input: input, guidance: guidance) ??
                           activeActivity(input: input, guidance: guidance)
                   ) {
                    return [
                        CoachActionRecommendation(
                            type: .sleepPriority,
                            englishTitle: "Keep the evening quiet and let sleep do the next part.",
                            englishSubtitle: "Close the day calmly and avoid adding late stimulation.",
                            russianTitle: "Вечер лучше спокойный — пусть сон сделает следующий шаг.",
                            russianSubtitle: "Завершите день спокойно и без позднего возбуждения."
                        )
                    ]
                }
                return [
                    CoachActionRecommendation(
                        type: .stayConsistent,
                        englishTitle: "Stay with today's plan",
                        englishSubtitle: "",
                        russianTitle: "Оставьте план без изменений",
                        russianSubtitle: ""
                    )
                ]
            }

            return [
                CoachActionLibrary.noAction(
                    reasonEnglish: "Today's plan is already enough",
                    reasonRussian: "На сегодня этого достаточно"
                ),
                CoachActionRecommendation(
                    type: .stayConsistent,
                    englishTitle: "Leave the day as it is",
                    englishSubtitle: "No extra sessions needed",
                    russianTitle: "Оставьте день как есть",
                    russianSubtitle: "Дополнительные тренировки не нужны"
                )
            ]
        }

        if permission == .noTraining {
            if let active = activeActivity(input: input, guidance: guidance) {
                if isHeatActivity(active) || coachV4ActivityFamily(for: active) == .sauna {
                    return [
                        CoachActionRecommendation(
                            type: .controlIntensity,
                            englishTitle: "Keep the heat short and controlled",
                            englishSubtitle: "Leave before fatigue shows",
                            russianTitle: "Тепло коротким и спокойным",
                            russianSubtitle: "Выйдите до появления усталости"
                        ),
                        CoachActionRecommendation(
                            type: .steadyHydration,
                            englishTitle: "Sip to comfort after",
                            englishSubtitle: "Do not chase the full water target at once",
                            russianTitle: "Утолите жажду",
                            russianSubtitle: "Не обязательно пить много"
                        )
                    ]
                }
                return [
                    CoachActionRecommendation(
                        type: .controlIntensity,
                        englishTitle: "You can stop here or keep it easy",
                        englishSubtitle: "Do not add intensity or extra sets",
                        russianTitle: "Можно завершить на этом",
                        russianSubtitle: "Если продолжаете — держите нагрузку лёгкой"
                    ),
                    CoachActionRecommendation(
                        type: .sleepPriority,
                        englishTitle: "Protect sleep",
                        englishSubtitle: "Keep the rest of the evening quiet",
                        russianTitle: "Берегите сон",
                        russianSubtitle: "Проведите остаток вечера спокойно"
                    )
                ]
            }
            append(.tomorrowBigWorkout) { recommendation in
                recommendation.type == .sleepPriority ||
                    recommendation.englishTitle.contains("Avoid another") ||
                    recommendation.englishTitle.contains("Save energy")
            }
            return dedupedRecommendations(recommendations)
        }

        switch owner {
        case .activityPreparation:
            guard let activity = upcomingActivity(input: input, guidance: guidance) else { break }
            let endurance = isEnduranceLike(activity)
            let hard = endurance || activity.effectiveDurationMinutes >= 60 || CoachActivityContextResolverV3.load(for: activity) == .high
            if hard && hydrationNeedsPreWorkoutAction(input) &&
                fuelingNeedsPreWorkoutAction(input, guidance: guidance, activity: activity) {
                recommendations.append(
                    CoachActionRecommendation(
                        type: .lightFueling,
                        englishTitle: "Fuel and hydrate before you start",
                        englishSubtitle: "Keep the first 15 minutes easy",
                        russianTitle: "Подкрепитесь и выпейте воды перед стартом",
                        russianSubtitle: "Первые 15 минут держите темп лёгким"
                    )
                )
            }
            if hard {
                append(.beforeHardWorkout) { recommendation in
                    switch recommendation.type {
                    case .hydrateBeforeSession:
                        return hydrationNeedsPreWorkoutAction(input) || endurance
                    case .lightFueling:
                        return fuelingNeedsPreWorkoutAction(input, guidance: guidance, activity: activity) ||
                            activity.effectiveDurationMinutes >= 75
                    default:
                        return true
                    }
                }
            } else {
                append(.beforeHardWorkout) { recommendation in
                    recommendation.englishTitle.contains("10 minutes") ||
                        recommendation.englishTitle.contains("Avoid extra") ||
                        recommendation.englishTitle.contains("Prepare hydration")
                }
            }
            if lowRecoveryOrReadiness(input) {
                append(.lowRecoveryPoorReadiness) { recommendation in
                    recommendation.englishTitle.contains("10-15") || recommendation.englishTitle.contains("Reassess")
                }
            }

        case .activeActivity, .pacingExecution, .sustainableExecution:
            if lowRecoveryOrReadiness(input) {
                append(.lowRecoveryPoorReadiness) { recommendation in
                    recommendation.englishTitle.contains("10-15") ||
                        recommendation.englishTitle.contains("Reassess") ||
                        recommendation.englishTitle.contains("quality") ||
                        recommendation.englishTitle.contains("shortening")
                }
            }
            if let activity = activeActivity(input: input, guidance: guidance),
               isEnduranceLike(activity) {
                append(.duringEnduranceSession)
            } else {
                append(.duringEnduranceSession) { recommendation in
                    recommendation.englishTitle.contains("steady rhythm") ||
                        recommendation.englishTitle.contains("increasing intensity")
                }
            }

        case .postActivityRecovery:
            if let activity = recentlyCompletedSeriousTraining(input: input, guidance: guidance) ?? completedActivity(input: input, guidance: guidance) {
                if isStrengthLike(activity) {
                    append(.afterStrengthWorkout)
                } else if isEnduranceLike(activity) || activity.effectiveDurationMinutes >= 75 {
                    append(.afterLongEndurance)
                } else {
                    append(.afterStrengthWorkout) { recommendation in
                        recommendation.englishTitle.contains("5-10") ||
                            recommendation.englishTitle.contains("300-700") ||
                            recommendation.englishTitle.contains("complete meal")
                    }
                }
            } else {
                append(.afterLongEndurance) { recommendation in
                    recommendation.englishTitle.contains("Rehydrate") ||
                        recommendation.englishTitle.contains("rest of the day") ||
                        recommendation.englishTitle.contains("Sleep")
                }
            }

        case .recovery:
            recommendations.append(recoveryPrimaryRecommendation(input: input))
            if localHour(input.now) >= 18 {
                append(.optionalRecoveryTools) { recommendation in
                    recommendation.type == .sleepPriority || recommendation.englishTitle.contains("Walk easy")
                }
            }

        case .tomorrowProtection:
            append(.tomorrowBigWorkout)
            if lowRecoveryOrReadiness(input) {
                append(.lowRecoveryPoorReadiness) { recommendation in
                    recommendation.englishTitle.contains("shortening") || recommendation.englishTitle.contains("quality")
                }
            }

        case .readiness:
            if calmDailyOverviewWithoutWorkout(
                input: input,
                guidance: guidance,
                selected: upcomingActivity(input: input, guidance: guidance) ??
                    activeActivity(input: input, guidance: guidance)
            ) {
                if moderateRecoveryScore(input) {
                    recommendations.append(moderateReadinessOverviewAction())
                } else if CoachLightRecoveryStableDayPolicy.caloriesCriticallyLow(input) {
                    recommendations.append(
                        CoachActionRecommendation(
                            type: .lightFueling,
                            englishTitle: "Eat something before the day builds",
                            englishSubtitle: "A simple breakfast is enough to start",
                            russianTitle: "Поездайте, пока день не разогнался",
                            russianSubtitle: "Простого завтрака для старта достаточно"
                        )
                    )
                } else {
                    let water = input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters
                    let waterGoal = input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters
                    if water <= 0.05 || ratio(current: water, goal: waterGoal) < 0.10 {
                        recommendations.append(
                            CoachActionRecommendation(
                                type: .hydrateBeforeSession,
                                englishTitle: "Drink a glass of water now",
                                englishSubtitle: "Start hydration before the day gets busy",
                                russianTitle: "Выпейте стакан воды",
                                russianSubtitle: "Начните с воды, пока день не разогнался"
                            )
                        )
                    } else {
                        recommendations.append(
                            CoachActionRecommendation(
                                type: .stayConsistent,
                                englishTitle: "Stay with today's plan",
                                englishSubtitle: "",
                                russianTitle: "Оставьте план без изменений",
                                russianSubtitle: ""
                            )
                        )
                    }
                }
            } else if let planned = plannedSessionReadinessRecommendation(input: input, guidance: guidance) {
                recommendations.append(planned)
            } else if lowRecoveryOrReadiness(input) {
                append(.lowRecoveryPoorReadiness)
            } else {
                append(.recoveryDay) { recommendation in
                    recommendation.englishTitle.contains("20-40") || recommendation.englishTitle.contains("5-10")
                }
            }

        case .stableOverview:
            if permission == .noActionNeeded {
                break
            }
            append(.recoveryDay) { recommendation in
                recommendation.englishTitle.contains("20-40") || recommendation.englishTitle.contains("comfortable")
            }

        case .hydration, .hydrationExecution:
            append(.beforeHardWorkout) { recommendation in
                recommendation.type == .hydrateBeforeSession
            }

        case .fuel, .fuelingDuringActivity:
            append(.beforeHardWorkout) { recommendation in
                recommendation.type == .lightFueling
            }
        }

        return dedupedRecommendations(recommendations)
    }

    private static func dedupedRecommendations(_ recommendations: [CoachActionRecommendation]) -> [CoachActionRecommendation] {
        var seen = Set<String>()
        return recommendations.filter { recommendation in
            let key = "\(recommendation.type)-\(recommendation.englishTitle.lowercased())"
            return seen.insert(key).inserted
        }
    }

    private static func hydrationNeedsPreWorkoutAction(_ input: CoachInputSnapshot) -> Bool {
        let water = input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters
        let waterGoal = input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        return ratio(current: water, goal: waterGoal) < 0.85 ||
            input.brain.hydration == .behind ||
            input.brain.hydration == .depleted
    }

    private static func fuelingNeedsPreWorkoutAction(
        _ input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        activity: PlannedActivity? = nil
    ) -> Bool {
        CoachLightRecoveryStableDayPolicy.fuelingNeedsPreWorkoutAction(
            input: input,
            guidance: guidance,
            activity: activity
        )
    }

    private static func moderateRecoveryScore(_ input: CoachInputSnapshot) -> Bool {
        let recovery = input.recoveryContext.recoveryPercent
        return recovery >= 60 && recovery < 75
    }

    private static func hasVisibleMorningNutritionOrHydrationGap(_ input: CoachInputSnapshot) -> Bool {
        guard localHour(input.now) < 12 else { return false }
        let water = input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters
        let waterGoal = input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        let calories = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
        let calorieGoal = input.brain.baseDayGoals.calories
        let waterRatio = ratio(current: water, goal: waterGoal)
        let calorieRatio = ratio(current: calories, goal: calorieGoal)
        return water <= 0.05 ||
            waterRatio < 0.10 ||
            calories <= 0 ||
            calorieRatio < 0.10
    }

    private static func calmMorningHeroText(_ input: CoachInputSnapshot) -> CoachFinalStoryText {
        if CoachLightRecoveryStableDayPolicy.caloriesCriticallyLow(input) {
            return dynamicText("Start with fuel this morning", russian: "Утром лучше начать с еды")
        }
        let water = input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters
        let waterGoal = input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        if water <= 0.05 || ratio(current: water, goal: waterGoal) < 0.10 {
            return dynamicText("Hydrate as the day starts", russian: "Начните день с воды")
        }
        if moderateRecoveryScore(input) {
            return dynamicText("Steady start this morning", russian: "Утро начинается ровно")
        }
        return dynamicText("Morning's going fine", russian: "Утро идёт ровно")
    }

    private static func recoveryHeroText(_ input: CoachInputSnapshot) -> CoachFinalStoryText {
        let recovery = input.recoveryContext.recoveryPercent
        if recovery > 0 && recovery < 35 {
            return dynamicText("Go gently today", russian: "Сегодня лучше бережно")
        }
        if input.brain.sleep == .short || input.brain.sleep == .veryShort ||
            (input.recoveryContext.sleepHours > 0 && input.recoveryContext.sleepHours < 6.5) {
            return dynamicText("Rest catches up today", russian: "Сегодня важнее отдых")
        }
        if recovery >= 35 && recovery < 55 {
            return dynamicText("Take it easy for now", russian: "Сейчас лучше не спешить")
        }
        return dynamicText("Recovery still needs time", russian: "Восстановлению ещё нужно время")
    }

    private static func recoveryPrimaryRecommendation(
        input: CoachInputSnapshot
    ) -> CoachActionRecommendation {
        let recovery = input.recoveryContext.recoveryPercent
        if recovery > 0 && recovery < 35 {
            return CoachActionRecommendation(
                type: .controlIntensity,
                englishTitle: "Rest before you add load",
                englishSubtitle: "Move only if it genuinely feels good",
                russianTitle: "Сначала отдых, потом нагрузка",
                russianSubtitle: "Движение — только если действительно хочется"
            )
        }
        if input.brain.sleep == .short || input.brain.sleep == .veryShort {
            return CoachActionRecommendation(
                type: .sleepPriority,
                englishTitle: "Keep today lighter than usual",
                englishSubtitle: "Short sleep is weighing on you today",
                russianTitle: "Сегодня лучше легче обычного",
                russianSubtitle: "Короткий сон сейчас главное ограничение"
            )
        }
        if recovery >= 35 && recovery < 55 {
            return CoachActionRecommendation(
                type: .lightRecoveryMovement,
                englishTitle: "Walk 20-40 minutes easy",
                englishSubtitle: "Keep it conversational",
                russianTitle: "Лёгкая прогулка — если хочется",
                russianSubtitle: "В комфортном темпе"
            )
        }
        return CoachActionRecommendation(
            type: .lightRecoveryMovement,
            englishTitle: "Keep movement easy",
            englishSubtitle: "Use only what leaves you fresher",
            russianTitle: "Движение — только лёгкое",
            russianSubtitle: "Только то, после чего свежее"
        )
    }

    private static func plannedSessionReadinessRecommendation(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachActionRecommendation? {
        guard let upcoming = upcomingActivity(input: input, guidance: guidance) ??
                nextImportantActivityToday(input: input, guidance: guidance) else {
            return nil
        }
        guard hasSignificantWorkoutContext(input: input, guidance: guidance, selected: upcoming) else {
            return nil
        }
        let name = localizedActivityName(for: upcoming, grammaticalCase: .dative)
        return CoachActionRecommendation(
            type: .stayConsistent,
            englishTitle: "Stay ready for the \(name.english)",
            englishSubtitle: "Keep food, fluids, and the rest of the morning calm",
            russianTitle: "Будьте готовы к \(name.russian)",
            russianSubtitle: "Еда, вода и спокойное утро помогут"
        )
    }

    private static func severelyLimitedRecovery(_ input: CoachInputSnapshot) -> Bool {
        let recovery = input.recoveryContext.recoveryPercent
        if recovery >= 60 && recovery < 75 {
            return false
        }
        if recovery >= 75 {
            return input.brain.sleep == .veryShort ||
                (input.recoveryContext.sleepHours > 0 && input.recoveryContext.sleepHours < 5.0)
        }
        return lowRecoveryOrReadiness(input)
    }

    private static func calmDailyOverviewWithoutWorkout(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        selected: PlannedActivity?
    ) -> Bool {
        guard !hasSignificantWorkoutContext(input: input, guidance: guidance, selected: selected) else {
            return false
        }
        if isStableDailyOverview(input: input, guidance: guidance) {
            return true
        }
        if guidance.priority.focus == .dailyOverview {
            return true
        }
        if guidance.priority.focus == .eveningWindDown {
            return true
        }
        return input.dayContext.upcomingTrainingActivities.isEmpty &&
            activeActivity(input: input, guidance: guidance) == nil &&
            upcomingActivity(input: input, guidance: guidance) == nil &&
            (guidance.priority.focus == .performanceReadiness || guidance.priority.focus == .recoveryNeeded)
    }

    private static func moderateReadinessOverviewAction() -> CoachActionRecommendation {
        CoachActionRecommendation(
            type: .stayConsistent,
            englishTitle: "Let the day build naturally",
            englishSubtitle: "Nothing is holding the day back right now, but recovery is not at its strongest yet",
            russianTitle: "Пусть день идёт своим темпом",
            russianSubtitle: "Ничего не сдерживает день, но восстановление ещё не на пике"
        )
    }

    private static func calmDailyOverviewAvoidanceText(_ input: CoachInputSnapshot? = nil) -> CoachFinalStoryText {
        if let input,
           isLateEveningWindDown(input),
           input.recoveryContext.recoveryPercent >= 75,
           !hasSleepDeficitEvidence(input) {
            return dynamicText(
                "Avoid turning a good day into a late-night push.",
                russian: "Не превращайте хороший день в поздний рывок."
            )
        }
        return dynamicText(
            "Avoid forcing the pace if energy feels inconsistent.",
            russian: "Не форсируйте темп, если энергия скачет."
        )
    }

    private static func lowRecoveryOrReadiness(_ input: CoachInputSnapshot) -> Bool {
        let recovery = input.recoveryContext.recoveryPercent
        if recovery >= 60 && recovery < 75 {
            return false
        }
        if recovery >= 75 {
            return input.brain.sleep == .veryShort ||
                (input.recoveryContext.sleepHours > 0 && input.recoveryContext.sleepHours < 5.0)
        }
        return (recovery > 0 && recovery < 60) ||
            input.brain.recovery == .compromised ||
            input.brain.recovery == .vulnerable ||
            input.brain.readiness == .low ||
            input.brain.readiness == .compromised ||
            input.brain.sleep == .short ||
            input.brain.sleep == .veryShort
    }

    private static func coachV4ActivityFamily(for activity: PlannedActivity) -> CoachV4ActivityFamily {
        let text = "\(activity.title) \(activity.type) \(activity.imageName)".lowercased()
        let kind = CoachActivityContextResolverV3.kind(for: activity)

        if text.contains("breath") { return .breathing }
        if text.contains("stretch") { return .stretching }
        if text.contains("yoga") { return .yoga }
        if text.contains("mobility") { return .mobility }
        if text.contains("walk") || text.contains("walking") { return .walk }
        if kind == .heat || text.contains("sauna") { return .sauna }
        if isEnduranceLike(activity) { return .endurance }
        if isStrengthLike(activity) { return .strength }
        if text.contains("tennis") || text.contains("squash") || text.contains("racket") { return .racket }
        return .other
    }

    private static func coachV4SessionPhase(
        selected: PlannedActivity?,
        active: PlannedActivity?,
        upcoming: PlannedActivity?,
        now: Date,
        latestCompleted: PlannedActivity?
    ) -> CoachV4SessionPhase {
        guard let selected else { return .none }
        if active?.id == selected.id { return .during }
        if upcoming?.id == selected.id { return .pre }
        if latestCompleted?.id == selected.id ||
            CoachLightRecoveryStableDayPolicy.isActuallyCompleted(selected, now: now) {
            return .post
        }
        if selected.date > now { return .pre }
        if coachV4EndDate(for: selected) > now { return .during }
        return .none
    }

    private static func coachV4DurationBand(for activity: PlannedActivity) -> CoachV4DurationBand {
        let minutes = activity.effectiveDurationMinutes
        guard minutes > 0 else { return .none }
        if minutes < 60 { return .shortUnder60 }
        if minutes <= 120 { return .medium60To120 }
        return .longOver120
    }

    private static func coachV4DayLoadContext(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        timePhase: CoachFinalDecisionTimeOfDay,
        seriousCompleted: PlannedActivity?,
        focusActivity: PlannedActivity?
    ) -> CoachV4DayLoadContext {
        let nextImportant = nextImportantActivityToday(input: input, guidance: guidance)
        let hoursUntilNext = nextImportant.map { max(0, $0.date.timeIntervalSince(input.now) / 3600) }
        let tomorrowDemand = input.dayPriorityModel.tomorrowDemand
        let todayPlanSummary = CoachDayPlanReadBuilder.build(input: input)

        return CoachV4DayLoadContext(
            timePhase: timePhase,
            caloriesBurnedSoFar: input.actualLoad.activeCalories,
            completedSeriousTrainingToday: seriousCompleted != nil ||
                (input.dayContext.completedTrainingStressScore >= 4 &&
                    !usesStableDayPlanningFrame(input: input, guidance: guidance)),
            completedRecoveryVolumeToday: input.dayContext.completedActivityVolumeMinutes - input.dayContext.completedTrainingMinutes,
            nextImportantActivityToday: nextImportant,
            focusActivity: focusActivity,
            referenceNow: input.now,
            recoveryPercent: input.recoveryContext.recoveryPercent,
            sleepHours: input.recoveryContext.sleepHours,
            hasHighYesterdayLoad: input.brain.past.hasHighActivityLoad,
            hoursUntilNextImportantActivity: hoursUntilNext,
            timeToNextImportantSession: coachV4TimeToSessionWindow(hoursUntilSession: hoursUntilNext),
            tomorrowDemand: tomorrowDemand,
            shouldProtectUpcomingSession: nextImportant != nil && (
                input.dayContext.completedTrainingStressScore > 0 ||
                    input.actualLoad.activeCalories >= 500 ||
                    input.recoveryContext.recoveryPercent < 75 ||
                    input.brain.sleep == .short ||
                    input.brain.sleep == .veryShort
            ),
            shouldProtectTomorrow: tomorrowDemand == .hard || guidance.priority.focus == .tomorrowPlanRisk,
            tomorrowRecoveryPlanSummary: CoachTomorrowPlanReadBuilder.recoveryPlanSummary(input: input),
            todayPlanSummary: todayPlanSummary,
            needsRecoveryNutrition: recoveryNutritionNeedsSupport(input)
        )
    }

    private static func coachV4TimeToSessionWindow(hoursUntilSession: Double?) -> CoachV4TimeToSessionWindow {
        guard let hoursUntilSession else { return .none }
        if hoursUntilSession < 0.25 { return .under15Minutes }
        if hoursUntilSession < 1 { return .fifteenTo60Minutes }
        if hoursUntilSession < 2 { return .sixtyTo120Minutes }
        if hoursUntilSession < 4 { return .twoToFourHours }
        return .fourPlusHours
    }

    private static func nextImportantActivityToday(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if let upcoming = upcomingActivity(input: input, guidance: guidance),
           isSignificantCoachActivityV4(upcoming) {
            return upcoming
        }

        if let planNext = CoachDayPlanReadBuilder.nextRemainingActivity(input) {
            return planNext
        }

        if let training = input.dayContext.upcomingTrainingActivities
            .filter({ !$0.isSkipped && !$0.isCompleted && $0.date >= input.now })
            .sorted(by: { $0.date < $1.date })
            .first {
            return training
        }

        return nextUpcomingRecoveryPlanActivity(input)
    }

    private static func ongoingV4Activity(input: CoachInputSnapshot) -> PlannedActivity? {
        input.plannedActivities
            .filter { activity in
                !activity.isCompleted &&
                    !activity.isSkipped &&
                    activity.date <= input.now &&
                    (activity.source == "today" || coachV4EndDate(for: activity) >= input.now) &&
                    (isSignificantCoachActivityV4(activity) || isHeatActivity(activity) || coachV4ActivityFamily(for: activity) == .sauna)
            }
            .sorted { $0.date > $1.date }
            .first
    }

    private static func upcomingV4RecoveryOrHeatActivity(input: CoachInputSnapshot) -> PlannedActivity? {
        input.plannedActivities
            .filter { activity in
                !activity.isCompleted &&
                    !activity.isSkipped &&
                    activity.date >= input.now &&
                    (isHeatActivity(activity) || coachV4ActivityFamily(for: activity) == .sauna)
            }
            .sorted { $0.date < $1.date }
            .first
    }

    private static func latestCompletedV4Activity(input: CoachInputSnapshot) -> PlannedActivity? {
        input.plannedActivities
            .filter { activity in
                activity.isCompleted &&
                    !activity.isSkipped &&
                    (isSignificantCoachActivityV4(activity) || isHeatActivity(activity) || coachV4ActivityFamily(for: activity) == .sauna)
            }
            .sorted { $0.date > $1.date }
            .first
    }

    private static func coachV4EndDate(for activity: PlannedActivity) -> Date {
        activity.date.addingTimeInterval(TimeInterval(max(activity.effectiveDurationMinutes, 1) * 60))
    }

    private static func v4ActivityClass(for activity: PlannedActivity) -> CoachV4ActivityClass {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        if kind == .heat { return .heat }
        if kind == .meal { return .nutrition }
        if isRecoveryActivityV4(activity) { return .recovery }
        if isSeriousTraining(activity) { return .seriousTraining }
        if isTrainingActivityV4(activity) { return .training }
        return .none
    }

    private static func isRecoveryActivityV4(_ activity: PlannedActivity) -> Bool {
        let text = "\(activity.title) \(activity.type) \(activity.imageName)".lowercased()
        if text.contains("recovery") ||
            text.contains("stretch") ||
            text.contains("mobility") ||
            text.contains("yoga") ||
            text.contains("breath") ||
            text.contains("walk") ||
            text.contains("walking") {
            return !isSeriousTraining(activity)
        }
        return CoachActivityContextResolverV3.kind(for: activity) == .recovery
    }

    private static func isTrainingActivityV4(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        guard kind == .workout || kind == .endurance else { return false }
        return !isRecoveryActivityV4(activity) || isSeriousTraining(activity)
    }

    private static func isSignificantCoachActivityV4(_ activity: PlannedActivity) -> Bool {
        isTrainingActivityV4(activity) && !isRecoveryActivityV4(activity)
    }

    private static func isSeriousTraining(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let load = CoachActivityContextResolverV3.load(for: activity)
        let minutes = activity.effectiveDurationMinutes
        let text = "\(activity.title) \(activity.type)".lowercased()

        if text.contains("recovery") ||
            text.contains("stretch") ||
            text.contains("mobility") ||
            text.contains("yoga") ||
            text.contains("breath") ||
            text.contains("walk") ||
            text.contains("walking") {
            return false
        }

        if kind == .endurance {
            return minutes >= 75 || load == .high || load == .extreme || text.contains("interval") || text.contains("long")
        }

        if kind == .workout {
            let strength = text.contains("strength") || text.contains("gym") || text.contains("lift") || text.contains("weight")
            let racket = text.contains("tennis") || text.contains("squash")
            return (strength && (minutes >= 45 || load == .high || load == .extreme)) ||
                (racket && (minutes >= 60 || load == .high || load == .extreme)) ||
                load == .extreme
        }

        return false
    }

    private static func recentlyCompletedSeriousTraining(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if usesStableDayPlanningFrame(input: input, guidance: guidance) {
            return nil
        }

        if recoveryDayMorningPlanningContext(input: input, guidance: guidance) {
            return nil
        }

        if case .recovering(let activity, _, _) = guidance.phase,
           activity.isCompleted,
           isSeriousTraining(activity) {
            return activity
        }

        if let activity = guidance.priority.activity,
           activity.isCompleted,
           isSeriousTraining(activity) {
            return activity
        }

        let calendar = Calendar.current
        if let planned = input.plannedActivities
            .filter({
                calendar.isDate($0.date, inSameDayAs: input.now) &&
                    $0.isCompleted &&
                    !$0.isSkipped &&
                    isSeriousTraining($0)
            })
            .sorted(by: { $0.date > $1.date })
            .first {
            return planned
        }

        return nil
    }

    private static func isEnduranceLike(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let text = "\(activity.title) \(activity.type)".lowercased()
        return kind == .endurance ||
            text.contains("run") ||
            text.contains("cycling") ||
            text.contains("ride") ||
            text.contains("bike") ||
            text.contains("bicycle")
    }

    private static func isStrengthLike(_ activity: PlannedActivity) -> Bool {
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let text = "\(activity.title) \(activity.type)".lowercased()
        return kind == .workout &&
            (text.contains("strength") ||
                text.contains("upper") ||
                text.contains("lower") ||
                text.contains("full body") ||
                text.contains("full-body") ||
                text.contains("fullbody") ||
                text.contains("leg") ||
                text.contains("push") ||
                text.contains("pull") ||
                text.contains("gym") ||
                text.contains("lift") ||
                text.contains("weight"))
    }

    private static func finalStorySupportActions(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        humanStory: HumanStory,
        colorFamily: CoachFinalStoryColorFamily,
        supportSignals: [CoachFinalStorySupportSignal]
    ) -> [CoachSupportActionV3] {
        let heroTexts = [
            humanStory.title.resolved,
            humanStory.whatHappened.resolved,
            humanStory.whatMattersNow.resolved,
            humanStory.whatToDoNext.resolved,
            humanStory.whatToAvoid.resolved
        ]

        if owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance),
           isHeatActivity(activity),
           hasSevereHydrationOrHeatContext(input: input) {
            return saunaHydrationSupportActions(colorFamily: colorFamily)
        }

        let upstream: [CoachSupportActionV3] = WeekFitCurrentLocale().identifier.hasPrefix("ru")
            ? []
            : (
                guidance.screenStory?.primaryActions.map { action in
                    CoachSupportActionV3(
                        type: action.type,
                        icon: action.icon,
                        title: action.title,
                        subtitle: action.subtitle,
                        color: action.color,
                        actionProvenance: action.actionProvenance
                    )
                } ?? []
            ) + guidance.supportActions
        let libraryActions = coachActionSupportActions(
            owner: owner,
            input: input,
            guidance: guidance,
            colorFamily: colorFamily
        )

        if owner == .postActivityRecovery || owner == .recovery {
            let recoveryActions = recoverySupportActions(input: input, guidance: guidance, colorFamily: colorFamily)
            let upstreamRecoveryActions = upstream.filter { !isGenericRecoveryFallbackAction($0) }
            let actions = filterSignalDuplicatingActions(
                mergeActions(libraryActions, recoveryActions + upstreamRecoveryActions, avoiding: heroTexts),
                owner: owner,
                input: input,
                guidance: guidance,
                supportSignals: supportSignals
            )
            if !actions.isEmpty {
                return Array(actions.prefix(3))
            }
            let fallbackRecoveryActions = filterSignalDuplicatingActions(
                mergeActions(libraryActions, recoveryActions, avoiding: heroTexts),
                owner: owner,
                input: input,
                guidance: guidance,
                supportSignals: supportSignals
            )
            if !fallbackRecoveryActions.isEmpty {
                return Array(fallbackRecoveryActions.prefix(3))
            }
        }

        var actions = filterSignalDuplicatingActions(
            dedupedActions(libraryActions + upstream, avoiding: heroTexts),
            owner: owner,
            input: input,
            guidance: guidance,
            supportSignals: supportSignals
        )
        actions = filterStableDayHydrationFuelActions(
            actions,
            owner: owner,
            input: input,
            guidance: guidance
        )

        if actions.isEmpty {
            actions.append(
                fallbackSupportAction(
                    owner: owner,
                    input: input,
                    guidance: guidance,
                    colorFamily: colorFamily
                )
            )
        }

        return Array(actions.prefix(3))
    }

    private static func fallbackSupportAction(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        colorFamily: CoachFinalStoryColorFamily
    ) -> CoachSupportActionV3 {
        switch owner {
        case .activityPreparation:
            return supportAction(
                .controlIntensity,
                title: localizedAction(english: "Start with 10 minutes easy", russian: "Первые минуты лучше спокойнее"),
                subtitle: localizedAction(english: "Let the warm-up set the first rhythm", russian: "Разминка задаёт ритм"),
                colorFamily: colorFamily
            )
        case .activeActivity:
            return supportAction(
                .controlIntensity,
                title: localizedAction(english: "Hold the next block controlled", russian: "Следующий блок держите под контролем"),
                subtitle: localizedAction(english: "Skip surges until breathing and form settle", russian: "Без рывков, пока дыхание и техника не стабилизируются"),
                colorFamily: colorFamily
            )
        case .pacingExecution:
            return supportAction(
                .steadyHydration,
                title: localizedAction(english: "Sip from your bottle", russian: "Глоток из бутылки"),
                subtitle: localizedAction(english: "Small mouthfuls only", russian: "Только маленькими глотками"),
                colorFamily: colorFamily
            )
        case .sustainableExecution:
            return supportAction(
                .steadyHydration,
                title: localizedAction(english: "Drink with each fueling block", russian: "Попейте с каждым приёмом пищи"),
                subtitle: localizedAction(english: "Small sips, not a full bottle at once", russian: "Маленькими глотками, не залпом"),
                colorFamily: colorFamily
            )
        case .postActivityRecovery:
            return supportAction(
                .sleepPriority,
                title: localizedAction(english: "Protect sleep tonight", russian: "Берегите сон сегодня"),
                subtitle: localizedAction(english: "That is where recovery finishes", russian: "Там завершается восстановление"),
                colorFamily: colorFamily
            )
        case .recovery:
            let recoveryAction = recoveryPrimaryRecommendation(input: input)
            return supportAction(
                recoveryAction.type,
                title: localizedAction(english: recoveryAction.englishTitle, russian: recoveryAction.russianTitle),
                subtitle: localizedAction(english: recoveryAction.englishSubtitle, russian: recoveryAction.russianSubtitle),
                colorFamily: colorFamily
            )
        case .tomorrowProtection:
            return supportAction(
                .sleepPriority,
                title: localizedAction(english: "Aim for 7-8 hours sleep", russian: "Постарайтесь выспаться"),
                subtitle: localizedAction(english: "Make tonight the main recovery block", russian: "Сегодня ночью"),
                colorFamily: colorFamily
            )
        case .readiness:
            if calmDailyOverviewWithoutWorkout(
                input: input,
                guidance: guidance,
                selected: upcomingActivity(input: input, guidance: guidance) ??
                    activeActivity(input: input, guidance: guidance)
            ) {
                let overviewAction = moderateRecoveryScore(input)
                    ? moderateReadinessOverviewAction()
                    : CoachActionRecommendation(
                        type: .stayConsistent,
                        englishTitle: "Stay with today's plan",
                        englishSubtitle: "",
                        russianTitle: "Оставьте план без изменений",
                        russianSubtitle: ""
                    )
                return supportAction(
                    .stayConsistent,
                    title: localizedAction(english: overviewAction.englishTitle, russian: overviewAction.russianTitle),
                    subtitle: localizedAction(english: overviewAction.englishSubtitle, russian: overviewAction.russianSubtitle),
                    colorFamily: colorFamily
                )
            }
            if hasSignificantWorkoutContext(
                input: input,
                guidance: guidance,
                selected: upcomingActivity(input: input, guidance: guidance) ??
                    activeActivity(input: input, guidance: guidance)
            ) {
                return supportAction(
                    .controlIntensity,
                    title: localizedAction(english: "Reduce intensity by one level", russian: "Сейчас лучше чуть легче обычного"),
                    subtitle: localizedAction(english: "Use this before the main set", russian: "Перед основной частью"),
                    colorFamily: colorFamily
                )
            }
            return supportAction(
                .stayConsistent,
                title: localizedAction(english: "Stay with today's plan", russian: "Оставьте план без изменений"),
                subtitle: localizedAction(english: "", russian: ""),
                colorFamily: colorFamily
            )
        case .fuelingDuringActivity:
            return supportAction(
                .sustainEnergy,
                title: localizedAction(english: "Consume 30-60 g carbs", russian: "Сейчас лучше поесть"),
                subtitle: localizedAction(english: "Within the next 15 minutes", russian: "В ближайшие минуты"),
                colorFamily: colorFamily
            )
        case .hydrationExecution:
            return supportAction(
                .steadyHydration,
                title: localizedAction(english: "Drink 300-500 ml", russian: "Попейте воды"),
                subtitle: localizedAction(english: "During the next 20 minutes", russian: "В ближайшие минуты"),
                colorFamily: colorFamily
            )
        case .stableOverview, .hydration, .fuel:
            break
        }

        return supportAction(
            .stayConsistent,
            title: localizedAction(english: "Leave the plan unchanged", russian: "План без изменений"),
            subtitle: localizedAction(english: "Do not add a new correction today", russian: "Сегодня новое исправление не нужно"),
            colorFamily: colorFamily
        )
    }

    private static func finalCopyPlan(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        humanStory: HumanStory,
        reasons: [CoachFinalStoryReason],
        supportActions: [CoachSupportActionV3]
    ) -> FinalCopyPlan {
        let critical = finalCopyIsCritical(owner: owner, input: input, guidance: guidance)
        let maxWhyRows = critical ? 3 : 2
        let maxActions = critical ? 3 : 2
        let heroTexts = [
            humanStory.title.resolved,
            humanStory.whatHappened.resolved,
            humanStory.whatMattersNow.resolved,
            humanStory.whatToDoNext.resolved,
            humanStory.whatToAvoid.resolved
        ]
        let heroThemes = Set(heroTexts.flatMap { finalCopyThemes(in: $0) })
        let concreteCriticalActions = supportActions.filter {
            finalCopyConcreteActionIsNecessary($0, critical: critical)
        }
        let concreteCriticalThemes = concreteCriticalActions.flatMap { action in
            finalCopyThemes(for: action)
        }
        let concreteCriticalActionThemes = Set(concreteCriticalThemes.filter { theme in
            theme == .hydration || theme == .fuel || theme == .protein
        })
        var themeCounts = Dictionary(uniqueKeysWithValues: FinalCopyTheme.allCases.map { ($0, heroThemes.contains($0) ? 1 : 0) })
        var seenText = Set(heroTexts.map(finalCopyNormalizedText))
        var cleanedReasons: [CoachFinalStoryReason] = []

        for reason in reasons {
            guard cleanedReasons.count < maxWhyRows else { break }

            let text = reason.text.resolved
            let normalized = finalCopyNormalizedText(text)
            guard !normalized.isEmpty, seenText.insert(normalized).inserted else { continue }

            let themes = finalCopyThemes(for: reason)
            let newThemes = themes.subtracting(heroThemes)
            let concreteActionAlreadyOwnsTheme = !themes.intersection(concreteCriticalActionThemes).isEmpty
            let repeatsHeroOnly = !themes.isEmpty && newThemes.isEmpty

            if concreteActionAlreadyOwnsTheme || (repeatsHeroOnly && !finalCopyReasonCanRestateHero(reason)) {
                continue
            }

            if finalCopyWouldOverRepeat(themes, themeCounts: themeCounts) {
                continue
            }

            cleanedReasons.append(reason)
            finalCopyAddThemes(themes, to: &themeCounts)
        }

        if cleanedReasons.isEmpty, let fallbackReason = finalCopyFallbackReason(
            from: reasons,
            avoiding: seenText,
            themeCounts: themeCounts
        ) {
            cleanedReasons = [fallbackReason]
            finalCopyAddThemes(finalCopyThemes(for: fallbackReason), to: &themeCounts)
            seenText.insert(finalCopyNormalizedText(fallbackReason.text.resolved))
        }

        let whyThemes = Set(cleanedReasons.flatMap { finalCopyThemes(for: $0) })
        var seenActionThemes = Set<FinalCopyTheme>()
        var cleanedActions: [CoachSupportActionV3] = []

        for action in supportActions {
            guard cleanedActions.count < maxActions else { break }

            let normalizedTitle = finalCopyNormalizedText(action.title)
            let normalizedSubtitle = finalCopyNormalizedText(action.subtitle)
            guard !normalizedTitle.isEmpty else { continue }
            guard !finalCopyTextOverlapsAny(normalizedTitle, in: seenText) else { continue }
            guard normalizedSubtitle.isEmpty || !finalCopyTextOverlapsAny(normalizedSubtitle, in: seenText) else { continue }
            seenText.insert(normalizedTitle)

            let themes = finalCopyThemes(for: action)
            let concreteNecessary = finalCopyConcreteActionIsNecessary(action, critical: critical)
            let repeatsWhy = !themes.intersection(whyThemes).isEmpty
            let repeatsActionTheme = !themes.intersection(seenActionThemes).isEmpty
            let genericSignalAction = finalCopyIsGenericHydrationOrFuelAction(action)

            if repeatsActionTheme {
                continue
            }
            if repeatsWhy && (!concreteNecessary || genericSignalAction) {
                continue
            }
            if finalCopyWouldOverRepeat(themes, themeCounts: themeCounts), !concreteNecessary {
                continue
            }

            cleanedActions.append(action)
            seenActionThemes.formUnion(themes)
            finalCopyAddThemes(themes, to: &themeCounts)
        }

        let cleanedHumanStory = finalCopyCompressedHumanStory(
            humanStory,
            owner: owner,
            input: input,
            guidance: guidance,
            supportActions: cleanedActions
        )

        return FinalCopyPlan(
            humanStory: cleanedHumanStory,
            reasons: cleanedReasons,
            supportActions: cleanedActions
        )
    }

    private static func finalCopyCompressedHumanStory(
        _ humanStory: HumanStory,
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        supportActions: [CoachSupportActionV3]
    ) -> HumanStory {
        let actionThemes = Set(supportActions.flatMap { finalCopyThemes(for: $0) })
        var happened = humanStory.whatHappened
        var matters = humanStory.whatMattersNow
        var next = humanStory.whatToDoNext
        var avoid = humanStory.whatToAvoid

        if !usesCoachV4DecisionFrame(input: input, guidance: guidance),
           owner == .activityPreparation,
           let activity = upcomingActivity(input: input, guidance: guidance),
           isHeatActivity(activity) {
            happened = dynamicText(
                "Keep the visit light.",
                russian: "Заход лёгкий."
            )
            matters = dynamicText("One small step is enough.", russian: "Достаточно одного простого шага.")
            if actionThemes.contains(.hydration) || actionThemes.contains(.saunaHeat) {
                next = dynamicText("Take the simple step.", russian: "Один простой шаг.")
                avoid = dynamicText("Do not overcomplicate it.", russian: "Без лишних усложнений.")
            }
        }

        return HumanStory(
            title: humanStory.title,
            whatHappened: happened,
            whatMattersNow: matters,
            whatToDoNext: next,
            whatToAvoid: avoid
        )
    }

    private static func finalCopyReasonCanRestateHero(_ reason: CoachFinalStoryReason) -> Bool {
        switch reason.kind {
        case .time, .tomorrow, .sleep:
            return true
        default:
            return false
        }
    }

    private static func finalCopyFallbackReason(
        from reasons: [CoachFinalStoryReason],
        avoiding seenText: Set<String>,
        themeCounts: [FinalCopyTheme: Int]
    ) -> CoachFinalStoryReason? {
        reasons.first { reason in
            let text = finalCopyNormalizedText(reason.text.resolved)
            let themes = finalCopyThemes(for: reason)
            return !text.isEmpty &&
                !finalCopyTextOverlapsAny(text, in: seenText) &&
                !finalCopyWouldOverRepeat(themes, themeCounts: themeCounts)
        } ?? reasons.first { reason in
            !finalCopyNormalizedText(reason.text.resolved).isEmpty
        }
    }

    private static func finalCopyIsCritical(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        guidance.priority.strength == .critical ||
            guidance.priority.severity == .critical ||
            owner == .activeActivity ||
            hasSevereHydrationOrHeatContext(input: input) && activitySoon(in: input, matching: { isHeatActivity($0) })
    }

    private static func finalCopyWouldOverRepeat(
        _ themes: Set<FinalCopyTheme>,
        themeCounts: [FinalCopyTheme: Int]
    ) -> Bool {
        themes.contains { (themeCounts[$0] ?? 0) >= 2 }
    }

    private static func finalCopyAddThemes(
        _ themes: Set<FinalCopyTheme>,
        to counts: inout [FinalCopyTheme: Int]
    ) {
        for theme in themes {
            counts[theme, default: 0] += 1
        }
    }

    private static func finalCopyConcreteActionIsNecessary(
        _ action: CoachSupportActionV3,
        critical: Bool
    ) -> Bool {
        let text = "\(action.title) \(action.subtitle)".lowercased()
        let hasAmount = text.contains("ml") || text.contains("воды") || text.range(of: #"\d"#, options: .regularExpression) != nil

        switch action.type {
        case .hydrateBeforeSession:
            return critical || hasAmount
        case .lightFueling, .recoveryMeal, .startRecoveryNutrition, .electrolyteRecovery:
            return critical || hasAmount
        case .controlIntensity, .cooldown, .mobilityPrep, .sleepPriority:
            return true
        default:
            return hasAmount
        }
    }

    private static func finalCopyIsGenericHydrationOrFuelAction(_ action: CoachSupportActionV3) -> Bool {
        switch action.type {
        case .steadyHydration, .rehydrateGradually, .sustainEnergy:
            return true
        default:
            return false
        }
    }

    private static func finalCopyThemes(for reason: CoachFinalStoryReason) -> Set<FinalCopyTheme> {
        var themes = finalCopyThemes(in: reason.text.resolved)
        switch reason.kind {
        case .hydration:
            themes.insert(.hydration)
        case .fuel:
            themes.insert(.fuel)
        case .recovery:
            themes.insert(.recovery)
        case .sleep:
            themes.insert(.sleep)
        case .tomorrow:
            themes.insert(.tomorrowDemand)
        case .time:
            themes.insert(.upcomingActivity)
        case .training:
            themes.insert(.upcomingActivity)
        case .constraint:
            themes.insert(.intensityControl)
        case .stability:
            themes.insert(.flexibility)
        }
        return themes
    }

    private static func finalCopyThemes(for action: CoachSupportActionV3) -> Set<FinalCopyTheme> {
        var themes = finalCopyThemes(in: "\(action.title) \(action.subtitle)")
        switch action.type {
        case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually, .electrolyteRecovery:
            themes.insert(.hydration)
        case .lightFueling, .sustainEnergy, .startRecoveryNutrition, .recoveryMeal, .keepDigestionLight:
            themes.insert(.fuel)
        case .controlIntensity:
            themes.insert(.intensityControl)
        case .cooldown:
            themes.insert(.cooldown)
        case .mobilityPrep, .lightRecoveryMovement:
            themes.insert(.mobility)
        case .sleepPriority, .downshiftNervousSystem, .breathingReset:
            themes.insert(.sleep)
        case .stayConsistent:
            themes.insert(.flexibility)
        }
        return themes
    }

    private static func finalCopyThemes(in value: String) -> Set<FinalCopyTheme> {
        let text = finalCopyNormalizedText(value)
        guard !text.isEmpty else { return [] }

        var themes = Set<FinalCopyTheme>()
        func containsAny(_ fragments: [String]) -> Bool {
            fragments.contains { text.contains($0) }
        }

        if containsAny(["water", "hydrate", "hydration", "drink", "sip", "ml", "вода", "воды", "водой", "пей", "выпей", "глот", "мл"]) {
            themes.insert(.hydration)
        }
        if containsAny(["food", "fuel", "fueling", "nutrition", "calorie", "carb", "meal", "eat", "еда", "еды", "питание", "углевод", "калор", "прием пищи"]) {
            themes.insert(.fuel)
        }
        if containsAny(["protein", "белок"]) {
            themes.insert(.protein)
        }
        if containsAny(["recovery", "recover", "readiness", "восстанов", "готовност"]) {
            themes.insert(.recovery)
        }
        if containsAny(["sleep", "сон", "сна"]) {
            themes.insert(.sleep)
        }
        if containsAny(["completed", "done", "logged", "already did", "main load", "main work", "заверш", "выполн", "уже сдел", "нагрузка уже", "главная нагрузка"]) {
            themes.insert(.completedLoad)
        }
        if containsAny(["coming soon", "upcoming", "next effort", "next planned", "before the start", "start", "скоро", "следующ", "перед старт", "до сауны"]) {
            themes.insert(.upcomingActivity)
        }
        if containsAny(["tomorrow", "завтра", "завтраш"]) {
            themes.insert(.tomorrowDemand)
        }
        if containsAny(["flexible", "flexibility", "stay with the plan", "keep the plan", "no rush", "nothing urgent", "plan", "гибк", "план", "спеш", "срочно"]) {
            themes.insert(.flexibility)
        }
        if containsAny(["intensity", "effort", "easy", "light", "hard", "pace", "tempo", "интенсив", "усили", "легк", "лёгк", "тяжел", "тяжёл", "темп"]) {
            themes.insert(.intensityControl)
        }
        if containsAny(["sauna", "heat", "сауна", "сауны", "сауну", "жар"]) {
            themes.insert(.saunaHeat)
        }
        if containsAny(["cool down", "cooldown", "замин"]) {
            themes.insert(.cooldown)
        }
        if containsAny(["mobility", "stretch", "мобиль", "растяж"]) {
            themes.insert(.mobility)
        }

        return themes
    }

    private static func finalCopyNormalizedText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ".。!?！？"))
    }

    private static func finalCopyTextOverlapsAny(_ value: String, in existing: Set<String>) -> Bool {
        existing.contains { finalCopyTextsOverlap(value, $0) }
    }

    private static func finalCopyTextsOverlap(_ lhs: String, _ rhs: String) -> Bool {
        let left = finalCopyNormalizedText(lhs)
        let right = finalCopyNormalizedText(rhs)
        guard left.count >= 12, right.count >= 12 else {
            return left == right
        }
        return left == right || left.contains(right) || right.contains(left)
    }

    private static func saunaHydrationSupportActions(
        colorFamily: CoachFinalStoryColorFamily
    ) -> [CoachSupportActionV3] {
        [
            supportAction(
                .hydrateBeforeSession,
                title: localizedAction(
                    english: "Sip 300-500 ml",
                    russian: "Попейте воды небольшими глотками"
                ),
                subtitle: localizedAction(
                    english: "Small sips are enough before sauna",
                    russian: "Перед сауной достаточно небольших глотков"
                ),
                colorFamily: .hydration
            ),
            supportAction(
                .controlIntensity,
                title: localizedAction(
                    english: "Keep sauna light",
                    russian: "Сауну лучше сократить"
                ),
                subtitle: localizedAction(
                    english: "Shorter and easier is the win today",
                    russian: "Сегодня лучше короче и легче"
                ),
                colorFamily: .activity
            ),
            supportAction(
                .steadyHydration,
                title: localizedAction(
                    english: "Do not chug water",
                    russian: "Воду на ближайший час"
                ),
                subtitle: localizedAction(
                    english: "One large drink will not help much",
                    russian: "Один большой объём мало поможет"
                ),
                colorFamily: colorFamily
            )
        ]
    }

    private static func filterStableDayHydrationFuelActions(
        _ actions: [CoachSupportActionV3],
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> [CoachSupportActionV3] {
        guard owner == .stableOverview || owner == .readiness else {
            return actions
        }
        guard !hasVisibleMorningNutritionOrHydrationGap(input) else {
            return actions
        }
        guard input.dayPriorityModel.tomorrowDemand != .hard,
              activeActivity(input: input, guidance: guidance) == nil else {
            return actions
        }

        return actions.filter { action in
            guard let signalKind = supportSignalKind(for: action.type) else { return true }
            return signalKind != .hydration && signalKind != .fuel
        }
    }

    private static func filterSignalDuplicatingActions(
        _ actions: [CoachSupportActionV3],
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        supportSignals: [CoachFinalStorySupportSignal]
    ) -> [CoachSupportActionV3] {
        guard owner != .postActivityRecovery && owner != .recovery else {
            return actions
        }

        let visibleSignalKinds = Set(supportSignals.map(\.kind))

        return actions.filter { action in
            guard let signalKind = supportSignalKind(for: action.type),
                  visibleSignalKinds.contains(signalKind) else {
                return true
            }

            return signalActionCanOwnMainSlot(
                action.type,
                signalKind: signalKind,
                owner: owner,
                input: input,
                guidance: guidance
            )
        }
    }

    private static func supportSignalKind(
        for actionType: CoachSupportActionTypeV3
    ) -> CoachFinalStorySupportSignal.Kind? {
        switch actionType {
        case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually, .electrolyteRecovery:
            return .hydration
        case .lightFueling, .sustainEnergy, .startRecoveryNutrition, .recoveryMeal:
            return .fuel
        case .sleepPriority:
            return .sleep
        case .breathingReset,
             .mobilityPrep,
             .keepDigestionLight,
             .controlIntensity,
             .cooldown,
             .lightRecoveryMovement,
             .downshiftNervousSystem,
             .stayConsistent:
            return nil
        }
    }

    private static func signalActionCanOwnMainSlot(
        _ actionType: CoachSupportActionTypeV3,
        signalKind: CoachFinalStorySupportSignal.Kind,
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        switch signalKind {
        case .hydration:
            return owner == .hydration ||
                actionType == .electrolyteRecovery ||
                activeActivity(input: input, guidance: guidance) != nil ||
                (guidance.priority.limiter == .hydration && guidance.priority.strength == .critical) ||
                activitySoon(in: input) { activity in
                    let kind = CoachActivityContextResolverV3.kind(for: activity)
                    let load = CoachActivityContextResolverV3.load(for: activity)
                    return kind == .heat || load == .high
                }

        case .fuel:
            return owner == .fuel ||
                activeActivity(input: input, guidance: guidance) != nil ||
                (guidance.priority.limiter == .fueling && guidance.priority.strength == .critical) ||
                activitySoon(in: input) { activity in
                    let kind = CoachActivityContextResolverV3.kind(for: activity)
                    let load = CoachActivityContextResolverV3.load(for: activity)
                    return kind == .endurance || load == .high
                }

        case .recovery, .sleep, .activity:
            return true
        }
    }

    private static func mergeActions(
        _ primary: [CoachSupportActionV3],
        _ secondary: [CoachSupportActionV3],
        avoiding heroTexts: [String]
    ) -> [CoachSupportActionV3] {
        dedupedActions(primary + secondary, avoiding: heroTexts)
    }

    private static func dedupedActions(
        _ actions: [CoachSupportActionV3],
        avoiding heroTexts: [String]
    ) -> [CoachSupportActionV3] {
        let normalizedHero = Set(heroTexts.map(normalizedActionText))
        var seen = Set<String>()
        var result: [CoachSupportActionV3] = []

        for action in actions {
            let titleKey = normalizedActionText(action.title)
            let subtitleKey = normalizedActionText(action.subtitle)
            guard !titleKey.isEmpty else { continue }
            guard !actionTextOverlapsAny(titleKey, in: normalizedHero) else { continue }
            guard subtitleKey.isEmpty || !actionTextOverlapsAny(subtitleKey, in: normalizedHero) else { continue }
            guard seen.insert("\(action.type)-\(titleKey)").inserted else { continue }
            guard !result.contains(where: { actionTextsOverlap(normalizedActionText($0.title), titleKey) }) else { continue }
            result.append(action)
        }

        return result
    }

    private static func actionTextOverlapsAny(_ value: String, in existing: Set<String>) -> Bool {
        existing.contains { actionTextsOverlap(value, $0) }
    }

    private static func actionTextsOverlap(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalizedActionText(lhs)
        let right = normalizedActionText(rhs)
        guard left.count >= 12, right.count >= 12 else {
            return left == right
        }
        return left == right || left.contains(right) || right.contains(left)
    }

    private static func recoverySupportActions(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        colorFamily: CoachFinalStoryColorFamily
    ) -> [CoachSupportActionV3] {
        guard completedLoadShouldDriveRecovery(input: input, guidance: guidance) else { return [] }

        let activity = completedActivity(input: input, guidance: guidance)
        let kind = activity.map { CoachActivityContextResolverV3.kind(for: $0) }
        let duration = activity?.effectiveDurationMinutes ?? input.dayContext.completedActivityVolumeMinutes
        let highLoad = duration >= 75 ||
            input.dayContext.completedTrainingStressScore >= 2 ||
            input.actualLoad.activeCalories >= 750
        let veryHighLoad = duration >= 150 ||
            input.dayContext.completedTrainingStressScore >= 4 ||
            input.actualLoad.activeCalories >= 1_200 ||
            (input.actualLoad.activityProgress ?? 0) >= 1.5
        let evening = localHour(input.now) >= 18
        let nutritionNeedsAction = recoveryNutritionNeedsSupport(input)
        let hydrationNeedsAction = recoveryHydrationNeedsSupport(input) ||
            kind == .some(.endurance) && highLoad

        var actions: [CoachSupportActionV3] = []

        let completedName = activity.map { recoveryActivityName($0).english } ?? "training"
        let isRide = activity.map { activity in
            let text = "\(activity.title) \(activity.type)".lowercased()
            return text.contains("ride") || text.contains("cycl") || text.contains("bike")
        } == true
        let isStrength = kind == .some(.workout) && activity.map { activity in
            let text = "\(activity.title) \(activity.type)".lowercased()
            return text.contains("strength") || text.contains("upper") || text.contains("gym") || text.contains("lift")
        } == true

        actions.append(
            supportAction(
                .cooldown,
                title: localizedAction(english: isStrength ? "Easy cooldown walk" : "Cooldown walk", russian: "Спокойная заминка"),
                subtitle: localizedAction(english: "Keep it easy and let the body downshift", russian: "Держите легко и дайте телу замедлиться"),
                colorFamily: colorFamily
            )
        )

        actions.append(
            supportAction(
                kind == .some(.workout) ? .mobilityPrep : .lightRecoveryMovement,
                title: localizedAction(english: isStrength ? "Mobility work" : "Light stretching", russian: isStrength ? "Мобильность" : "Лёгкая растяжка"),
                subtitle: localizedAction(english: "Restore range without adding load", russian: "Подвижность без новой нагрузки"),
                colorFamily: colorFamily
            )
        )

        if nutritionNeedsAction && highLoad {
            actions.append(
                supportAction(
                    .recoveryMeal,
                    title: localizedAction(english: isStrength ? "Protein feeding" : "Recovery meal with protein and carbs", russian: isStrength ? "Приём с белком" : "Полноценный приём пищи"),
                    subtitle: localizedAction(english: "Help absorb the completed \(completedName)", russian: "Помогите телу усвоить выполненную работу"),
                    colorFamily: .fuel
                )
            )
        }

        if hydrationNeedsAction {
            actions.append(
                supportAction(
                    .rehydrateGradually,
                    title: localizedAction(english: isRide || kind == .some(.endurance) ? "500 ml hydration" : "Hydrate gradually", russian: "Попейте постепенно"),
                    subtitle: localizedAction(english: "Sip over the next hour instead of catching up fast", russian: "В течение часа, без резкой компенсации"),
                    colorFamily: .hydration
                )
            )
        }

        if evening || veryHighLoad || noRemainingTrainingToday(input) {
            actions.append(
                supportAction(
                    .sleepPriority,
                    title: localizedAction(english: "Aim for 7-8 hours sleep", russian: "Постарайтесь выспаться"),
                    subtitle: localizedAction(english: "Keep the evening easy so recovery can land", russian: "Вечер лучше спокойный, чтобы восстановление сработало"),
                    colorFamily: colorFamily
                )
            )
        }

        if veryHighLoad {
            actions.append(
                supportAction(
                    .controlIntensity,
                    title: localizedAction(english: "No extra hard effort", russian: "Без ещё одной тяжёлой нагрузки"),
                    subtitle: localizedAction(english: "Do not stack more intensity onto today", russian: "Сегодня интенсивность лучше не добавлять"),
                    colorFamily: .warning
                )
            )
        }

        return actions
    }

    private static func isGenericRecoveryFallbackAction(_ action: CoachSupportActionV3) -> Bool {
        let title = normalizedActionText(action.title)
        return title == "stay relaxed" ||
            title == "slow down" ||
            title == "prepare for sleep" ||
            title == "keep the evening calm" ||
            title == "wind down now" ||
            title == "settle down"
    }

    private static func recoveryNutritionNeedsSupport(_ input: CoachInputSnapshot) -> Bool {
        let calories = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
        let calorieGoal = input.nutritionContext?.caloriesGoal ?? input.brain.fullDayGoals.calories
        let protein = input.nutritionContext?.proteinCurrent ?? input.brain.metrics.protein
        let proteinGoal = input.nutritionContext?.proteinGoal ?? input.brain.fullDayGoals.protein

        return ratio(current: calories, goal: calorieGoal) < 0.95 ||
            ratio(current: protein, goal: proteinGoal) < 0.95
    }

    private static func recoveryHydrationNeedsSupport(_ input: CoachInputSnapshot) -> Bool {
        let water = input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters
        let waterGoal = input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters

        return ratio(current: water, goal: waterGoal) < 0.85 ||
            input.brain.hydration == .depleted ||
            input.brain.hydration == .behind
    }

    private static func supportAction(
        _ type: CoachSupportActionTypeV3,
        title: String,
        subtitle: String,
        colorFamily: CoachFinalStoryColorFamily
    ) -> CoachSupportActionV3 {
        CoachSupportActionV3(
            type: type,
            icon: supportActionIcon(for: type),
            title: title,
            subtitle: subtitle,
            color: supportActionColor(for: type, fallback: colorFamily.color),
            actionProvenance: .recoveryPolicy
        )
    }

    private static func supportActionIcon(for type: CoachSupportActionTypeV3) -> String {
        switch type {
        case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually, .electrolyteRecovery:
            return "drop.fill"
        case .startRecoveryNutrition, .recoveryMeal, .lightFueling, .sustainEnergy, .keepDigestionLight:
            return "fork.knife"
        case .sleepPriority:
            return "moon.fill"
        case .cooldown, .mobilityPrep, .lightRecoveryMovement:
            return "figure.cooldown"
        case .breathingReset, .downshiftNervousSystem:
            return "wind"
        case .controlIntensity:
            return "speedometer"
        case .stayConsistent:
            return "checkmark.circle.fill"
        }
    }

    private static func supportActionColor(
        for type: CoachSupportActionTypeV3,
        fallback: Color
    ) -> Color {
        switch type {
        case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually, .electrolyteRecovery:
            return CoachPalette.hydration
        case .startRecoveryNutrition, .recoveryMeal, .lightFueling, .sustainEnergy, .keepDigestionLight:
            return CoachPalette.fueling
        case .controlIntensity:
            return CoachPalette.warning
        default:
            return fallback
        }
    }

    private static func localizedAction(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }

    private static func normalizedActionText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func completedLoadShouldDriveRecovery(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        if usesStableDayPlanningFrame(input: input, guidance: guidance) {
            return false
        }

        if recoveryDayMorningPlanningContext(input: input, guidance: guidance) {
            return false
        }

        if recentlyCompletedSeriousTraining(input: input, guidance: guidance) != nil {
            return true
        }

        if latestCompletedActivityIsRecoveryOnly(input: input, guidance: guidance),
           !objectiveStrainIsHigh(input) {
            return false
        }

        return input.dayContext.completedTrainingStressScore >= 2 ||
            objectiveStrainIsHigh(input)
    }

    private static func latestCompletedActivityIsRecoveryOnly(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        if let activity = guidance.priority.activity,
           activity.isCompleted,
           isRecoveryActivityV4(activity),
           !isSeriousTraining(activity) {
            return true
        }

        guard let activity = input.dayContext.lastCompletedActivity ??
            input.dayContext.completedActivities
            .sorted(by: { $0.date > $1.date })
            .first else {
            return false
        }

        return isRecoveryActivityV4(activity) && !isSeriousTraining(activity)
    }

    private static func recoveryOwnerIsIndependentlyJustified(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        if recentlyCompletedSeriousTraining(input: input, guidance: guidance) != nil {
            return true
        }
        if lowRecoveryOrReadiness(input) {
            return true
        }
        if input.recoveryContext.sleepHours > 0 && input.recoveryContext.sleepHours < 6.5 {
            return true
        }
        if input.dayContext.completedTrainingStressScore >= 2 {
            return true
        }
        if input.dayContext.hasMeaningfulLoadCompleted && !latestCompletedActivityIsRecoveryOnly(input: input, guidance: guidance) {
            return true
        }
        return false
    }

    private static func objectiveStrainIsHigh(_ input: CoachInputSnapshot) -> Bool {
        input.dayContext.completedTrainingStressScore >= 4 ||
            input.brain.metrics.activeCalories >= 1_200 ||
            input.actualLoad.activeCalories >= 1_200 ||
            (input.actualLoad.exerciseMinutes ?? 0) >= 150 ||
            (input.actualLoad.activityProgress ?? 0) >= 1.5
    }

    private static func activeActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if case .active(let activity, _) = guidance.phase,
           !isCompletedDuplicate(activity, in: input) {
            return activity
        }

        if let activity = guidance.priority.activity,
           isActive(activity, now: input.now),
           !isCompletedDuplicate(activity, in: input) {
            return activity
        }

        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: input.dayContext.allActivities,
            selectedDate: input.selectedDate,
            now: input.now,
            brain: input.brain
        )
        if let activity = activityContext.activeActivity,
           !isCompletedDuplicate(activity, in: input) {
            return activity
        }

        if let manualActive = input.dayContext.allActivities.first(where: { activity in
            activity.source == "today" &&
                isActive(activity, now: input.now) &&
                !isCompletedDuplicate(activity, in: input)
        }) {
            return manualActive
        }

        return nil
    }

    private static func isActive(_ activity: PlannedActivity, now: Date) -> Bool {
        guard !activity.isCompleted, !activity.isSkipped else { return false }
        let end = Calendar.current.date(
            byAdding: .minute,
            value: activity.effectiveDurationMinutes,
            to: activity.date
        ) ?? activity.date
        return activity.date <= now && now <= end
    }

    private static func isCompletedDuplicate(
        _ activity: PlannedActivity,
        in input: CoachInputSnapshot
    ) -> Bool {
        input.dayContext.completedActivities.contains { completed in
            guard completed.id != activity.id else { return false }
            let sameTitle = completed.title.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(activity.title.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
            let sameType = completed.type.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(activity.type.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
            let startDelta = abs(completed.date.timeIntervalSince(activity.date))
            let durationDelta = abs(completed.effectiveDurationMinutes - activity.effectiveDurationMinutes)

            return sameTitle && sameType && startDelta <= 15 * 60 && durationDelta <= 10
        }
    }

    private static func activeSessionAssessment(
        activity: PlannedActivity,
        guidance: CoachGuidanceV3,
        input: CoachInputSnapshot
    ) -> ActiveSessionAssessment {
        let highLoad = dayAlreadyHasHighLoad(input)
        let criticalReadiness = criticalActiveReadinessWarning(guidance)
        let lateEvening = localHour(input.now) >= 20
        let lightRecovery = isLightRecoveryActivity(activity)
        let compromised = input.brain.readiness == .low ||
            input.brain.readiness == .compromised ||
            input.brain.recovery == .compromised ||
            input.recoveryContext.recoveryPercent > 0 && input.recoveryContext.recoveryPercent < 60 ||
            input.recoveryContext.sleepHours > 0 && input.recoveryContext.sleepHours < 6.5

        if (highLoad || criticalReadiness) && lateEvening {
            return .activeSleepRisk
        }
        if (highLoad || criticalReadiness) && lightRecovery {
            return .activeRecoveryOnly
        }
        if highLoad || criticalReadiness {
            return .activeAfterOverload
        }
        if compromised || input.dayContext.completedTrainingStressScore >= 2 {
            return .activeWithCaution
        }
        return .normalActive
    }

    private static func dayAlreadyHasHighLoad(_ input: CoachInputSnapshot) -> Bool {
        input.dayContext.hasMeaningfulLoadCompleted ||
            input.dayContext.completedActivityVolumeMinutes >= 150 ||
            input.dayContext.completedTrainingStressScore >= 4 ||
            input.actualLoad.activeCalories >= 1_200 ||
            (input.actualLoad.exerciseMinutes ?? 0) >= 150 ||
            (input.actualLoad.activityProgress ?? 0) >= 1.5
    }

    private static func criticalActiveReadinessWarning(_ guidance: CoachGuidanceV3) -> Bool {
        guidance.priority.focus == .trainingReadinessWarning &&
            guidance.priority.strength == .critical
    }

    private static func isLightRecoveryActivity(_ activity: PlannedActivity) -> Bool {
        let type = activity.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if type.contains("walk") ||
            type.contains("stretch") ||
            type.contains("mobility") ||
            type.contains("yoga") ||
            type.contains("recovery") {
            return true
        }

        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let load = CoachActivityContextResolverV3.load(for: activity)
        return kind == .recovery || load == .low
    }

    private static func eveningSleepRecoveryShouldLead(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        completedLoadShouldDriveRecovery(input: input, guidance: guidance) &&
            noRemainingTrainingToday(input)
    }

    private static func noRemainingTrainingToday(_ input: CoachInputSnapshot) -> Bool {
        let remainingContextActivity = input.dayContext.upcomingActivities.contains { activity in
            !activity.isCompleted &&
                !activity.isSkipped &&
                CoachDayActivityContextResolver.isCoachRelevant(activity)
        }

        return input.dayContext.upcomingTrainingActivities.allSatisfy { $0.isCompleted || $0.isSkipped } &&
            !remainingContextActivity
    }

    private static func completedActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if let activity = recentlyCompletedSeriousTraining(input: input, guidance: guidance) {
            return activity
        }

        if let activity = guidance.priority.activity, activity.isCompleted, !isRecoveryActivityV4(activity) {
            return activity
        }
        return input.dayContext.lastCompletedActivity ??
            input.dayContext.completedActivities
            .filter { CoachDayActivityContextResolver.isCoachRelevant($0) && !isRecoveryActivityV4($0) }
            .sorted { $0.date > $1.date }
            .first
    }

    private static func latestCompletedActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if let activity = guidance.priority.activity, activity.isCompleted {
            return activity
        }

        if case .recovering(let activity, _, _) = guidance.phase,
           activity.isCompleted {
            return activity
        }

        return input.dayContext.lastCompletedActivity ??
            input.dayContext.completedActivities
            .sorted { $0.date > $1.date }
            .first
    }

    private static func completedLoadText(
        activity: PlannedActivity,
        input: CoachInputSnapshot
    ) -> CoachFinalStoryText {
        let activityName = recoveryActivityName(activity).english.lowercased()
        let russianActivityName = recoveryActivityName(activity).russian
        let duration = durationLoadDescription(minutes: activity.effectiveDurationMinutes).english
        let russianDuration = durationLoadDescription(minutes: activity.effectiveDurationMinutes).russian
        let load = input.brain.metrics.activeCalories >= 1_200 ||
            activity.effectiveDurationMinutes >= 150 ||
            CoachActivityContextResolverV3.kind(for: activity) == .endurance && activity.effectiveDurationMinutes >= 120 ||
            input.dayContext.completedTrainingStressScore >= 4
            ? "main training load"
            : "main training stimulus"
        let russianLoad = load == "main training load" ? "основную тренировочную нагрузку" : "основной тренировочный стимул"

        return formattedText(
            "coach.final.human.recovery.completedLoad",
            fallback: "Today's %@ %@ already delivered the %@.",
            russianFallback: "Сегодняшняя %@ %@ уже дала %@.",
            parameters: [duration, activityName, load],
            russianParameters: [russianDuration, russianActivityName, russianLoad]
        )
    }

    private static func recoveryActivityName(_ activity: PlannedActivity) -> (english: String, russian: String) {
        let type = activity.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch type {
        case "cycling", "bike", "biking", "ride":
            return ("cycling session", "велотренировка")
        case "running", "run":
            return ("running session", "беговая тренировка")
        case "walking", "walk":
            return ("walk", "прогулка")
        case "strength", "gym", "lifting":
            return ("strength session", "силовая тренировка")
        default:
            let title = displayName(activity).trimmingCharacters(in: .whitespacesAndNewlines)
            let english = title.localizedCaseInsensitiveContains("session") ? title : "\(title) session"
            return (english, "тренировка")
        }
    }

    private static func durationLoadDescription(minutes: Int) -> (english: String, russian: String) {
        if minutes >= 180 {
            return ("\(minutes / 60)+ hour", "\(minutes / 60)+ часа")
        }
        if minutes >= 120 {
            return ("\(minutes / 60) hour", "\(minutes / 60) часа")
        }
        if minutes >= 75 {
            return ("\(minutes) minute", "\(minutes)-минутная")
        }
        return ("completed", "завершенная")
    }

    private static func upcomingActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if case .preparing(let activity, _, _) = guidance.phase,
           !activity.isCompleted,
           !activity.isSkipped,
           activity.date > input.now,
           CoachDayActivityContextResolver.isCoachRelevant(activity) {
            return activity
        }

        if let activity = guidance.priority.activity,
           !activity.isCompleted,
           !activity.isSkipped,
           activity.date > input.now,
           CoachDayActivityContextResolver.isCoachRelevant(activity) {
            return activity
        }
        return nil
    }

    private static func recoveryLooksStrong(_ input: CoachInputSnapshot) -> Bool {
        input.recoveryContext.recoveryPercent >= 85 &&
            input.recoveryContext.sleepHours >= 7.0 &&
            (input.brain.recovery == .strong || input.brain.readiness == .good)
    }

    private enum ActivityNameGrammaticalCase {
        case nominative
        case dative
        case accusative
        case genitive
    }

    private struct LocalizedActivityName {
        let english: String
        let russian: String
    }

    private static func localizedActivityName(
        for activity: PlannedActivity,
        grammaticalCase: ActivityNameGrammaticalCase = .nominative
    ) -> LocalizedActivityName {
        let text = "\(activity.title) \(activity.type)".lowercased()
        let kind = CoachActivityContextResolverV3.kind(for: activity)

        struct Forms {
            let english: String
            let nominative: String
            let dative: String
            let accusative: String
            let genitive: String
        }

        let forms: Forms? = {
            if kind == .heat || text.contains("sauna") || text.contains("саун") || text.contains("steam") {
                return Forms(
                    english: "sauna",
                    nominative: "сауна",
                    dative: "сауне",
                    accusative: "сауну",
                    genitive: "сауны"
                )
            }
            if text.contains("run") || text.contains("jog") || text.contains("бег") || text.contains("пробеж") {
                return Forms(
                    english: "run",
                    nominative: "бег",
                    dative: "пробежке",
                    accusative: "бег",
                    genitive: "бега"
                )
            }
            if text.contains("cycl") || text.contains("bike") || text.contains("ride") || text.contains("вел") {
                return Forms(
                    english: "ride",
                    nominative: "заезд",
                    dative: "заезду",
                    accusative: "заезд",
                    genitive: "заезда"
                )
            }
            if text.contains("walk") || text.contains("walking") || text.contains("прогул") {
                return Forms(
                    english: "walk",
                    nominative: "прогулка",
                    dative: "прогулке",
                    accusative: "прогулку",
                    genitive: "прогулки"
                )
            }
            if text.contains("stretch") || text.contains("растяж") {
                return Forms(
                    english: "stretching",
                    nominative: "растяжка",
                    dative: "растяжке",
                    accusative: "растяжку",
                    genitive: "растяжки"
                )
            }
            if text.contains("strength") || text.contains("workout") || text.contains("gym") || text.contains("силов") {
                return Forms(
                    english: "strength work",
                    nominative: "силовая",
                    dative: "силовой",
                    accusative: "силовую",
                    genitive: "силовой"
                )
            }
            return nil
        }()

        guard let forms else {
            let fallback = displayName(activity).lowercased()
            return LocalizedActivityName(english: fallback, russian: fallback)
        }

        let russian: String
        switch grammaticalCase {
        case .nominative:
            russian = forms.nominative
        case .dative:
            russian = forms.dative
        case .accusative:
            russian = forms.accusative
        case .genitive:
            russian = forms.genitive
        }
        return LocalizedActivityName(english: forms.english, russian: russian)
    }

    private static func displayName(_ activity: PlannedActivity) -> String {
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        let type = activity.type.trimmingCharacters(in: .whitespacesAndNewlines)
        return type.isEmpty ? "training" : type
    }

    private static func tomorrowProtectionActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        if guidance.priority.focus == .tomorrowPlanRisk,
           let activity = guidance.priority.activity,
           !activity.isSkipped {
            return activity
        }

        if guidance.priority.focus == .tomorrowPlanRisk,
           let selected = selectedCoachActivity(input: input, guidance: guidance) {
            return selected
        }

        guard input.dayPriorityModel.tomorrowDemand == .hard else { return nil }
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: input.selectedDate) else {
            return nil
        }
        let tomorrowActivities = input.plannedActivities.filter { activity in
            calendar.isDate(activity.date, inSameDayAs: tomorrow) && !activity.isSkipped
        }
        return CoachTomorrowDemandResolver.resolve(activities: tomorrowActivities).primaryTrainingActivity
    }

    private static func enduranceDisplayLabels(for activity: PlannedActivity) -> (english: String, russian: String) {
        let text = "\(activity.title) \(activity.type)".lowercased()
        if text.contains("run") || text.contains("running") {
            return ("run", "бег")
        }
        if text.contains("cycling") ||
            text.contains("cycl") ||
            text.contains("bike") ||
            text.contains("ride") {
            return ("ride", "заезд")
        }
        if text.contains("swim") || text.contains("swimming") {
            return ("swim", "заплыв")
        }
        return ("endurance session", "длинный блок")
    }

    private static func specificText(_ value: String?) -> String? {
        guard !WeekFitCurrentLocale().identifier.hasPrefix("ru") else { return nil }
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return nil }
        guard !isGenericActionText(text) else { return nil }
        return text
    }

    private static func isGenericActionText(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return true }
        return normalized == "rebuild the basics" ||
            normalized.contains("rebuild the basics") ||
            normalized == "support recovery" ||
            normalized == "support the next block" ||
            normalized == "hydration supports this story" ||
            normalized == "fuel supports this story" ||
            normalized == "nutrition supports this story" ||
            normalized == "sleep is part of the decision" ||
            normalized == "keep the routine" ||
            normalized == "stay consistent"
    }

    private static func isDuplicateAction(_ first: String, _ second: String) -> Bool {
        let lhs = first.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rhs = second.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lhs == rhs || lhs.contains(rhs) || rhs.contains(lhs)
    }

    private static func lowercasedFirst(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.lowercased() + value.dropFirst()
    }

    private static func dynamicText(_ english: String, russian: String) -> CoachFinalStoryText {
        text("", english, russian)
    }

    private static func formattedText(
        _ key: String,
        fallback: String,
        russianFallback: String,
        parameters: [String],
        russianParameters: [String]
    ) -> CoachFinalStoryText {
        CoachFinalStoryText(
            key: key,
            fallback: String(format: fallback, arguments: parameters.map { $0 as CVarArg }),
            russianFallback: String(format: russianFallback, arguments: russianParameters.map { $0 as CVarArg }),
            parameters: parameters,
            russianParameters: russianParameters
        )
    }

    private static func finalDecisionContext(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachFinalDecisionContext {
        let selected = selectedCoachActivity(input: input, guidance: guidance)
        let selectedFutureActivity = selected.flatMap { activity -> PlannedActivity? in
            guard !activity.isCompleted,
                  !activity.isSkipped,
                  activity.date > input.now else {
                return nil
            }
            return activity
        }
        let shouldUsePreparationUpNext = guidance.priority.focus == .prepareForActivity ||
            guidance.priority.focus == .nextActivityLater
        let selectedUpNext = selectedFutureActivity ??
            (shouldUsePreparationUpNext ? nextImportantActivityToday(input: input, guidance: guidance) : nil)

        return CoachFinalDecisionContext(
            selectedCoachActivity: selected,
            selectedUpNext: selectedUpNext,
            hasFutureActivityContext: selectedUpNext != nil,
            hasTomorrowDemand: input.dayPriorityModel.tomorrowDemand != .none,
            completedLoadMinutes: input.dayContext.completedActivityVolumeMinutes,
            completedTrainingStress: input.dayContext.completedTrainingStressScore,
            timeOfDay: finalDecisionTimeOfDay(input.now)
        )
    }

    private static func selectedCoachActivity(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> PlannedActivity? {
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: input.dayContext.allActivities,
            selectedDate: input.selectedDate,
            now: input.now,
            brain: input.brain
        )

        if let active = activityContext.activeActivity,
           !isCompletedDuplicate(active, in: input),
           CoachDayActivityContextResolver.isCoachRelevant(active) {
            return active
        }

        if let manualActive = input.dayContext.allActivities.first(where: { activity in
            activity.source == "today" &&
                isActive(activity, now: input.now) &&
                !isCompletedDuplicate(activity, in: input) &&
                CoachDayActivityContextResolver.isCoachRelevant(activity)
        }) {
            return manualActive
        }

        if let activity = guidance.priority.activity,
           !activity.isSkipped,
           CoachDayActivityContextResolver.isCoachRelevant(activity) {
            return activity
        }

        if let preparing = activityContext.preparingActivity,
           CoachDayActivityContextResolver.isCoachRelevant(preparing) {
            return preparing
        }

        if !usesStableDayPlanningFrame(input: input, guidance: guidance),
           let recent = activityContext.recentlyCompletedActivity,
           CoachDayActivityContextResolver.isCoachRelevant(recent) {
            return recent
        }

        switch guidance.phase {
        case .active(let activity, _):
            return !activity.isSkipped && CoachDayActivityContextResolver.isCoachRelevant(activity) ? activity : nil
        case .preparing(let activity, _, _):
            return !activity.isSkipped && CoachDayActivityContextResolver.isCoachRelevant(activity) ? activity : nil
        case .recovering(let activity, _, _):
            return !activity.isSkipped && CoachDayActivityContextResolver.isCoachRelevant(activity) ? activity : nil
        case .stable:
            return nil
        }
    }

    private static func finalDecisionTimeOfDay(_ date: Date) -> CoachFinalDecisionTimeOfDay {
        switch localHour(date) {
        case 0..<5:
            return .night
        case 5..<11:
            return .morning
        case 11..<14:
            return .midday
        case 14..<18:
            return .afternoon
        case 18..<21:
            return .evening
        default:
            return .lateEvening
        }
    }

    private static func finalStoryReasons(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        context: CoachFinalDecisionContext
    ) -> [CoachFinalStoryReason] {
        var reasons: [CoachFinalStoryReason] = []

        func append(
            _ kind: CoachFinalStoryReason.Kind,
            _ english: String,
            _ russian: String,
            icon: String,
            colorFamily: CoachFinalStoryColorFamily
        ) {
            guard reasons.count < 3 else { return }
            reasons.append(
                CoachFinalStoryReason(
                    kind: kind,
                    text: dynamicText(english, russian: russian),
                    icon: icon,
                    colorFamily: colorFamily
                )
            )
        }

        switch owner {
        case .stableOverview, .readiness:
            if input.recoveryContext.recoveryPercent > 0 && input.recoveryContext.recoveryPercent < 65 ||
                input.brain.recovery == .compromised ||
                input.brain.sleep == .short ||
                input.brain.sleep == .veryShort {
                append(.sleep, "Sleep or recovery is limiting the day.", "Сон или отдых ограничивают день.", icon: "moon.fill", colorFamily: .recovery)
            } else {
                append(.recovery, "Recovery is within the normal range.", "Самочувствие в обычном диапазоне.", icon: "heart.fill", colorFamily: .recovery)
            }

            if context.hasFutureActivityContext {
                append(.time, "There is enough room before the next important effort.", "До следующей важной тренировки достаточно времени.", icon: "clock.fill", colorFamily: .ready)
            } else if context.hasTomorrowDemand {
                append(.tomorrow, "Tomorrow has a meaningful demand, but nothing needs forcing now.", "Завтра серьёзная тренировка, но сейчас ничего не нужно форсировать.", icon: "calendar", colorFamily: .activity)
            } else {
                append(.stability, "No immediate demand is shaping the day.", "Сейчас день не задаёт срочных требований.", icon: "checkmark.seal.fill", colorFamily: .stable)
            }

            append(.constraint, "Nothing urgent needs changing.", "Срочно ничего менять не нужно.", icon: "shield.fill", colorFamily: .stable)

        case .activityPreparation:
            if let activity = context.selectedUpNext,
               isHeatActivity(activity) {
                let minutes = minutesUntil(activity, from: input.now)
                append(
                    .time,
                    minutes.map { $0 <= 30 } == true ? "Sauna starts in less than half an hour." : "Sauna is still ahead today.",
                    minutes.map { $0 <= 30 } == true ? "До сауны осталось меньше получаса." : "Сауна ещё впереди сегодня.",
                    icon: "clock.fill",
                    colorFamily: .ready
                )
                append(.hydration, "Water is still low today.", "Воды сегодня пока мало.", icon: "drop.fill", colorFamily: .hydration)
                if input.recoveryContext.sleepHours > 0 && input.recoveryContext.sleepHours < 7 {
                    append(.sleep, "Sleep was shorter than usual.", "Сон был короче обычного.", icon: "moon.fill", colorFamily: .recovery)
                } else {
                    append(.training, "A lighter sauna will cost less.", "Лёгкая сауна заберёт меньше.", icon: "flame.fill", colorFamily: .activity)
                }
            } else if let activity = context.selectedUpNext {
                let minutes = minutesUntil(activity, from: input.now)
                let labels = enduranceDisplayLabels(for: activity)
                append(
                    .time,
                    minutes.map { "\(labels.english.capitalized) starts in about \($0) minutes." } ?? "\(labels.english.capitalized) is still ahead today.",
                    minutes.map { "\(labels.russian.capitalized) начнётся примерно через \($0) минут." } ?? "\(labels.russian.capitalized) ещё впереди сегодня.",
                    icon: "clock.fill",
                    colorFamily: .ready
                )
                append(.training, "The biggest training load is still ahead.", "Главная тренировка ещё впереди.", icon: "figure.run", colorFamily: .activity)
                append(.constraint, "Arriving fresh matters more than adding activity now.", "Сейчас важнее выйти свежим, чем добавить активность.", icon: "figure.cooldown", colorFamily: .warning)
            } else {
                append(.stability, "No selected activity needs special prep.", "Выбранной активности не нужна особая подготовка.", icon: "checkmark.seal.fill", colorFamily: .stable)
                append(.recovery, "Recovery and day stability matter most right now.", "Сейчас важнее отдых и стабильность дня.", icon: "heart.fill", colorFamily: .recovery)
                append(.constraint, "There is no rush to prepare.", "Спешить с подготовкой не нужно.", icon: "shield.fill", colorFamily: .stable)
            }

        case .activeActivity, .pacingExecution, .sustainableExecution:
            append(.training, "The current session is already creating load.", "Текущая тренировка уже создаёт нагрузку.", icon: "figure.run", colorFamily: .activity)
            append(.constraint, "Effort control protects the rest of the day.", "Контроль усилия защищает остаток дня.", icon: "speedometer", colorFamily: .warning)
            append(.recovery, "Recovery depends on finishing with reserve.", "Отдых зависит от запаса на финише.", icon: "heart.fill", colorFamily: .recovery)

        case .fuelingDuringActivity:
            append(.training, "Energy expenditure is already high.", "Расход энергии уже высокий.", icon: "flame.fill", colorFamily: .activity)
            append(.fuel, "Fuel intake is behind the workload.", "Еда отстаёт от нагрузки.", icon: "bolt.fill", colorFamily: .fuel)
            append(.time, "The remaining work still needs usable energy.", "Оставшейся работе нужна энергия.", icon: "clock.fill", colorFamily: .ready)

        case .hydrationExecution:
            append(.hydration, "Fluid intake is behind the session demand.", "Воды меньше, чем требует тренировка.", icon: "drop.fill", colorFamily: .hydration)
            append(.training, "The workload is long enough for hydration to affect quality.", "Тренировка достаточно длинная, чтобы вода влияла на качество.", icon: "figure.run", colorFamily: .activity)
            append(.constraint, "Catching up later is harder than steady drinking now.", "Позже догонять сложнее, чем пить ровно сейчас.", icon: "exclamationmark.triangle.fill", colorFamily: .warning)

        case .postActivityRecovery, .recovery:
            append(.training, "The main useful load is already done.", "Основная полезная работа уже выполнена.", icon: "checkmark.circle.fill", colorFamily: .activity)
            append(.recovery, "Recovery matters more than another hard effort.", "Отдых важнее ещё одной тяжёлой нагрузки.", icon: "heart.fill", colorFamily: .recovery)
            append(.constraint, "Extra intensity is unlikely to add benefit.", "Дополнительная интенсивность вряд ли даст пользу.", icon: "exclamationmark.triangle.fill", colorFamily: .warning)

        case .tomorrowProtection:
            if let activity = tomorrowProtectionActivity(input: input, guidance: guidance) {
                let labels = enduranceDisplayLabels(for: activity)
                append(
                    .tomorrow,
                    "Tomorrow's \(labels.english) is the higher-priority demand.",
                    "Завтрашний \(labels.russian) — более приоритетная тренировка.",
                    icon: "calendar",
                    colorFamily: .activity
                )
            } else {
                append(.tomorrow, "Tomorrow has the higher-priority demand.", "Завтра более приоритетная тренировка.", icon: "calendar", colorFamily: .activity)
            }
            append(.constraint, "Extra load today can lower readiness.", "Лишняя нагрузка сегодня снизит готовность.", icon: "arrow.down.heart.fill", colorFamily: .warning)
            append(.sleep, "Sleep and recovery set up the next session.", "Сон и отдых готовят следующую тренировку.", icon: "moon.fill", colorFamily: .recovery)

        case .hydration:
            append(.hydration, "Water is low right now.", "Воды сейчас мало.", icon: "drop.fill", colorFamily: .hydration)
            if context.hasFutureActivityContext {
                append(.training, "Do not start dry.", "Лучше не начинать без воды.", icon: "figure.run", colorFamily: .activity)
            } else {
                append(.constraint, "This is easy to fix now.", "Сейчас это легко поправить.", icon: "exclamationmark.triangle.fill", colorFamily: .warning)
            }
            append(.stability, "Small sips are enough.", "Достаточно небольших глотков.", icon: "checkmark.seal.fill", colorFamily: .stable)

        case .fuel:
            append(.fuel, "Food is low right now.", "Еды сейчас мало.", icon: "bolt.fill", colorFamily: .fuel)
            if context.hasFutureActivityContext {
                append(.training, "The next effort needs usable energy.", "Следующей тренировке нужна энергия.", icon: "figure.run", colorFamily: .activity)
            } else {
                append(.constraint, "Low fuel makes additional intensity less useful.", "При низкой энергии дополнительная интенсивность менее полезна.", icon: "exclamationmark.triangle.fill", colorFamily: .warning)
            }
            append(.stability, "A simple correction keeps the day steadier.", "Простая коррекция сделает день ровнее.", icon: "checkmark.seal.fill", colorFamily: .stable)
        }

        return Array(reasons.prefix(3))
    }

    private static func coachV4FinalReasons(
        frame: CoachV4DecisionFrame,
        humanStory: HumanStory
    ) -> [CoachFinalStoryReason] {
        var seen = Set([
            humanStory.title.resolved,
            humanStory.whatHappened.resolved,
            humanStory.whatMattersNow.resolved,
            humanStory.whatToDoNext.resolved,
            humanStory.whatToAvoid.resolved
        ].map(finalCopyNormalizedText))

        var reasons: [CoachFinalStoryReason] = []
        for reason in frame.reasons {
            let normalized = finalCopyNormalizedText(localizedAction(english: reason.english, russian: reason.russian))
            guard !normalized.isEmpty else { continue }
            guard !finalCopyTextOverlapsAny(normalized, in: seen) else { continue }
            seen.insert(normalized)
            reasons.append(
                CoachFinalStoryReason(
                    kind: reason.kind,
                    text: dynamicText(reason.english, russian: reason.russian),
                    icon: reason.icon,
                    colorFamily: reason.colorFamily
                )
            )
            if reasons.count == 3 { break }
        }

        return reasons
    }

    private static func coachV4FinalSupportActions(
        frame: CoachV4DecisionFrame,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        humanStory: HumanStory,
        reasons: [CoachFinalStoryReason],
        colorFamily: CoachFinalStoryColorFamily
    ) -> [CoachSupportActionV3] {
        if frame.trainPermission == .noActionNeeded,
           frame.storyOwner == .readiness || frame.storyOwner == .stableOverview {
            return []
        }

        var seen = Set((
            [
                humanStory.title.resolved,
                humanStory.whatHappened.resolved,
                humanStory.whatMattersNow.resolved,
                humanStory.whatToDoNext.resolved,
                humanStory.whatToAvoid.resolved
            ] + reasons.map { $0.text.resolved }
        ).map(finalCopyNormalizedText))

        var actions: [CoachSupportActionV3] = []
        for recommendation in frame.actions {
            let title = localizedTitle(recommendation)
            let subtitle = localizedSubtitle(recommendation)
            let normalizedTitle = finalCopyNormalizedText(title)
            let normalizedSubtitle = finalCopyNormalizedText(subtitle)
            guard !normalizedTitle.isEmpty else { continue }
            guard !finalCopyTextOverlapsAny(normalizedTitle, in: seen) else { continue }
            guard normalizedSubtitle.isEmpty || !finalCopyTextOverlapsAny(normalizedSubtitle, in: seen) else { continue }
            seen.insert(normalizedTitle)
            if !normalizedSubtitle.isEmpty {
                seen.insert(normalizedSubtitle)
            }
            actions.append(
                supportAction(
                    recommendation.type,
                    title: title,
                    subtitle: subtitle,
                    colorFamily: colorFamily
                )
            )
            if actions.count == 3 { break }
        }

        if actions.isEmpty {
            let fallback = fallbackSupportAction(
                owner: frame.storyOwner,
                input: input,
                guidance: guidance,
                colorFamily: colorFamily
            )
            let normalizedTitle = finalCopyNormalizedText(fallback.title)
            let normalizedSubtitle = finalCopyNormalizedText(fallback.subtitle)
            if !normalizedTitle.isEmpty,
               !finalCopyTextOverlapsAny(normalizedTitle, in: seen),
               normalizedSubtitle.isEmpty || !finalCopyTextOverlapsAny(normalizedSubtitle, in: seen) {
                actions.append(fallback)
            }
        }

        return actions
    }

    static func build(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        display: Display
    ) -> CoachFinalStory {
        let decisionContext = finalDecisionContext(input: input, guidance: guidance)
        let owner = resolvedOwner(input: input, guidance: guidance)
        logV4AuditBuilderIn(input: input, guidance: guidance, ownerCandidate: owner)
        let title = titleText(owner: owner, fallback: display.title)
        let subtitle = subtitleText(owner: owner, fallback: display.message)
        let recommendation = recommendationText(owner: owner, fallback: display.recommendation)
        let avoid = avoidText(owner: owner, guidance: guidance)
        let assessment = readinessAssessment(input)

        if usesCoachV4DecisionFrame(input: input, guidance: guidance) {
            let frame = coachV4DecisionFrame(owner: owner, input: input, guidance: guidance)
            let storyOwner = frame.storyOwner
            let colorFamily = resolvedColorFamily(owner: storyOwner, input: input, guidance: guidance)
            let badge = badgeText(owner: storyOwner, fallback: display.stateLabel)
            let icon = resolvedIcon(owner: storyOwner, fallback: display.icon)
            let humanStory = HumanStory(
                title: frame.hero,
                whatHappened: frame.assessment,
                whatMattersNow: frame.situation,
                whatToDoNext: coachActionText(frame.primaryAction),
                whatToAvoid: frame.avoidance
            )
            let reasons = coachV4FinalReasons(frame: frame, humanStory: humanStory)
            let supportActions = coachV4FinalSupportActions(
                frame: frame,
                input: input,
                guidance: guidance,
                humanStory: humanStory,
                reasons: reasons,
                colorFamily: colorFamily
            )
            logV4OwnerNormalization(
                source: "CoachFinalStoryBuilder",
                ownerBefore: owner,
                ownerAfter: storyOwner,
                baseOwner: owner,
                input: input,
                guidance: guidance,
                selected: frame.dayLoadContext.nextImportantActivityToday,
                reasonKinds: reasons.map(\.kind),
                usedFallback: false,
                fallbackSource: "v4Playbook"
            )
            let primaryAction = supportActions.first.map { action in
                CoachFinalStoryAction(
                    title: dynamicText(action.title, russian: action.title),
                    icon: action.icon
                )
            } ?? CoachFinalStoryAction(title: humanStory.whatToDoNext, icon: actionIcon(owner: storyOwner))

            let story = CoachFinalStory(
                owner: storyOwner,
                primaryFocus: alignedPrimaryFocus(owner: storyOwner, guidance: guidance),
                titleKey: humanStory.title.key,
                subtitleKey: humanStory.whatHappened.key,
                badgeState: badge,
                heroState: humanStory.whatMattersNow,
                colorFamily: colorFamily,
                icon: icon,
                primaryRecommendationKey: humanStory.whatToDoNext.key,
                avoidRecommendationKey: humanStory.whatToAvoid.key,
                title: humanStory.title,
                subtitle: humanStory.whatHappened,
                primaryRecommendation: humanStory.whatToDoNext,
                avoidRecommendation: humanStory.whatToAvoid,
                whatHappened: humanStory.whatHappened,
                whatMattersNow: humanStory.whatMattersNow,
                whatToDoNext: humanStory.whatToDoNext,
                whatToAvoid: humanStory.whatToAvoid,
                reasons: reasons,
                supportSignals: [],
                upNextContext: upNextContext(decisionContext),
                confidence: guidance.priority.confidence,
                dataReadinessState: assessment.dataReadinessState,
                primaryAction: primaryAction,
                supportActions: supportActions,
                decisionContext: decisionContext
            )
            validateFinalStoryDebug(story)
            logV4AuditBuilderOut(story: story, source: "v4Playbook", usedFallback: false)
            return story
        }

        let humanStory = humanStory(
            owner: owner,
            input: input,
            guidance: guidance,
            titleFallback: title,
            whatHappenedFallback: subtitle,
            whatToDoNextFallback: recommendation,
            whatToAvoidFallback: avoid
        )

        let colorFamily = resolvedColorFamily(owner: owner, input: input, guidance: guidance)
        let badge = badgeText(owner: owner, fallback: display.stateLabel)
        let icon = resolvedIcon(owner: owner, fallback: display.icon)
        let signals = supportSignals(owner: owner, input: input, guidance: guidance)
        let reasons = finalStoryReasons(
            owner: owner,
            input: input,
            guidance: guidance,
            context: decisionContext
        )

        let supportActions = finalStorySupportActions(
            owner: owner,
            input: input,
            guidance: guidance,
            humanStory: humanStory,
            colorFamily: colorFamily,
            supportSignals: signals
        )
        let copyPlan = finalCopyPlan(
            owner: owner,
            input: input,
            guidance: guidance,
            humanStory: humanStory,
            reasons: reasons,
            supportActions: supportActions
        )
        let primaryAction = copyPlan.supportActions.first.map { action in
            CoachFinalStoryAction(
                title: dynamicText(action.title, russian: action.title),
                icon: action.icon
            )
        } ?? CoachFinalStoryAction(title: copyPlan.humanStory.whatToDoNext, icon: actionIcon(owner: owner))

        let story = CoachFinalStory(
            owner: owner,
            primaryFocus: alignedPrimaryFocus(owner: owner, guidance: guidance),
            titleKey: copyPlan.humanStory.title.key,
            subtitleKey: copyPlan.humanStory.whatHappened.key,
            badgeState: badge,
            heroState: copyPlan.humanStory.whatMattersNow,
            colorFamily: colorFamily,
            icon: icon,
            primaryRecommendationKey: copyPlan.humanStory.whatToDoNext.key,
            avoidRecommendationKey: copyPlan.humanStory.whatToAvoid.key,
            title: copyPlan.humanStory.title,
            subtitle: copyPlan.humanStory.whatHappened,
            primaryRecommendation: copyPlan.humanStory.whatToDoNext,
            avoidRecommendation: copyPlan.humanStory.whatToAvoid,
            whatHappened: copyPlan.humanStory.whatHappened,
            whatMattersNow: copyPlan.humanStory.whatMattersNow,
            whatToDoNext: copyPlan.humanStory.whatToDoNext,
            whatToAvoid: copyPlan.humanStory.whatToAvoid,
            reasons: copyPlan.reasons,
            supportSignals: signals,
            upNextContext: upNextContext(decisionContext),
            confidence: guidance.priority.confidence,
            dataReadinessState: assessment.dataReadinessState,
            primaryAction: primaryAction,
            supportActions: copyPlan.supportActions,
            decisionContext: decisionContext
        )
        validateFinalStoryDebug(story)
        logV4AuditBuilderOut(story: story, source: "legacyFinalStory", usedFallback: true)
        return story
    }

    private static func logV4AuditBuilderIn(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3,
        ownerCandidate: CoachFinalStoryOwner
    ) {
        #if DEBUG
        let activity = builderAuditActivity(input: input, guidance: guidance)
        CoachLogger.trace(
            "[CoachV4Audit.Builder.In]",
            "priority=\(guidance.priority.priority)/\(guidance.priority.focus) phase=\(builderAuditPhase(guidance)) activity=\(activity?.title ?? "nil") activityState=\(builderAuditActivityState(activity, now: input.now)) ownerCandidate=\(ownerCandidate.rawValue)"
        )
        #endif
    }

    private static func logV4AuditBuilderOut(
        story: CoachFinalStory,
        source: String,
        usedFallback: Bool
    ) {
        #if DEBUG
        CoachLogger.trace(
            "[CoachV4Audit.Builder.Out]",
            "owner=\(story.owner.rawValue) title=\"\(story.title.resolved)\" source=\(source) usedFallback=\(usedFallback)"
        )
        #endif
    }

    private static func builderAuditActivity(input: CoachInputSnapshot, guidance: CoachGuidanceV3) -> PlannedActivity? {
        if let activity = guidance.priority.activity {
            return activity
        }
        switch guidance.phase {
        case .active(let activity, _),
             .preparing(let activity, _, _),
             .recovering(let activity, _, _):
            return activity
        case .stable:
            return input.dayContext.lastCompletedActivity ?? input.dayContext.completedActivities.sorted { $0.date > $1.date }.first
        }
    }

    private static func builderAuditPhase(_ guidance: CoachGuidanceV3) -> String {
        if case .stable = guidance.phase {
            return "stable"
        }
        return "\(guidance.phase)"
    }

    private static func builderAuditActivityState(_ activity: PlannedActivity?, now: Date) -> String {
        guard let activity else { return "none" }
        return activity.terminalState(now: now).rawValue
    }

    private static func validateFinalStoryDebug(_ story: CoachFinalStory) {
        #if DEBUG
        if !story.decisionContext.hasActivityContext,
           textLooksActivitySpecific(visibleFinalStoryText(story)) {
            CoachLogger.verbose(
                "[CoachTextInvalidContext]",
                "owner=\(story.owner) selectedActivity=nil selectedUpNext=nil text=\"\(visibleFinalStoryText(story))\""
            )
        }

        let reasonKinds = Set(story.reasons.map(\.kind))
        let allowed = allowedReasonKinds(for: story.owner, context: story.decisionContext)
        if !reasonKinds.isSubset(of: allowed) {
            CoachLogger.verbose(
                "[CoachReasoningMismatch]",
                "owner=\(story.owner) reasonKinds=\(reasonKinds.map(\.rawValue).joined(separator: ",")) allowed=\(allowed.map(\.rawValue).joined(separator: ","))"
            )
        }

        if (story.owner == .stableOverview || story.owner == .readiness),
           !story.decisionContext.hasFutureActivityContext,
           !story.decisionContext.hasTomorrowDemand {
            let hydrationFuelActions = story.supportActions.filter { action in
                supportSignalKind(for: action.type) == .hydration || supportSignalKind(for: action.type) == .fuel
            }
            let startsWithHydrationOrFuel = story.supportActions.first.map { action in
                supportSignalKind(for: action.type) == .hydration || supportSignalKind(for: action.type) == .fuel
            } ?? false
            if hydrationFuelActions.count >= 2 || startsWithHydrationOrFuel {
                CoachLogger.verbose(
                    "[CoachPriorityViolation]",
                    "owner=\(story.owner) actions=\(story.supportActions.map { "\($0.type):\($0.title)" }.joined(separator: " | "))"
                )
            }
        }
        #endif
    }

    private static func visibleFinalStoryText(_ story: CoachFinalStory) -> String {
        ([
            story.title.resolved,
            story.subtitle.resolved,
            story.heroState.resolved,
            story.primaryRecommendation.resolved,
            story.avoidRecommendation.resolved,
            story.whatHappened.resolved,
            story.whatMattersNow.resolved,
            story.whatToDoNext.resolved,
            story.whatToAvoid.resolved
        ] + story.reasons.map { $0.text.resolved } + story.supportActions.flatMap { [$0.title, $0.subtitle] })
            .joined(separator: " ")
            .lowercased()
    }

    private static func textLooksActivitySpecific(_ text: String) -> Bool {
        [
            "activity is coming",
            "coming soon",
            "current session",
            "next activity",
            "next planned effort",
            "next effort",
            "session is active",
            "workout",
            "ride",
            "run",
            "prepare for",
            "start easy",
            "first 15 minutes",
            "следующая активность",
            "следующая нагрузка",
            "сессия уже",
            "скоро начнется",
            "подготовьтесь",
            "первые 15 минут"
        ].contains { text.contains($0) }
    }

    private static func allowedReasonKinds(
        for owner: CoachFinalStoryOwner,
        context: CoachFinalDecisionContext
    ) -> Set<CoachFinalStoryReason.Kind> {
        switch owner {
        case .hydration, .hydrationExecution:
            return [.hydration, .training, .constraint, .stability]
        case .fuel, .fuelingDuringActivity:
            return [.fuel, .training, .constraint, .stability]
        case .activeActivity, .pacingExecution, .sustainableExecution:
            return [.training, .constraint, .recovery, .time, .fuel]
        case .activityPreparation:
            return context.hasFutureActivityContext
                ? [.training, .constraint, .time, .hydration, .sleep, .recovery]
                : [.stability, .recovery, .constraint]
        case .postActivityRecovery, .recovery:
            return [.training, .recovery, .constraint, .sleep]
        case .tomorrowProtection:
            return [.tomorrow, .constraint, .sleep, .recovery]
        case .readiness, .stableOverview:
            return [.recovery, .sleep, .time, .tomorrow, .stability, .constraint]
        }
    }

    static func inputIsCoherent(_ input: CoachInputSnapshot) -> Bool {
        readinessAssessment(input).allowed
    }

    static func readinessAssessment(_ input: CoachInputSnapshot) -> CoachFinalStoryReadinessAssessment {
        var satisfied: [String] = []
        var blocked: [String] = []

        if input.nutritionContext != nil {
            satisfied.append("nutrition")
        } else {
            blocked.append("nutritionMissing")
        }

        if input.recoveryContext.recoveryPercent > 0 {
            satisfied.append("recoveryPercent")
        } else {
            blocked.append("recoveryPlaceholder")
        }

        if input.recoveryContext.sleepHours > 0 && input.brain.metrics.sleepHours > 0 {
            satisfied.append("sleepHours")
        } else {
            blocked.append("sleepPlaceholder")
        }

        if input.brain.sleep != .unknown {
            satisfied.append("sleepState")
        } else {
            blocked.append("sleepUnknown")
        }

        let readinessLooksPlaceholder = input.brain.sleep == .unknown &&
            input.recoveryContext.recoveryPercent <= 0 &&
            (input.brain.readiness == .low || input.brain.readiness == .compromised)
        if readinessLooksPlaceholder {
            blocked.append("readinessPlaceholder:\(input.brain.readiness)")
        } else {
            satisfied.append("readinessState")
        }

        let dayContextMatchesSelectedDate = Calendar.current.isDate(input.dayContext.date, inSameDayAs: input.selectedDate)
        let dayContextClockIsCurrent = abs(input.dayContext.now.timeIntervalSince(input.now)) < 2
        if dayContextMatchesSelectedDate && dayContextClockIsCurrent {
            satisfied.append("activityContext")
        } else {
            blocked.append("activityContextStale")
        }

        let allowed = blocked.isEmpty
        return CoachFinalStoryReadinessAssessment(
            allowed: allowed,
            dataReadinessState: allowed ? .coherent : .settling,
            satisfiedConditions: satisfied,
            blockingReasons: blocked
        )
    }

    private static func resolvedOwner(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachFinalStoryOwner {
        if guidance.priority.focus == .activeActivity ||
            activeActivity(input: input, guidance: guidance) != nil {
            return .activeActivity
        }

        if CoachLightRecoveryStableDayPolicy.shouldForceStableOverview(input: input, guidance: guidance) {
            return .stableOverview
        }

        if guidance.priority.focus == .tomorrowPlanRisk ||
            input.dayPriorityModel.tomorrowDemand == .hard {
            return .tomorrowProtection
        }

        if stableDayPlanningOverviewContext(guidance) {
            if recoveryDayMorningPlanningContext(input: input, guidance: guidance) {
                return .stableOverview
            }
            if calmDailyOverviewWithoutWorkout(input: input, guidance: guidance, selected: nil),
               moderateRecoveryScore(input) || isPriorityStableDailyOverview(guidance) {
                return .stableOverview
            }
            return .readiness
        }

        if stableDayOverviewWithoutAcknowledgedTraining(input: input, guidance: guidance) {
            if recoveryDayMorningPlanningContext(input: input, guidance: guidance) {
                return .stableOverview
            }
            if calmDailyOverviewWithoutWorkout(input: input, guidance: guidance, selected: nil),
               moderateRecoveryScore(input) || isPriorityStableDailyOverview(guidance) {
                return .stableOverview
            }
            return .readiness
        }

        if guidance.priority.focus == .prepareForActivity ||
            guidance.priority.focus == .nextActivityLater {
            if authoritativePlanChangeNarrative(guidance: guidance) != nil {
                return .readiness
            }
            return .activityPreparation
        }

        if completedLoadShouldDriveRecovery(input: input, guidance: guidance) {
            return .postActivityRecovery
        }

        if guidance.priority.focus == .postActivityRecovery,
           latestCompletedActivityIsRecoveryOnly(input: input, guidance: guidance),
           !objectiveStrainIsHigh(input) {
            return .recovery
        }

        if hasSevereHydrationOrHeatContext(input: input),
           activitySoon(in: input, matching: { isHeatActivity($0) }) {
            return .activityPreparation
        }

        if guidance.priority.focus == .recoveryNeeded ||
            guidance.priority.focus == .eveningWindDown ||
            guidance.priority.focus == .postActivityRecovery {
            return guidance.priority.focus == .postActivityRecovery ? .postActivityRecovery : .recovery
        }

        if guidance.priority.focus != .activeActivity,
           guidance.priority.focus != .postActivityRecovery,
           !hasHigherLevelHydrationNarrative(input: input, guidance: guidance),
           hydrationMayOwnHero(input: input, guidance: guidance),
           hasSevereHydrationOrHeatContext(input: input) {
            return .hydration
        }

        if guidance.priority.focus != .activeActivity,
           guidance.priority.focus != .postActivityRecovery,
           fuelMayOwnHero(input: input, guidance: guidance),
           hasSevereFuelOrHardTrainingContext(input: input, guidance: guidance) {
            return .fuel
        }

        switch guidance.priority.focus {
        case .activeActivity:
            return .activeActivity
        case .prepareForActivity, .nextActivityLater:
            return .activityPreparation
        case .postActivityRecovery:
            if latestCompletedActivityIsRecoveryOnly(input: input, guidance: guidance),
               !objectiveStrainIsHigh(input) {
                return .recovery
            }
            return .postActivityRecovery
        case .recoveryNeeded, .eveningWindDown:
            return .recovery
        case .trainingReadinessWarning:
            return .readiness
        case .tomorrowPlanRisk:
            return .tomorrowProtection
        case .hydrationBehind:
            return hydrationMayOwnHero(input: input, guidance: guidance) ? .hydration : fallbackOwner(input: input, guidance: guidance)
        case .fuelBehind:
            return fuelMayOwnHero(input: input, guidance: guidance) ? .fuel : fallbackOwner(input: input, guidance: guidance)
        case .performanceReadiness:
            return .readiness
        case .dailyOverview:
            return .stableOverview
        }
    }

    private static func fallbackOwner(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachFinalStoryOwner {
        if input.dayContext.completedTrainingStressScore > 0 ||
            input.dayContext.hasMeaningfulLoadCompleted ||
            guidance.priority.priority == .recovery {
            return .recovery
        }

        if input.dayContext.upcomingTrainingActivities.isEmpty {
            return .readiness
        }

        return .activityPreparation
    }

    private static func hasHigherLevelHydrationNarrative(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        if activeActivity(input: input, guidance: guidance) != nil ||
            completedLoadShouldDriveRecovery(input: input, guidance: guidance) ||
            input.dayPriorityModel.tomorrowDemand == .hard ||
            activitySoon(in: input, matching: { isHeatActivity($0) }) {
            return true
        }

        switch guidance.priority.focus {
        case .prepareForActivity,
             .nextActivityLater,
             .postActivityRecovery,
             .recoveryNeeded,
             .tomorrowPlanRisk,
             .eveningWindDown:
            return true
        default:
            return false
        }
    }

    private static func hydrationMayOwnHero(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        let waterRatio = ratio(
            current: input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters,
            goal: input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        )
        let severeGap = waterRatio < 0.20 || input.brain.hydration == .depleted
        let heatSoon = activitySoon(in: input) { CoachActivityContextResolverV3.kind(for: $0) == .heat }
        let hardSoon = activitySoon(in: input) { activity in
            let load = CoachActivityContextResolverV3.load(for: activity)
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            return kind == .endurance || load == .high || load == .extreme
        }
        let safetyRisk = guidance.priority.strength == .critical || guidance.priority.limiter == .hydration && guidance.priority.strength == .critical
        let morning = localHour(input.now) < 12

        if morning && !heatSoon && !hardSoon && !safetyRisk {
            if severeGap && waterRatio < 0.05 {
                return true
            }
            return false
        }

        return severeGap || heatSoon || hardSoon || safetyRisk
    }

    private static func hasSevereHydrationOrHeatContext(input: CoachInputSnapshot) -> Bool {
        let waterRatio = ratio(
            current: input.nutritionContext?.waterCurrent ?? input.brain.metrics.waterLiters,
            goal: input.nutritionContext?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        )
        return waterRatio < 0.20 ||
            input.brain.hydration == .depleted ||
            activitySoon(in: input) { CoachActivityContextResolverV3.kind(for: $0) == .heat }
    }

    private static func fuelMayOwnHero(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        let focusActivity = guidance.priority.activity ?? nextUpcomingPlanActivityToday(input)
        if let focusActivity,
           CoachLightRecoveryStableDayPolicy.isLightRecoveryModality(focusActivity),
           !CoachLightRecoveryStableDayPolicy.shouldShowFuelWarning(
               input: input,
               guidance: guidance,
               activity: focusActivity
           ) {
            return false
        }

        let calories = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
        let calorieRatio = ratio(current: calories, goal: input.brain.baseDayGoals.calories)
        let noFuel = calories < 120 || calorieRatio < 0.10
        let severeEnergyGap = calorieRatio < 0.20 || input.brain.fuel == .underfueled && calories < 300
        let hardSoon = activitySoon(in: input) { activity in
            let load = CoachActivityContextResolverV3.load(for: activity)
            let kind = CoachActivityContextResolverV3.kind(for: activity)
            return kind == .endurance || load == .high || load == .extreme
        }
        let postWorkoutRefuel = input.dayContext.hasMeaningfulLoadCompleted &&
            (input.nutritionContext?.needsProteinRecovery == true || severeEnergyGap)
        let readinessRisk = guidance.priority.strength == .critical && guidance.priority.limiter == .fueling
        let morning = localHour(input.now) < 12

        if morning && !hardSoon && !postWorkoutRefuel && !readinessRisk {
            if noFuel || calories <= 0 {
                return true
            }
            return false
        }

        return (hardSoon && noFuel) || postWorkoutRefuel || severeEnergyGap || readinessRisk
    }

    private static func hasSevereFuelOrHardTrainingContext(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> Bool {
        let calories = input.nutritionContext?.caloriesCurrent ?? input.brain.metrics.calories
        let calorieRatio = ratio(current: calories, goal: input.brain.baseDayGoals.calories)
        return calorieRatio < 0.20 ||
            input.brain.fuel == .underfueled && calories < 300 ||
            guidance.priority.limiter == .fueling && guidance.priority.strength == .critical ||
            activitySoon(in: input) { activity in
                let load = CoachActivityContextResolverV3.load(for: activity)
                let kind = CoachActivityContextResolverV3.kind(for: activity)
                return kind == .endurance || load == .high || load == .extreme
            }
    }

    private static func alignedPrimaryFocus(
        owner: CoachFinalStoryOwner,
        guidance: CoachGuidanceV3
    ) -> CoachDayFocus {
        let focus = guidance.priority.focus
        switch owner {
        case .recovery:
            switch focus {
            case .dailyOverview, .performanceReadiness, .eveningWindDown:
                return .recoveryNeeded
            default:
                return focus
            }
        case .postActivityRecovery:
            switch focus {
            case .dailyOverview, .performanceReadiness, .recoveryNeeded, .eveningWindDown:
                return .postActivityRecovery
            default:
                return focus
            }
        case .activityPreparation:
            switch focus {
            case .dailyOverview, .performanceReadiness, .recoveryNeeded:
                return .prepareForActivity
            default:
                return focus
            }
        case .tomorrowProtection:
            switch focus {
            case .dailyOverview, .performanceReadiness, .eveningWindDown:
                return .tomorrowPlanRisk
            default:
                return focus
            }
        case .stableOverview, .readiness:
            switch focus {
            case .recoveryNeeded, .postActivityRecovery:
                return .dailyOverview
            default:
                return focus
            }
        default:
            return focus
        }
    }

    private static func resolvedColorFamily(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachFinalStoryColorFamily {
        if guidance.priority.strength == .critical &&
            owner != .activeActivity &&
            owner != .fuelingDuringActivity &&
            owner != .hydrationExecution &&
            owner != .hydration &&
            owner != .fuel &&
            owner != .recovery &&
            owner != .postActivityRecovery {
            switch guidance.priority.limiter {
            case .trainingReadiness, .recovery, .accumulatedFatigue, .excessivePlannedLoad, .insufficientRecoveryTime:
                return .stress
            case .sleep:
                return input.recoveryContext.recoveryPercent > 0 && input.recoveryContext.recoveryPercent < 45 ? .stress : .warning
            case .hydration, .fueling, .upcomingTraining, .timing, .none:
                return .warning
            }
        }

        switch owner {
        case .activeActivity, .pacingExecution, .sustainableExecution:
            if let activity = activeActivity(input: input, guidance: guidance) {
                switch activeSessionAssessment(activity: activity, guidance: guidance, input: input) {
                case .activeSleepRisk, .activeAfterOverload:
                    return .stress
                case .activeWithCaution:
                    return .warning
                case .activeRecoveryOnly:
                    return .recovery
                case .normalActive:
                    return .activity
                }
            }
            return .activity
        case .fuelingDuringActivity:
            return .fuel
        case .hydrationExecution:
            return .hydration
        case .activityPreparation:
            return .activity
        case .postActivityRecovery, .recovery:
            return guidance.priority.severity == .critical ? .warning : .recovery
        case .readiness:
            if guidance.priority.focus == .trainingReadinessWarning {
                return guidance.priority.strength == .critical ? .stress : .warning
            }
            return guidance.priority.focus == .performanceReadiness ? .ready : .stable
        case .stableOverview:
            return .stable
        case .tomorrowProtection:
            return .warning
        case .hydration:
            return guidance.priority.strength == .critical ? .warning : .hydration
        case .fuel:
            return guidance.priority.strength == .critical ? .warning : .fuel
        }
    }

    private static func badgeText(owner: CoachFinalStoryOwner, fallback: String) -> CoachFinalStoryText {
        switch owner {
        case .activeActivity:
            return text("coach.final.badge.live", "LIVE", "СЕЙЧАС")
        case .pacingExecution:
            return text("coach.final.badge.pacing", "PACING", "ТЕМП")
        case .sustainableExecution:
            return text("coach.final.badge.execution", "EXECUTION", "ВЫПОЛНЕНИЕ")
        case .fuelingDuringActivity:
            return text("coach.final.badge.fuelingLive", "FUEL NOW", "ПИТАНИЕ")
        case .hydrationExecution:
            return text("coach.final.badge.hydrationLive", "DRINK NOW", "ВОДА")
        case .activityPreparation:
            return text("coach.final.badge.prepare", "PREPARE", "ПОДГОТОВКА")
        case .postActivityRecovery, .recovery:
            return text("coach.final.badge.recovery", "RECOVERY", "ВОССТАНОВЛЕНИЕ")
        case .readiness:
            return text("coach.final.badge.readiness", "READINESS", "ГОТОВНОСТЬ")
        case .tomorrowProtection:
            return text("coach.final.badge.tomorrow", "PROTECT TOMORROW", "ЗАЩИТИТЬ ЗАВТРА")
        case .stableOverview:
            return text("coach.final.badge.stable", "ON TRACK", "ВСЁ ПО ПЛАНУ")
        case .hydration:
            return text("coach.final.badge.hydration", "HYDRATION", "ВОДА")
        case .fuel:
            return text("coach.final.badge.fuel", "FUEL", "ПИТАНИЕ")
        }
    }

    private static func titleText(owner: CoachFinalStoryOwner, fallback: String) -> CoachFinalStoryText {
        switch owner {
        case .activeActivity, .pacingExecution, .sustainableExecution:
            return text("coach.final.title.live", fallback, "Держите тренировку под контролем")
        case .fuelingDuringActivity:
            return text("coach.final.title.fuelingLive", fallback, "Поддержите энергию")
        case .hydrationExecution:
            return text("coach.final.title.hydrationLive", fallback, "Верните воду в график")
        case .activityPreparation:
            return text("coach.final.title.prepare", fallback, "Постарайтесь подготовиться к тренировке")
        case .postActivityRecovery, .recovery:
            return text("coach.final.title.recovery", fallback, "Сейчас важнее отдохнуть")
        case .readiness:
            return text("coach.final.title.readiness", fallback, "Держите день спокойным")
        case .tomorrowProtection:
            return text("coach.final.title.tomorrow", fallback, "Сохраните силы на завтра")
        case .stableOverview:
            return text("coach.final.title.stable", fallback, "Сегодня нет причин менять план")
        case .hydration:
            return text("coach.final.title.hydration", fallback, "Возьмите воду")
        case .fuel:
            return text("coach.final.title.fuel", fallback, "Возьмите перекус")
        }
    }

    private static func subtitleText(owner: CoachFinalStoryOwner, fallback: String) -> CoachFinalStoryText {
        switch owner {
        case .activeActivity, .pacingExecution, .sustainableExecution:
            return text("coach.final.subtitle.live", fallback, "Сейчас важнее ровный темп, а не дополнительные цели.")
        case .fuelingDuringActivity:
            return text("coach.final.subtitle.fuelingLive", fallback, "Энергия уже требует действий.")
        case .hydrationExecution:
            return text("coach.final.subtitle.hydrationLive", fallback, "Сейчас важно попить воды.")
        case .activityPreparation:
            return text("coach.final.subtitle.prepare", fallback, "Следующая тренировка важнее напоминаний о воде или еде.")
        case .postActivityRecovery, .recovery:
            return text("coach.final.subtitle.recovery", fallback, "Полезная работа уже учтена. Остаток дня должен поддержать отдых.")
        case .readiness:
            return text("coach.final.subtitle.readiness", fallback, "Состояние тела сейчас важнее отдельных напоминаний.")
        case .tomorrowProtection:
            return text("coach.final.subtitle.tomorrow", fallback, "Сегодняшний выбор должен помочь завтрашней тренировке.")
        case .stableOverview:
            return text("coach.final.subtitle.stable", fallback, "День выглядит стабильным и не требует срочных исправлений.")
        case .hydration:
            return text("coach.final.subtitle.hydration", fallback, "Воды сейчас мало. Это легко поправить небольшими глотками.")
        case .fuel:
            return text("coach.final.subtitle.fuel", fallback, "Еда сейчас влияет на готовность к следующей тренировке.")
        }
    }

    private static func recommendationText(owner: CoachFinalStoryOwner, fallback: String) -> CoachFinalStoryText {
        switch owner {
        case .activeActivity, .pacingExecution, .sustainableExecution:
            return text("coach.final.recommendation.live", fallback, "Держите усилие ровным и завершите с запасом.")
        case .fuelingDuringActivity:
            return text("coach.final.recommendation.fuelingLive", fallback, "Поесть сейчас и продолжать по графику.")
        case .hydrationExecution:
            return text("coach.final.recommendation.hydrationLive", fallback, "Попейте маленькими глотками в ближайшие минуты.")
        case .activityPreparation:
            return text("coach.final.recommendation.prepare", fallback, "Начните легче обычного и оставьте интенсивность гибкой.")
        case .postActivityRecovery, .recovery:
            return text("coach.final.recommendation.recovery", fallback, "Восстановите базу: вода, нормальная еда и без лишней интенсивности.")
        case .readiness:
            return text("coach.final.recommendation.readiness", fallback, "Выберите один лёгкий блок и не добавляйте лишнюю нагрузку.")
        case .tomorrowProtection:
            return text("coach.final.recommendation.tomorrow", fallback, "Снизьте остаток дня и берегите сон.")
        case .stableOverview:
            return text("coach.final.recommendation.stable", fallback, "Продолжайте в привычном ритме.")
        case .hydration:
            return text("coach.final.recommendation.hydration", fallback, "Попейте постепенно и не начинайте сухим.")
        case .fuel:
            return text("coach.final.recommendation.fuel", fallback, "Добавьте простую еду, которую легко переварить.")
        }
    }

    private static func avoidText(owner: CoachFinalStoryOwner, guidance: CoachGuidanceV3) -> CoachFinalStoryText {
        let fallback = guidance.avoidNotes.first ?? guidance.screenStory?.beCarefulWith ?? "Do not add unnecessary intensity."
        switch owner {
        case .activeActivity, .pacingExecution, .sustainableExecution:
            return text("coach.final.avoid.live", fallback, "Не добавляйте лишний стресс в текущую тренировку.")
        case .fuelingDuringActivity:
            return text("coach.final.avoid.fuelingLive", fallback, "Не ждите голода на длинной работе.")
        case .hydrationExecution:
            return text("coach.final.avoid.hydrationLive", fallback, "Не догоняйте воду одним большим объёмом.")
        case .activityPreparation:
            return text("coach.final.avoid.prepare", fallback, "Не тратьте силы до начала основной тренировки.")
        case .postActivityRecovery, .recovery:
            return text("coach.final.avoid.recovery", fallback, "Не добавляйте нагрузку, когда отдых уже важнее.")
        case .readiness:
            return text("coach.final.avoid.readiness", fallback, "Не используйте хорошее самочувствие как повод добавлять лишнее.")
        case .tomorrowProtection:
            return text("coach.final.avoid.tomorrow", fallback, "Не занимайте силы у завтрашней тренировки.")
        case .stableOverview:
            return text("coach.final.avoid.stable", fallback, "Не добавляйте задачи там, где день уже идёт нормально.")
        case .hydration:
            return text("coach.final.avoid.hydration", fallback, "Воду лучше не догонять одним большим объёмом.")
        case .fuel:
            return text("coach.final.avoid.fuel", fallback, "Не откладывайте еду до момента, когда энергия уже провалится.")
        }
    }

    private static func supportSignals(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> [CoachFinalStorySupportSignal] {
        var signals: [CoachFinalStorySupportSignal] = []
        let nutrition = input.nutritionContext
        let waterRatio = ratio(
            current: nutrition?.waterCurrent ?? input.brain.metrics.waterLiters,
            goal: nutrition?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        )
        let waterCurrent = nutrition?.waterCurrent ?? input.brain.metrics.waterLiters
        let caloriesCurrent = nutrition?.caloriesCurrent ?? input.brain.metrics.calories
        let proteinCurrent = nutrition?.proteinCurrent ?? input.brain.metrics.protein
        let calorieRatio = ratio(
            current: caloriesCurrent,
            goal: input.brain.baseDayGoals.calories
        )
        let proteinRatio = ratio(
            current: proteinCurrent,
            goal: nutrition?.proteinGoal ?? input.brain.baseDayGoals.protein
        )

        let ownerIsPostActivityRecovery = owner == .postActivityRecovery
        let hydrationIsMeaningful = owner == .activityPreparation ||
            owner == .activeActivity ||
            ownerIsPostActivityRecovery
            ? (waterRatio < 0.45 && waterCurrent < 1.5 || input.brain.hydration == .depleted)
            : (waterRatio < 0.35 || input.brain.hydration == .depleted)
        if guidance.priority.focus != .hydrationBehind && hydrationIsMeaningful {
            signals.append(
                CoachFinalStorySupportSignal(
                    kind: .hydration,
                    title: hydrationSupportText(owner: owner, input: input, waterRatio: waterRatio),
                    icon: "drop.fill"
                )
            )
        }

        let fuelIsMeaningful = owner == .activityPreparation ||
            owner == .activeActivity ||
            ownerIsPostActivityRecovery
            ? (calorieRatio < 0.45 && caloriesCurrent < 1_200 ||
                proteinRatio < 0.50 && proteinCurrent < 50 ||
                nutrition?.needsProteinRecovery == true && proteinRatio < 0.75 && proteinCurrent < 70)
            : (calorieRatio < 0.25 && caloriesCurrent < 600)
        if guidance.priority.focus != .fuelBehind && fuelIsMeaningful {
            signals.append(
                CoachFinalStorySupportSignal(
                    kind: .fuel,
                    title: fuelSupportText(owner: owner, input: input, calorieRatio: calorieRatio),
                    icon: "bolt.fill"
                )
            )
        }

        if guidance.priority.limiter == .sleep {
            signals.append(
                CoachFinalStorySupportSignal(
                    kind: .sleep,
                    title: text("coach.final.signal.sleep", "Sleep is the limiter.", "Сон сейчас ограничивает готовность."),
                    icon: "moon.fill"
                )
            )
        }

        return Array(signals.prefix(3))
    }

    private static func hydrationSupportText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        waterRatio: Double
    ) -> CoachFinalStoryText {
        if owner == .postActivityRecovery || owner == .recovery {
            return dynamicText(
                "Drink 300-500 ml over the next hour.",
                russian: "Попейте воды в течение следующего часа."
            )
        }

        if owner == .activityPreparation || owner == .activeActivity {
            return dynamicText(
                "Drink a small amount before the start.",
                russian: "Несколько глотков перед стартом."
            )
        }

        if waterRatio < 0.20 || input.brain.hydration == .depleted {
            return dynamicText(
                "Hydration has not really started.",
                russian: "Воды почти не было."
            )
        }

        return dynamicText("Hydration is behind.", russian: "Воды отстаёт.")
    }

    private static func fuelSupportText(
        owner: CoachFinalStoryOwner,
        input: CoachInputSnapshot,
        calorieRatio: Double
    ) -> CoachFinalStoryText {
        if owner == .postActivityRecovery || owner == .recovery {
            return dynamicText(
                "Protein and carbs help absorb the work.",
                russian: "Белок и еда помогают усвоить нагрузку."
            )
        }

        if owner == .activityPreparation || owner == .activeActivity {
            return dynamicText(
                "Quick carbs make the start easier.",
                russian: "Простая еда облегчит старт."
            )
        }

        if calorieRatio < 0.20 || input.brain.fuel == .underfueled {
            return dynamicText(
                "Nutrition is materially behind.",
                russian: "Еда заметно отстаёт."
            )
        }

        return dynamicText("Nutrition is behind.", russian: "Еда отстаёт.")
    }

    private static func upNextContext(
        _ context: CoachFinalDecisionContext
    ) -> CoachFinalStoryUpNextContext? {
        guard let activity = context.selectedUpNext else {
            return nil
        }

        return CoachFinalStoryUpNextContext(
            activityID: activity.id,
            title: WeekFitCoachRuntimeLocalizedString(activity.title)
        )
    }

    private static func resolvedIcon(owner: CoachFinalStoryOwner, fallback: String) -> String {
        switch owner {
        case .activeActivity, .pacingExecution, .sustainableExecution:
            return fallback
        case .fuelingDuringActivity:
            return "bolt.fill"
        case .hydrationExecution:
            return "drop.fill"
        case .activityPreparation:
            return fallback.isEmpty ? "figure.run" : fallback
        case .postActivityRecovery, .recovery:
            return "heart.fill"
        case .readiness:
            return "checkmark.seal.fill"
        case .tomorrowProtection:
            return "moon.stars.fill"
        case .stableOverview:
            return "waveform.path.ecg.rectangle.fill"
        case .hydration:
            return "drop.fill"
        case .fuel:
            return "bolt.fill"
        }
    }

    private static func actionIcon(owner: CoachFinalStoryOwner) -> String {
        switch owner {
        case .hydration, .hydrationExecution:
            return "drop.fill"
        case .fuel, .fuelingDuringActivity:
            return "fork.knife"
        case .activeActivity, .pacingExecution, .sustainableExecution:
            return "speedometer"
        case .activityPreparation:
            return "figure.cooldown"
        case .postActivityRecovery, .recovery:
            return "heart.fill"
        case .tomorrowProtection:
            return "moon.fill"
        case .readiness, .stableOverview:
            return "checkmark"
        }
    }

    private static func activitySoon(
        in input: CoachInputSnapshot,
        matching predicate: (PlannedActivity) -> Bool
    ) -> Bool {
        input.dayContext.upcomingActivities.contains { activity in
            guard !activity.isCompleted, !activity.isSkipped else { return false }
            let minutes = activity.date.timeIntervalSince(input.now) / 60
            return minutes >= 0 && minutes <= 180 && predicate(activity)
        } || input.dayContext.allActivities.contains { activity in
            guard !activity.isCompleted, !activity.isSkipped else { return false }
            let end = Calendar.current.date(byAdding: .minute, value: activity.effectiveDurationMinutes, to: activity.date) ?? activity.date
            return activity.date <= input.now && input.now <= end && predicate(activity)
        }
    }

    private static func isHeatActivity(_ activity: PlannedActivity) -> Bool {
        CoachActivityContextResolverV3.kind(for: activity) == .heat
    }

    private static func minutesUntil(_ activity: PlannedActivity, from date: Date) -> Int? {
        let minutes = Int(activity.date.timeIntervalSince(date) / 60)
        return minutes >= 0 ? minutes : nil
    }

    private static func localHour(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }

    private static func ratio(current: Double, goal: Double) -> Double {
        guard goal > 0 else { return 1 }
        return max(0, current / goal)
    }

    private static func text(
        _ key: String,
        _ fallback: String,
        _ russianFallback: String
    ) -> CoachFinalStoryText {
        CoachFinalStoryText(
            key: key,
            fallback: fallback.trimmingCharacters(in: .whitespacesAndNewlines),
            russianFallback: russianFallback,
            parameters: [],
            russianParameters: []
        )
    }
}

struct CoachDayNarrativePresentation {
    let stateLabel: String
    let title: String
    let message: String
    let todayTitle: String
    let todayMessage: String
    let icon: String
    let color: Color

    static func resolve(
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> CoachDayNarrativePresentation? {
        let model = input.dayPriorityModel
        let nutrition = input.nutritionContext
        let constraints = DayConstraints(input: input)
        let isDemandingDay = model.dayGoal == .overload ||
            model.dayStressLevel == .overload ||
            model.dayStressLevel == .high
        let isRecoveryPriority = guidance.priority.focus == .recoveryNeeded ||
            guidance.priority.focus == .postActivityRecovery ||
            guidance.priority.priority == .recovery
        let visualStateIsMisleading = guidance.stateLabel == "GOOD TO GO" ||
            guidance.screenStory?.stateLabel == "GOOD TO GO" ||
            guidance.screenStory?.stateLabel == "ON TRACK"
        let isRecoveryPhase: Bool
        switch guidance.phase {
        case .recovering, .stable:
            isRecoveryPhase = true
        case .active, .preparing:
            isRecoveryPhase = false
        }

        guard isDemandingDay || isRecoveryPriority else { return nil }
        guard isRecoveryPhase || isRecoveryPriority || visualStateIsMisleading else { return nil }
        guard constraints.hasMeaningfulLimiter || visualStateIsMisleading || isRecoveryPriority else {
            return nil
        }

        let completedLine = accomplishmentLine(model: model, input: input)
        let limiterLine = constraints.limiterLine
        let protectionLine = protectionLine(model: model)
        let message = [
            completedLine,
            limiterLine,
            protectionLine
        ]
            .compactMap { $0 }
            .joined(separator: " ")

        return CoachDayNarrativePresentation(
            stateLabel: "RECOVERY PRIORITY",
            title: "Recovery is now the priority",
            message: message,
            todayTitle: "Recovery now leads the day",
            todayMessage: todayMessage(
                model: model,
                constraints: constraints,
                nutrition: nutrition
            ),
            icon: "bolt.shield.fill",
            color: WeekFitTheme.purple
        )
    }

    private static func accomplishmentLine(
        model: DayPriorityModel,
        input: CoachInputSnapshot
    ) -> String {
        if let primary = model.primarySession, primary.isCompleted {
            return "You completed the key workload today."
        }

        if input.dayContext.completedTrainingMinutes > 0 || input.dayContext.completedTrainingStressScore > 0 {
            return "Training work is complete for now."
        }

        return "Today has carried a demanding training load."
    }

    private static func protectionLine(model: DayPriorityModel) -> String? {
        switch model.protectionTarget {
        case .tomorrow:
            return "Protect tomorrow by keeping the rest of today easy."
        case .recovery:
            return "Protect recovery before adding more stress."
        case .primarySession:
            return "Protect the work by letting adaptation start now."
        case .consistency:
            return "Protect consistency by not adding extra fatigue."
        }
    }

    private static func todayMessage(
        model: DayPriorityModel,
        constraints: DayConstraints,
        nutrition: CoachNutritionContext?
    ) -> String {
        if constraints.hasFuelLimiter && constraints.hasHydrationLimiter {
            return "The day was demanding, and fuel plus hydration are now behind. Start recovery before adding more stress."
        }

        if constraints.hasFuelLimiter {
            return "The day was demanding, and fueling is now the limiter. Eat enough to support recovery."
        }

        if constraints.hasHydrationLimiter {
            return "The day was demanding, and hydration is now the limiter. Rehydrate steadily before the next block."
        }

        if model.protectionTarget == .tomorrow {
            return "The day was demanding. Downshift now so tomorrow's training is not compromised."
        }

        if nutrition?.needsProteinRecovery == true {
            return "The key work is done. Protein and recovery now matter more than adding load."
        }

        return "The key work is done. Recovery now matters more than adding load."
    }
}

enum CoachPresentationCopy {
    static func normalize(
        stateLabel: String,
        title: String,
        message: String,
        recommendation: String,
        icon: String,
        color: Color,
        input: CoachInputSnapshot,
        guidance: CoachGuidanceV3
    ) -> (stateLabel: String, title: String, message: String, recommendation: String, icon: String, color: Color) {
        let noUpcomingActivity = input.dayContext.upcomingTrainingActivities.isEmpty &&
            input.dayContext.upcomingActivities.filter { !$0.isCompleted && !$0.isSkipped }.isEmpty

        if guidance.priority.focus == .performanceReadiness && noUpcomingActivity {
            return (
                stateLabel: localized(english: "READINESS", russian: "ГОТОВНОСТЬ"),
                title: localized(english: "Keep today light", russian: "Держите день лёгким"),
                message: localized(
                    english: "Recovery looks good, but recent load still matters. Use easy movement and avoid turning the morning into another hard session.",
                    russian: "Самочувствие хорошее, но недавняя нагрузка всё ещё важна. Двигайтесь легко и не добавляйте утром ещё одну тяжёлую тренировку."
                ),
                recommendation: localized(
                    english: "Choose one easy block, keep heat conservative, and let food and water support the day.",
                    russian: "Выберите один лёгкий блок, сауну спокойной, еду и воду — поддержкой дня."
                ),
                icon: "heart.fill",
                color: CoachPalette.stable
            )
        }

        if WeekFitCurrentLocale().identifier.hasPrefix("ru") {
            return (
                stateLabel: runtimeLocalized(stateLabel, fallback: stateLabel),
                title: runtimeLocalized(title, fallback: title),
                message: runtimeLocalized(message, fallback: message),
                recommendation: runtimeLocalized(recommendation, fallback: recommendation),
                icon: icon,
                color: color
            )
        }

        return (stateLabel, title, message, recommendation, icon, color)
    }

    private static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }

    private static func runtimeLocalized(_ value: String, fallback: String) -> String {
        let localized = WeekFitCoachRuntimeLocalizedString(value)
        guard localized != value else { return fallback }
        return localized
    }
}

private struct DayConstraints {
    let hasFuelLimiter: Bool
    let hasHydrationLimiter: Bool
    let hasProteinLimiter: Bool

    init(input: CoachInputSnapshot) {
        let nutrition = input.nutritionContext
        let calorieRatio = Self.ratio(
            current: nutrition?.caloriesCurrent ?? input.brain.metrics.calories,
            goal: input.brain.baseDayGoals.calories
        )
        let proteinRatio = Self.ratio(
            current: nutrition?.proteinCurrent ?? input.brain.metrics.protein,
            goal: input.brain.baseDayGoals.protein
        )
        let waterRatio = Self.ratio(
            current: nutrition?.waterCurrent ?? input.brain.metrics.waterLiters,
            goal: nutrition?.waterGoal ?? input.brain.fullDayGoals.waterLiters
        )

        hasFuelLimiter = calorieRatio < 0.45 ||
            proteinRatio < 0.35
        hasHydrationLimiter = input.brain.hydration == .depleted ||
            input.brain.hydration == .behind ||
            waterRatio < 0.60
        hasProteinLimiter = proteinRatio < 0.50
    }

    var hasMeaningfulLimiter: Bool {
        hasFuelLimiter || hasHydrationLimiter || hasProteinLimiter
    }

    var limiterLine: String? {
        switch (hasFuelLimiter, hasHydrationLimiter, hasProteinLimiter) {
        case (true, true, true):
            return "Recovery, hydration and fueling are now the limiting factors, with protein still behind."
        case (true, true, false):
            return "Recovery, hydration and fueling are now the limiting factors."
        case (true, false, true):
            return "Recovery and fueling are now the limiting factors, with protein still behind."
        case (true, false, false):
            return "Recovery and fueling are now the limiting factors."
        case (false, true, true):
            return "Recovery and hydration are now the limiting factors, with protein still behind."
        case (false, true, false):
            return "Recovery and hydration are now the limiting factors."
        case (false, false, true):
            return "Recovery and protein are now the limiting factors."
        case (false, false, false):
            return nil
        }
    }

    private static func ratio(current: Double, goal: Double) -> Double {
        guard goal > 0 else { return 1 }
        return current / goal
    }
}

extension CoachRationalePresentation {
    static func resolve(from input: CoachInputSnapshot) -> CoachRationalePresentation? {
        guard let active = input.dayContext.allActivities.first(where: { isActiveActivity($0, now: input.now) }) ??
                input.brain.activities.first(where: { isActiveActivity($0, now: input.now) }) else {
            return nil
        }

        let model = input.dayPriorityModel
        let target = rationaleTarget(
            active: active,
            model: model
        )
        guard let target else { return nil }

        let rationale = rationaleCopy(
            active: active,
            target: target,
            model: model
        )

        return CoachRationalePresentation(
            title: rationale.title,
            message: rationale.message,
            icon: icon(for: target),
            color: WeekFitTheme.meal,
            sourceActivityID: target.id
        )
    }

    private static func isActiveActivity(_ activity: PlannedActivity, now: Date) -> Bool {
        guard !activity.isCompleted, !activity.isSkipped else { return false }
        let end = Calendar.current.date(
            byAdding: .minute,
            value: activity.effectiveDurationMinutes,
            to: activity.date
        ) ?? activity.date

        return activity.date <= now && now <= end
    }

    private static func cleanTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Training" : trimmed
    }

    private static func activeActivityName(_ activity: PlannedActivity) -> String {
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()
        if title.contains("walk") || type.contains("walk") {
            return "walk"
        }
        return "session"
    }

    private static func rationaleTarget(
        active: PlannedActivity,
        model: DayPriorityModel
    ) -> PlannedActivity? {
        if let primary = model.primarySession, primary.id != active.id {
            return primary
        }

        if let secondary = model.secondarySession, secondary.id != active.id {
            return secondary
        }

        return nil
    }

    private static func rationaleCopy(
        active: PlannedActivity,
        target: PlannedActivity,
        model: DayPriorityModel
    ) -> (title: String, message: String) {
        let targetName = cleanTitle(target.title)
        let activeName = activeActivityName(active)
        let kind = CoachActivityContextResolverV3.kind(for: target)
        let load = CoachActivityContextResolverV3.load(for: target)

        if model.protectionTarget == .tomorrow {
            return (
                title: "Protect tomorrow",
                message: "Tomorrow carries real demand. Keep this \(activeName) easy so today supports recovery instead of borrowing from the next training day."
            )
        }

        switch kind {
        case .endurance:
            return (
                title: "Protect the main effort",
                message: "\(targetName) is the key workload today. Keep this \(activeName) relaxed so you preserve legs and fueling for the main effort."
            )

        case .workout:
            let loadPhrase = load == .high || load == .extreme
                ? "the highest-value training block"
                : "the priority training block"
            return (
                title: "Save quality for training",
                message: "\(targetName) is \(loadPhrase) today. Use this \(activeName) to stay loose, not to add fatigue before loading."
            )

        case .heat:
            return (
                title: "Arrive settled for heat",
                message: "\(targetName) will add heat stress. Keep this \(activeName) easy so you start hydrated, calm, and not already taxed."
            )

        case .recovery:
            return (
                title: "Keep the day restorative",
                message: "\(targetName) is meant to support recovery. Keep this \(activeName) easy so the day stays restorative, not draining."
            )

        case .meal:
            return (
                title: "Keep digestion easy",
                message: "\(targetName) is the next useful reset. Keep this \(activeName) easy so appetite and digestion stay steady."
            )

        case .other:
            return (
                title: "Protect what comes next",
                message: "\(targetName) is the next meaningful block. Keep this \(activeName) easy so you arrive fresh instead of carrying extra fatigue."
            )
        }
    }

    private static func icon(for activity: PlannedActivity) -> String {
        let text = "\(activity.title) \(activity.type)".lowercased()
        if text.contains("core") || text.contains("strength") || text.contains("gym") {
            return "figure.core.training"
        }
        if text.contains("run") {
            return "figure.run"
        }
        if text.contains("ride") || text.contains("bike") || text.contains("cycle") {
            return "bicycle"
        }
        return "figure.strengthtraining.traditional"
    }
}

func validTitle(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return trimmed
}
