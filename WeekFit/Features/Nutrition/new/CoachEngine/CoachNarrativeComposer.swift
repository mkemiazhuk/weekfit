import Foundation

struct CoachComposedNarrative: Hashable {
    let title: String
    let myRead: String
    let myRecommendation: String
    let beCarefulWith: String
    let why: String?
    let todayTitle: String
    let todayMessage: String
    let voice: CoachNarrativeVoice
    let strategy: CoachNarrativeStrategy
    let dayStory: CoachNarrativeDayStory
}

enum CoachNarrativeVoice: String, Hashable {
    case strategic
    case performance
    case recovery
    case direct
    case supportive
}

enum CoachNarrativeStrategy: String, Hashable {
    case protectAdaptation
    case reduceRisk
    case preserveKeySession
    case recoverNow
    case keepPlanCalm
}

enum CoachNarrativeTimeOfDay: String, Hashable {
    case morning
    case midday
    case afternoon
    case evening
    case night
}

enum CoachNarrativeDayStory: String, Hashable {
    case recoveryDay
    case highLoadDay
    case overloadDay
    case performanceDay
    case protectionDay
    case rebuildDay
    case consistencyDay
    case preparationDay
}

enum CoachNarrativeHydrationState: String, Hashable {
    case depleted
    case improving
    case adequate
}

struct CoachNarrativeContext {
    let frame: CoachDayDecisionFrame
    let priority: CoachDayPriorityResult
    let timeOfDay: CoachNarrativeTimeOfDay
    let completedDayStory: String
    let remainingActivity: RemainingActivityRiskAssessment?
    let actualLoad: CoachActualLoadSnapshot
    let recovery: CoachRecoveryContext?
    let nutrition: CoachNutritionContext?
    let voice: CoachNarrativeVoice
    let strategy: CoachNarrativeStrategy
    let dayStory: CoachNarrativeDayStory
    let hydrationState: CoachNarrativeHydrationState
    let variationSeed: Int
}

enum CoachNarrativeComposer {

    static func context(
        frame: CoachDayDecisionFrame,
        priority: CoachDayPriorityResult,
        decisionContext: CoachDecisionContext
    ) -> CoachNarrativeContext {
        let timeOfDay = resolveTimeOfDay(decisionContext.dayContext.now)
        let strategy = resolveStrategy(frame: frame, priority: priority)
        let dayStory = resolveDayStory(frame: frame, priority: priority, actualLoad: decisionContext.actualLoad)
        let hydrationState = resolveHydrationState(decisionContext)
        let seed = stableSeed(
            [
                dayStory.rawValue,
                hydrationState.rawValue,
                frame.dayType.rawValue,
                frame.primaryDriver.rawValue,
                frame.planStatus.rawValue,
                frame.recommendationIntent.rawValue,
                frame.remainingActivityRisk?.activityTitle ?? "none",
                timeOfDay.rawValue,
                "\(Int(decisionContext.actualLoad.activeCalories.rounded()))"
            ].joined(separator: "|")
        )
        let voice = resolveVoice(
            frame: frame,
            strategy: strategy,
            timeOfDay: timeOfDay,
            seed: seed
        )

        return CoachNarrativeContext(
            frame: frame,
            priority: priority,
            timeOfDay: timeOfDay,
            completedDayStory: frame.dayRead.past,
            remainingActivity: frame.remainingActivityRisk,
            actualLoad: decisionContext.actualLoad,
            recovery: decisionContext.recoveryContext,
            nutrition: decisionContext.nutritionContext,
            voice: voice,
            strategy: strategy,
            dayStory: dayStory,
            hydrationState: hydrationState,
            variationSeed: seed
        )
    }

    static func compose(_ context: CoachNarrativeContext) -> CoachComposedNarrative {
        let title = composeTitle(context)
        let read = composeRead(context)
        let recommendation = composeRecommendation(context)
        let trap = composeTrap(context)
        let why = composeWhy(context)

        return CoachComposedNarrative(
            title: title,
            myRead: read,
            myRecommendation: recommendation,
            beCarefulWith: trap,
            why: why,
            todayTitle: title,
            todayMessage: conciseTodayMessage(read: read, recommendation: recommendation),
            voice: context.voice,
            strategy: context.strategy,
            dayStory: context.dayStory
        )
    }

