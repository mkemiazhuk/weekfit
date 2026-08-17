import Foundation

/// Preparation / on-trail copy for substantial hike-like walks.
/// Keeps the `.walkLightDay` scenario; only the words change with duration and phase.
enum CoachLongHikeCopy {

    private static let multiHourMinutes = 180
    private static let allDayMinutes = 300

    static func isSubstantialHike(input: CoachCopyBuildInput) -> Bool {
        guard input.isFocusHikeLike else { return false }
        let minutes = resolvedMinutes(input)
        return minutes >= 60
            || input.modifiers.durationBand == .long
            || input.modifiers.durationBand == .extended
    }

    static func draft(for input: CoachCopyBuildInput) -> CoachCopyRegistryScenarios.Draft {
        let minutes = resolvedMinutes(input)
        let hoursEN = hoursLabel(for: minutes)
        let hoursRU = hoursLabelRu(for: minutes)
        let phase = CoachWalkRecoveryActionCopy.phase(for: input)

        switch phase {
        case .upcoming:
            return prepDraft(minutes: minutes, hoursEN: hoursEN, hoursRU: hoursRU)
        case .live:
            return liveDraft(minutes: minutes, hoursEN: hoursEN, hoursRU: hoursRU)
        case .completed:
            return completedDraft(hoursEN: hoursEN, hoursRU: hoursRU)
        }
    }

    /// Why-row prep cues for long hikes — fitted into the 3-line budget by the registry.
    static func supportingSignals(for input: CoachCopyBuildInput) -> [CoachBilingualText] {
        guard isSubstantialHike(input: input), input.scenario == .walkLightDay else { return [] }
        let minutes = resolvedMinutes(input)
        let phase = CoachWalkRecoveryActionCopy.phase(for: input)

        switch phase {
        case .upcoming:
            if minutes >= allDayMinutes {
                return [
                    .en(
                        "Pack water for the whole outing — top up before you leave.",
                        "Воды возьмите на весь выход — долейте перед выходом."
                    ),
                    .en(
                        "Snacks early and often — don't wait until empty.",
                        "Перекусы рано и часто — не ждите, пока совсем пусто."
                    ),
                    .en(
                        "Leave turnaround margin — the way back still counts.",
                        "Оставьте запас на разворот — обратная дорога тоже считается."
                    )
                ]
            }
            if minutes >= multiHourMinutes {
                return [
                    .en(
                        "Bring more water than feels necessary.",
                        "Воды возьмите больше, чем кажется нужным."
                    ),
                    .en(
                        "Pack a snack you can eat without stopping long.",
                        "Возьмите перекус, который можно съесть на ходу."
                    ),
                    .en(
                        "Check shoes, socks, and a simple blister fix.",
                        "Проверьте обувь, носки и простой пластырь от мозолей."
                    )
                ]
            }
            return [
                .en(
                    "Water and a small snack before you start.",
                    "Вода и небольшой перекус до старта."
                ),
                .en(
                    "Start easier than the first climb invites.",
                    "Начните легче, чем провоцирует первый подъём."
                )
            ]
        case .live:
            return [
                .en(
                    "Sip early — don't wait for thirst to catch up.",
                    "Пейте заранее — не ждите сильной жажды."
                ),
                .en(
                    "Eat before energy dips, not after.",
                    "Ешьте до спада энергии, а не после."
                )
            ]
        case .completed:
            return [
                .en(
                    "Refill fluids and get a real meal soon.",
                    "Восполните жидкость и скоро съешьте нормальный приём пищи."
                )
            ]
        }
    }

    // MARK: - Drafts

    private static func prepDraft(
        minutes: Int,
        hoursEN: String,
        hoursRU: String
    ) -> CoachCopyRegistryScenarios.Draft {
        if minutes >= allDayMinutes {
            return CoachCopyRegistryScenarios.Draft(
                assessment: .en(
                    "About \(hoursEN) on trail — treat this as a full outing, not a stroll.",
                    "Около \(hoursRU) на маршруте — это полноценный выход, не прогулка."
                ),
                recommendation: .en(
                    "Pack water, salty snacks, and a light layer. Eat and drink before the first hard climb.",
                    "Возьмите воду, солёный перекус и лёгкий слой. Ешьте и пейте до первого серьёзного подъёма."
                ),
                avoid: .en(
                    "Don't leave hungry, under-watered, or without a turnaround plan.",
                    "Не выходите голодным, с малым запасом воды и без плана разворота."
                ),
                nextAction: .en(
                    "Lay out water, snacks, and layers — then leave at a sustainable pace.",
                    "Разложите воду, перекусы и слои — и выходите в устойчивом темпе."
                )
            )
        }

        if minutes >= multiHourMinutes {
            return CoachCopyRegistryScenarios.Draft(
                assessment: .en(
                    "About \(hoursEN) hike — real time on your feet, so prep matters.",
                    "Хайкинг около \(hoursRU) — много времени на ногах, подготовка важна."
                ),
                recommendation: .en(
                    "Bring water, a snack, and something for blisters. Start easier than the trail invites.",
                    "Возьмите воду, перекус и защиту от мозолей. Начните легче, чем провоцирует тропа."
                ),
                avoid: .en(
                    "Don't race the first climb or save all food for the end.",
                    "Не срывайтесь на первом подъёме и не оставляйте всю еду на конец."
                ),
                nextAction: .en(
                    "Fill a bottle, pocket a snack, check shoes — then ease into the first section.",
                    "Наполните бутылку, положите перекус, проверьте обувь — и мягко войдите в первый участок."
                )
            )
        }

        return CoachCopyRegistryScenarios.Draft(
            assessment: .en(
                "Hike day — give it the respect of a real outing.",
                "День хайкинга — отнеситесь как к настоящей вылазке."
            ),
            recommendation: .en(
                "Steady pace, early fuel, and leave margin for the way back.",
                "Ровный темп, еда заранее и запас сил на обратную дорогу."
            ),
            avoid: .en(
                "Don't start hard or skip food and water early.",
                "Не стартуйте жёстко и не откладывайте еду с водой на потом."
            ),
            nextAction: .en(
                "Check shoes, water, and start easier than you think.",
                "Проверьте обувь и воду — и начните легче, чем кажется нужным."
            )
        )
    }