    static func debugLines(for narrative: CoachComposedNarrative) -> [String] {
        [
            "CoachNarrativeDebug.voice=\(narrative.voice.rawValue)",
            "CoachNarrativeDebug.strategy=\(narrative.strategy.rawValue)",
            "CoachNarrativeDebug.dayStory=\(narrative.dayStory.rawValue)"
        ]
    }
}

private extension CoachNarrativeComposer {

    static func composeTitle(_ context: CoachNarrativeContext) -> String {
        if context.strategy == .preserveKeySession,
           let primary = context.frame.primarySession {
            return "Protect \(shortActivityName(primary))"
        }

        if context.frame.planStatus == .complete {
            return storyTitle(context)
        }

        if let risk = context.remainingActivity {
            switch risk.recommendedAction {
            case .skip, .moveToTomorrow:
                return risk.category == "running" ? "Move the run" : "Move the session"
            case .replace:
                return risk.category == "running" ? "Replace the run" : "Adjust the plan"
            case .makeEasy, .shorten:
                return risk.category == "running" ? "Keep it very easy" : "Lower the ceiling"
            case .keep where risk.category == "recovery":
                return "Keep it recovery-only"
            case .keep:
                return "Keep the plan easy"
            }
        }

        switch context.strategy {
        case .recoverNow:
            return storyTitle(context)
        case .protectAdaptation:
            return storyTitle(context)
        case .reduceRisk:
            return "Lower today’s risk"
        case .preserveKeySession:
            return "Protect the key session"
        case .keepPlanCalm:
            return "Keep the plan calm"
        }
    }

    static func composeRead(_ context: CoachNarrativeContext) -> String {
        var sentences: [String] = []

        sentences.append(storyRead(context))

        if !context.completedDayStory.isEmpty {
            sentences.append(context.completedDayStory)
        }

        if !storyReadAlreadyCoversDriver(context) {
            sentences.append(dayMeaningSentence(context))
        }

        if let risk = context.remainingActivity,
           context.frame.planStatus.requiresPlanChange || context.frame.planStatus == .complete {
            sentences.append(activityMeaningSentence(risk: risk, context: context))
        }

        return uniqueSentences(sentences).joined(separator: " ")
    }

    static func composeRecommendation(_ context: CoachNarrativeContext) -> String {
        if context.strategy == .preserveKeySession,
           let primary = context.frame.primarySession {
            let name = shortActivityName(primary).lowercased()
            return select(
                [
                    "Keep the day pointed at \(name). Eat normally, keep fluids steady, and let the first block confirm readiness.",
                    "Make the rest of the day support \(name): steady fuel, steady fluids, and no extra work around it.",
                    "Protect the session by arriving fresh. Cover the basics, then open easier than you think you need to."
                ],
                seed: context.variationSeed
            )
        }

        if let risk = context.remainingActivity {
            return activityRecommendation(risk: risk, context: context)
        }

        switch context.frame.planStatus {
        case .cancel:
            return voiceLine(
                context,
                strategic: "Remove the remaining training and let recovery become the plan.",
                performance: "Protect the work already done. No more training belongs today.",
                recovery: "Give the body the rest of the day to absorb the load.",
                direct: "Cancel the remaining training today.",
                supportive: "You have done enough today. Let the rest of the day be recovery."
            )
        case .replace:
            return voiceLine(
                context,
                strategic: "Replace the remaining training with recovery work, or move it to a day that can absorb it.",
                performance: "Protect today’s progress by trading the remaining session for recovery.",
                recovery: "Choose easy recovery work now; the adaptation needs space.",
                direct: "Do not add another training session today.",
                supportive: "You can let the plan change today. Recovery is the useful next step."
            )
        case .downgrade, .adjust:
            return voiceLine(
                context,
                strategic: "Keep only the version of the plan that supports recovery and does not add meaningful stress.",
                performance: "Lower the ceiling and finish with reserve.",
                recovery: "Make the remaining work gentle enough that it helps recovery instead of competing with it.",
                direct: "Cut the intensity and keep it easy.",
                supportive: "If you still want movement, keep it short, easy, and optional."
            )
        case .complete:
            return storyRecommendation(context)
        case .valid:
            return "Continue the plan, but keep the support work calm and purposeful."
        }
    }

    static func composeTrap(_ context: CoachNarrativeContext) -> String {
        if context.strategy == .preserveKeySession {
            return select(
                [
                    "Spending energy before the session you actually care about.",
                    "Letting support gaps become the main story.",
                    "Turning preparation into extra training."
                ],
                seed: context.variationSeed
            )
        }

        if let risk = context.remainingActivity {
            if risk.category == "recovery" {
                return "Turning recovery work into another workout."
            }
            return select(
                [
                    "Treating the calendar as more important than the day you actually had.",
                    "Chasing completion when the useful training signal is already there.",
                    "Letting a planned session become a fatigue tax."
                ],
                seed: context.variationSeed
            )
        }

        switch context.strategy {
        case .recoverNow, .protectAdaptation:
            return storyTrap(context)
        case .reduceRisk:
            return "Letting the schedule override the body’s current ceiling."
        case .preserveKeySession:
            return "Spending readiness before the key session starts."
        case .keepPlanCalm:
            return "Turning a stable day into a problem to solve."
        }
    }

    static func composeWhy(_ context: CoachNarrativeContext) -> String? {
        var evidence: [String] = []

        if context.actualLoad.activeCalories >= 750 ||
            context.actualLoad.activityProgress.map({ $0 >= 1.5 }) == true {
            evidence.append("actual activity load is already above target")
        }

        if let recovery = context.recovery, recovery.recoveryPercent > 0, recovery.recoveryPercent < 60 {
            evidence.append("recovery is limited")
        }

        if context.contributorsContain(.underfueled) {
            evidence.append("fueling could use support")
        }

        if context.contributorsContain(.hydrationBehind) {
            switch context.hydrationState {
            case .depleted:
                evidence.append("hydration needs attention")
            case .improving:
                evidence.append("hydration is improving")
            case .adequate:
                evidence.append("hydration is now adequate")
            }
        }

        if context.contributorsContain(.proteinBehind) {
            evidence.append("protein could use attention")
        }

        if context.contributorsContain(.recentSauna) {
            evidence.append("sauna added heat stress")
        }

        if context.contributorsContain(.tomorrowDemand) {
            evidence.append("tomorrow needs freshness")
        }

        if let risk = context.remainingActivity,
           risk.riskLevel == .high || risk.riskLevel == .critical {
            evidence.append("the remaining \(activityNoun(risk)) carries real training cost")
        }

        guard !evidence.isEmpty else {
            return context.frame.primaryDriver == .none ? nil : driverWhy(context)
        }

        return "\(naturalList(evidence).capitalizedFirst). \(driverWhy(context))"
    }

    static func dayMeaningSentence(_ context: CoachNarrativeContext) -> String {
        let timePrefix: String
        switch context.timeOfDay {
        case .morning:
            timePrefix = "Already this morning"
        case .midday:
            timePrefix = "By midday"
        case .afternoon:
            timePrefix = "At this point in the afternoon"
        case .evening:
            timePrefix = "By evening"
        case .night:
            timePrefix = "At this point tonight"
        }

        switch context.frame.primaryDriver {
        case .accumulatedFatigue, .overloadRisk, .excessiveLoad:
            return voiceLine(
                context,
                strategic: "\(timePrefix), the main question is not whether you can do more; it is whether more work still has a return.",
                performance: "\(timePrefix), the useful training signal is already expensive enough to protect.",
                recovery: "\(timePrefix), the body still has work to do from what is already in the day.",
                direct: "\(timePrefix), accumulated load is now the limiter.",
                supportive: "\(timePrefix), you have already put meaningful work into the day."
            )
        case .poorSleep:
            return "\(timePrefix), sleep is narrowing how much quality work today can productively use."
        case .lowRecovery:
            return "\(timePrefix), recovery is the limiter that should shape the rest of the plan."
        case .tomorrowDemand:
            return "\(timePrefix), tomorrow’s demand makes freshness more valuable than squeezing in extra load."
        case .illness, .injury, .unsafeHeatStress:
            return "\(timePrefix), the safety cost is higher than the training upside."
        case .none:
            return "\(timePrefix), the plan still has room as long as the basics stay steady."
        }
    }