    private static func liveDraft(
        minutes: Int,
        hoursEN: String,
        hoursRU: String
    ) -> CoachCopyRegistryScenarios.Draft {
        if minutes >= multiHourMinutes {
            return CoachCopyRegistryScenarios.Draft(
                assessment: .en(
                    "You're in a \(hoursEN) hike — protect the second half now.",
                    "Вы в хайкинге на \(hoursRU) — уже сейчас берегите вторую половину."
                ),
                recommendation: .en(
                    "Keep the pace conversational. Sip and snack before you feel empty.",
                    "Держите разговорный темп. Пейте и перекусывайте до ощущения пустоты."
                ),
                avoid: .en(
                    "Don't chase the summit if legs or water are already fading.",
                    "Не гонитесь за вершиной, если ноги или вода уже на исходе."
                ),
                nextAction: .en(
                    "Drink now, take a small bite, then settle back into an easy rhythm.",
                    "Выпейте сейчас, сделайте небольшой перекус — и вернитесь в спокойный ритм."
                )
            )
        }

        return CoachCopyRegistryScenarios.Draft(
            assessment: .en(
                "Hike is underway — stay ahead of fatigue.",
                "Хайкинг идёт — не дайте усталости догнать."
            ),
            recommendation: .en(
                "Steady footing and early fluids beat hero pace.",
                "Устойчивый шаг и вода заранее лучше геройского темпа."
            ),
            avoid: .en(
                "Don't force speed on tired feet.",
                "Не форсируйте скорость на усталых ногах."
            ),
            nextAction: .en(
                "Check water and cadence over the next ten minutes.",
                "В ближайшие десять минут проверьте воду и ритм шага."
            )
        )
    }

    private static func completedDraft(
        hoursEN: String,
        hoursRU: String
    ) -> CoachCopyRegistryScenarios.Draft {
        CoachCopyRegistryScenarios.Draft(
            assessment: .en(
                "Long hike done — the body still needs a soft landing.",
                "Длинный хайкинг позади — телу ещё нужна мягкая посадка."
            ),
            recommendation: .en(
                "Refill fluids, eat a real meal, and keep the rest of the day light on the legs.",
                "Восполните жидкость, съешьте нормальную еду и остаток дня берегите ноги."
            ),
            avoid: .en(
                "Don't stack more hard work or skip food after the effort.",
                "Не наслаивайте новую жёсткую нагрузку и не пропускайте еду после выхода."
            ),
            nextAction: .en(
                "Drink, eat, then put the legs up for a bit.",
                "Выпейте, поешьте — и немного дайте ногам отдых."
            )
        )
    }

    // MARK: - Helpers

    static func resolvedMinutes(_ input: CoachCopyBuildInput) -> Int {
        if let minutes = input.focusActivity?.durationMinutes, minutes > 0 {
            return minutes
        }
        if input.focusDurationMinutes > 0 {
            return input.focusDurationMinutes
        }
        switch input.modifiers.durationBand {
        case .short: return 20
        case .medium: return 45
        case .long: return 75
        case .extended: return 180
        }
    }

    static func hoursLabel(for minutes: Int) -> String {
        if minutes >= 90 {
            let hours = Double(minutes) / 60.0
            let rounded = (hours * 2).rounded() / 2
            if rounded.truncatingRemainder(dividingBy: 1) == 0 {
                let value = Int(rounded)
                return "\(value) \(value == 1 ? "hour" : "hours")"
            }
            return String(format: "%.1f hours", rounded)
        }
        return "\(minutes) minutes"
    }

    static func hoursLabelRu(for minutes: Int) -> String {
        if minutes >= 90 {
            let hours = Double(minutes) / 60.0
            let rounded = (hours * 2).rounded() / 2
            if rounded.truncatingRemainder(dividingBy: 1) == 0 {
                let value = Int(rounded)
                return "\(value) \(russianHoursWord(value))"
            }
            let text = String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
            return "\(text) часа"
        }
        return "\(minutes) минут"
    }

    private static func russianHoursWord(_ value: Int) -> String {
        let mod10 = value % 10
        let mod100 = value % 100
        if mod10 == 1, mod100 != 11 { return "час" }
        if (2...4).contains(mod10), !(12...14).contains(mod100) { return "часа" }
        return "часов"
    }
}