    static func activityMeaningSentence(
        risk: RemainingActivityRiskAssessment,
        context: CoachNarrativeContext
    ) -> String {
        let noun = activityNoun(risk)
        let duration = "\(risk.plannedDuration)-minute"
        switch risk.riskLevel {
        case .critical:
            return "That makes the planned \(duration) \(noun) a poor trade today."
        case .high:
            return "The planned \(duration) \(noun) is now more likely to add fatigue than fitness."
        case .medium:
            return "The planned \(noun) only fits if it stays easy enough to avoid becoming another stressor."
        case .low where risk.category == "recovery":
            return "\(risk.activityTitle) can still help if it stays recovery work."
        case .low:
            return "\(risk.activityTitle) still fits, but it should not expand beyond the plan."
        }
    }

    static func activityRecommendation(
        risk: RemainingActivityRiskAssessment,
        context: CoachNarrativeContext
    ) -> String {
        let noun = activityNoun(risk)
        switch risk.recommendedAction {
        case .keep where risk.category == "recovery":
            return "\(risk.activityTitle) is fine. Keep it gentle and finish feeling better than when you started."
        case .keep:
            return "Keep the \(noun), but do not add extra work around it."
        case .shorten, .makeEasy:
            let cap = risk.maxRecommendedDuration.map { "\($0) minutes" } ?? "a short version"
            let intensity = risk.maxRecommendedIntensity ?? "very easy"
            let replacement = risk.replacementSuggestion ?? "walking or stretching"
            return "Only keep the \(noun) if it stays \(cap) at \(intensity). Otherwise, switch to \(replacement)."
        case .replace:
            let cap = risk.maxRecommendedDuration.map { "\($0) minutes" } ?? "20 minutes"
            let intensity = risk.maxRecommendedIntensity ?? "very easy"
            let replacement = risk.replacementSuggestion ?? "recovery work"
            return "Replace the \(noun) with \(replacement), or cap it at \(cap) \(intensity) if you still want movement."
        case .skip:
            return "Skip the \(noun). The next useful adaptation comes from recovery."
        case .moveToTomorrow:
            return "Move the \(noun) to another day. Today’s job is to absorb the work already done."
        }
    }

    static func driverWhy(_ context: CoachNarrativeContext) -> String {
        switch context.frame.primaryDriver {
        case .accumulatedFatigue, .overloadRisk, .excessiveLoad:
            return "More work is unlikely to improve today’s outcome until the existing load is absorbed."
        case .poorSleep:
            return "Poor sleep lowers the ceiling for quality work, even when motivation is high."
        case .lowRecovery:
            return "Recovery is what turns the work into adaptation."
        case .tomorrowDemand:
            return "Freshness now protects the quality of tomorrow’s work."
        case .illness, .injury, .unsafeHeatStress:
            return "The risk is not worth the training upside."
        case .none:
            return "The decision is about keeping the day aligned, not fixing a problem."
        }
    }

    static func storyTitle(_ context: CoachNarrativeContext) -> String {
        switch context.dayStory {
        case .recoveryDay:
            return select(
                [
                    "Recovery leads today",
                    "Let recovery do the work",
                    "Keep the day restorative"
                ],
                seed: context.variationSeed
            )
        case .highLoadDay:
            return select(
                [
                    "Protect today’s work",
                    "The work is in the bank",
                    "Recovery is the next win"
                ],
                seed: context.variationSeed
            )
        case .overloadDay:
            return select(
                [
                    "Stop adding load",
                    "Protect today’s progress",
                    "Let the day end here"
                ],
                seed: context.variationSeed
            )
        case .performanceDay:
            return "Protect the key session"
        case .protectionDay:
            return select(
                [
                    "Protect tomorrow",
                    "Save the quality for tomorrow",
                    "Keep freshness available"
                ],
                seed: context.variationSeed
            )
        case .rebuildDay:
            return "Rebuild the base"
        case .consistencyDay:
            return "Keep the day steady"
        case .preparationDay:
            return "Prepare, do not spend"
        }
    }

    static func storyRead(_ context: CoachNarrativeContext) -> String {
        let prefix = storyTimePrefix(context)
        switch context.dayStory {
        case .recoveryDay:
            return voiceLine(
                context,
                strategic: "\(prefix), today is a recovery day: the value comes from lowering stress, not proving capacity.",
                performance: "\(prefix), the performance move is restraint.",
                recovery: "\(prefix), the body is still doing useful work in the background.",
                direct: "\(prefix), this is not a day to chase load.",
                supportive: "\(prefix), the day is asking for patience more than effort."
            )
        case .highLoadDay:
            if context.hydrationState == .improving {
                return "\(prefix), today is still a high-load day, but hydration is moving in the right direction."
            }
            return voiceLine(
                context,
                strategic: "\(prefix), today has become a high-load day.",
                performance: "\(prefix), the training signal is already in place.",
                recovery: "\(prefix), there is enough work in the system to recover from.",
                direct: "\(prefix), the day is already loaded.",
                supportive: "\(prefix), you have already done meaningful work today."
            )
        case .overloadDay:
            if context.hydrationState == .improving {
                return "\(prefix), the day is still overloaded, but one recovery lever is improving."
            }
            return voiceLine(
                context,
                strategic: "\(prefix), the story of the day has shifted from building fitness to managing overload.",
                performance: "\(prefix), protecting the work matters more than adding another signal.",
                recovery: "\(prefix), the body has more to absorb than it can benefit from adding to.",
                direct: "\(prefix), this is now an overload day.",
                supportive: "\(prefix), nothing important is left to prove today."
            )
        case .performanceDay:
            return "\(prefix), the day is organized around one important session, so everything else should support that work."
        case .protectionDay:
            return "\(prefix), the best thing you can do for the next training opportunity is keep freshness available."
        case .rebuildDay:
            return "\(prefix), this is a rebuild day: enough movement to keep rhythm, not enough stress to dig deeper."
        case .consistencyDay:
            return "\(prefix), the day is about consistency and control, not forcing a bigger training story."
        case .preparationDay:
            return "\(prefix), the day is still a preparation day, so the goal is to arrive ready rather than spend readiness early."
        }
    }

    static func storyRecommendation(_ context: CoachNarrativeContext) -> String {
        switch context.dayStory {
        case .overloadDay:
            if context.hydrationState == .improving {
                return "Keep fluids steady, keep the evening light, and do not add another session."
            }
            return voiceLine(
                context,
                strategic: "Keep the rest of the day light and avoid adding another session.",
                performance: "Protect today’s progress by ending the training work here.",
                recovery: "Let the evening stay easy so the body can start absorbing the load.",
                direct: "Do not add another session tonight.",
                supportive: "Call the work done and let recovery take over."
            )
        case .highLoadDay:
            if context.hydrationState == .improving {
                return "Keep the recovery trend going: steady fluids, easy movement only, and a normal meal if food is still behind."
            }
            return voiceLine(
                context,
                strategic: "Shift the rest of the day toward recovery and keep movement optional.",
                performance: "Protect the work already done; keep the evening easy.",
                recovery: "Choose recovery work only: gentle mobility, stretching, or an easy walk.",
                direct: "Keep the rest of the day easy.",
                supportive: "You have enough in the bank. Keep the rest light."
            )
        case .protectionDay:
            return "Keep the rest of today quiet, finish the basics, and preserve freshness for tomorrow."
        default:
            return voiceLine(
                context,
                strategic: "The highest return now comes from recovery.",
                performance: "Protect today’s work instead of chasing more fatigue.",
                recovery: "Let the body finish the work it has already started.",
                direct: "Do not add more load.",
                supportive: "You have already done enough today."
            )
        }
    }

    static func storyTrap(_ context: CoachNarrativeContext) -> String {
        switch context.dayStory {
        case .overloadDay:
            return select(
                [
                    "Trying to win the day twice.",
                    "Treating more fatigue as more fitness.",
                    "Letting the calendar talk you into extra load."
                ],
                seed: context.variationSeed
            )
        case .highLoadDay:
            return select(
                [
                    "Chasing a little more after the useful work is already done.",
                    "Turning a good training day into an overreach.",
                    "Adding work because the day still has time left."
                ],
                seed: context.variationSeed
            )
        case .protectionDay:
            return "Spending tomorrow’s freshness tonight."
        default:
            return select(
                [
                    "Adding more work because there is still time left.",
                    "Mistaking more fatigue for more fitness.",
                    "Trying to turn every day into a training day."
                ],
                seed: context.variationSeed
            )
        }
    }

    static func storyTimePrefix(_ context: CoachNarrativeContext) -> String {
        switch context.timeOfDay {
        case .morning:
            return "This morning"
        case .midday:
            return "By midday"
        case .afternoon:
            return "By afternoon"
        case .evening:
            return "By evening"
        case .night:
            return "Tonight"
        }
    }

    static func storyReadAlreadyCoversDriver(_ context: CoachNarrativeContext) -> Bool {
        switch context.dayStory {
        case .highLoadDay, .overloadDay, .performanceDay, .protectionDay, .rebuildDay, .preparationDay:
            return true
        case .recoveryDay, .consistencyDay:
            return context.frame.primaryDriver == .none
        }
    }

    static func resolveDayStory(
        frame: CoachDayDecisionFrame,
        priority: CoachDayPriorityResult,
        actualLoad: CoachActualLoadSnapshot
    ) -> CoachNarrativeDayStory {
        if priority.reasons.contains("dayDecisionFrame=primarySessionProtection") {
            return .performanceDay
        }

        if frame.primaryDriver == .tomorrowDemand {
            return .protectionDay
        }

        if frame.planStatus == .complete {
            if frame.dayType == .overload ||
                actualLoad.activityProgress.map({ $0 >= 1.5 }) == true ||
                actualLoad.activeCalories >= 750 {
                return .highLoadDay
            }
            return .recoveryDay
        }

        if frame.planStatus.requiresPlanChange {
            if frame.dayType == .overload ||
                frame.remainingActivityRisk?.riskLevel == .critical ||
                actualLoad.activityProgress.map({ $0 >= 1.5 }) == true {
                return .overloadDay
            }
            return .protectionDay
        }

        switch frame.dayType {
        case .recovery, .deload:
            return .recoveryDay
        case .training:
            return frame.recommendationIntent == .prepareForSession ? .preparationDay : .consistencyDay
        case .performance:
            return .performanceDay
        case .overload:
            return .overloadDay
        case .maintenance:
            return .consistencyDay
        }
    }

    static func resolveHydrationState(_ context: CoachDecisionContext) -> CoachNarrativeHydrationState {
        let ratio: Double
        if let nutrition = context.nutritionContext, nutrition.waterGoal > 0 {
            ratio = nutrition.waterCurrent / nutrition.waterGoal
        } else {
            ratio = context.brain.current.waterProgress
        }
        if ratio < 0.50 {
            return .depleted
        }
        if ratio < 0.70 {
            return .improving
        }
        return .adequate
    }

    static func resolveStrategy(
        frame: CoachDayDecisionFrame,
        priority: CoachDayPriorityResult
    ) -> CoachNarrativeStrategy {
        if priority.reasons.contains("dayDecisionFrame=primarySessionProtection") {
            return .preserveKeySession
        }

        switch frame.planStatus {
        case .complete:
            return .recoverNow
        case .cancel, .replace:
            return frame.remainingActivityRisk?.riskLevel == .critical ? .reduceRisk : .protectAdaptation
        case .downgrade, .adjust:
            return .reduceRisk
        case .valid:
            return .keepPlanCalm
        }
    }

    static func resolveVoice(
        frame: CoachDayDecisionFrame,
        strategy: CoachNarrativeStrategy,
        timeOfDay: CoachNarrativeTimeOfDay,
        seed: Int
    ) -> CoachNarrativeVoice {
        if strategy == .preserveKeySession {
            return .performance
        }

        if strategy == .reduceRisk,
           frame.remainingActivityRisk?.riskLevel == .critical {
            return .direct
        }

        if strategy == .recoverNow {
            return select([.recovery, .supportive, .strategic], seed: seed)
        }

        if timeOfDay == .evening || timeOfDay == .night {
            return select([.recovery, .strategic, .supportive], seed: seed)
        }

        switch frame.primaryDriver {
        case .accumulatedFatigue, .overloadRisk, .excessiveLoad:
            return select([.strategic, .performance, .direct], seed: seed)
        case .poorSleep, .lowRecovery:
            return select([.recovery, .supportive, .strategic], seed: seed)
        case .tomorrowDemand:
            return select([.strategic, .performance, .recovery], seed: seed)
        case .illness, .injury, .unsafeHeatStress:
            return .direct
        case .none:
            return .supportive
        }
    }

    static func resolveTimeOfDay(_ date: Date) -> CoachNarrativeTimeOfDay {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11:
            return .morning
        case 11..<14:
            return .midday
        case 14..<18:
            return .afternoon
        case 18..<23:
            return .evening
        default:
            return .night
        }
    }

    static func conciseTodayMessage(read: String, recommendation: String) -> String {
        let sentence = recommendation
            .split(whereSeparator: { ".!?".contains($0) })
            .first
            .map(String.init) ?? recommendation
        return sentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func voiceLine(
        _ context: CoachNarrativeContext,
        strategic: String,
        performance: String,
        recovery: String,
        direct: String,
        supportive: String
    ) -> String {
        switch context.voice {
        case .strategic:
            return strategic
        case .performance:
            return performance
        case .recovery:
            return recovery
        case .direct:
            return direct
        case .supportive:
            return supportive
        }
    }

    static func select<T>(_ values: [T], seed: Int) -> T {
        values[abs(seed) % values.count]
    }

    static func stableSeed(_ value: String) -> Int {
        value.unicodeScalars.reduce(0) { partial, scalar in
            partial &* 31 &+ Int(scalar.value)
        }
    }

    static func activityNoun(_ risk: RemainingActivityRiskAssessment) -> String {
        let title = risk.activityTitle.lowercased()
        if title.contains("run") || risk.category == "running" { return "run" }
        if title.contains("cycl") || title.contains("ride") || risk.category == "cycling" { return "ride" }
        if title.contains("stretch") || risk.category == "recovery" { return "recovery work" }
        if title.contains("walk") { return "walk" }
        if title.contains("sauna") { return "sauna" }
        return "session"
    }

    static func shortActivityName(_ activity: PlannedActivity) -> String {
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "the session" }
        let lowered = title.lowercased()
        if lowered.contains("cycl") || lowered.contains("ride") { return "the ride" }
        if lowered.contains("run") { return "the run" }
        return title
    }

    static func naturalList(_ parts: [String]) -> String {
        switch parts.count {
        case 0:
            return ""
        case 1:
            return parts[0]
        case 2:
            return "\(parts[0]) and \(parts[1])"
        default:
            return "\(parts.dropLast().joined(separator: ", ")), and \(parts.last ?? "")"
        }
    }

    static func uniqueSentences(_ sentences: [String]) -> [String] {
        var seen = Set<String>()
        return sentences.compactMap { sentence in
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return trimmed
        }
    }
}

private extension CoachNarrativeContext {
    func contributorsContain(_ contributor: CoachContributor) -> Bool {
        frame.contributors.contains(contributor)
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
