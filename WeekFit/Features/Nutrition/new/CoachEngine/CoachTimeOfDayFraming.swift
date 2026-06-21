import Foundation

/// Shared hero and My Read framing by clock phase of day.
enum CoachTimeOfDayFraming {

    struct Copy {
        let english: String
        let russian: String

        init(_ english: String, _ russian: String) {
            self.english = english
            self.russian = russian
        }
    }

    static func postStaleHero(
        timePhase: CoachFinalDecisionTimeOfDay,
        modalityEN: String,
        modalityRU: String,
        longSession: Bool
    ) -> Copy {
        let longEN = longSession ? "long " : ""
        let longRU = longSession ? "длинной " : ""
        switch timePhase {
        case .morning:
            return Copy(
                "After this morning's \(longEN)\(modalityEN)",
                "После \(longRU)\(modalityRU) этим утром"
            )
        case .midday:
            return Copy(
                "Midday after the \(longEN)\(modalityEN)",
                "После \(longRU)\(modalityRU) — середина дня"
            )
        case .afternoon:
            return Copy(
                "Afternoon after the \(longEN)\(modalityEN)",
                "После \(longRU)\(modalityRU) — второй половины дня"
            )
        case .evening:
            return Copy(
                "Evening after the \(longEN)\(modalityEN)",
                "Вечер после \(longRU)\(modalityRU)"
            )
        case .lateEvening, .night:
            return Copy(
                "Late day after the \(longEN)\(modalityEN)",
                "Поздний вечер после \(longRU)\(modalityRU)"
            )
        }
    }

    static func postSettledHero(
        timePhase: CoachFinalDecisionTimeOfDay,
        modalityEN: String,
        modalityRU: String
    ) -> Copy {
        switch timePhase {
        case .morning, .midday:
            return Copy(
                "After the \(modalityEN)",
                "После \(modalityRU)"
            )
        case .afternoon:
            return Copy(
                "The \(modalityEN) is behind you",
                "После \(modalityRU) — день продолжается"
            )
        case .evening, .lateEvening, .night:
            return Copy(
                "After today's \(modalityEN)",
                "После сегодняшней \(modalityRU)"
            )
        }
    }

    static func strengthPostStaleHero(timePhase: CoachFinalDecisionTimeOfDay) -> Copy {
        switch timePhase {
        case .morning, .midday:
            return Copy("After strength work this morning", "После силовой этим утром")
        case .afternoon:
            return Copy("Afternoon after strength work", "После силовой — второй половины дня")
        case .evening:
            return Copy("Evening after strength work", "Вечер после силовой")
        case .lateEvening, .night:
            return Copy("Late day after strength work", "Поздний вечер после силовой")
        }
    }

    static func myReadTimeClause(
        timePhase: CoachFinalDecisionTimeOfDay,
        owner: CoachFinalStoryOwner,
        completedSeriousTrainingToday: Bool,
        hasUpcomingSessionToday: Bool,
        isPostSession: Bool
    ) -> Copy? {
        switch timePhase {
        case .morning:
            if owner == .stableOverview || owner == .readiness {
                return Copy(
                    "Morning's going fine so far.",
                    "Утро пока идёт ровно."
                )
            }
            if owner == .activityPreparation || (hasUpcomingSessionToday && !completedSeriousTrainingToday) {
                return Copy(
                    "Morning is still open — ease into the main session.",
                    "Утро ещё впереди — спокойно настройтесь на главную сессию."
                )
            }
            if owner == .stableOverview || owner == .readiness {
                return Copy(
                    "Morning's going fine so far.",
                    "Утро пока идёт ровно."
                )
            }
            return nil

        case .midday:
            if isPostSession && completedSeriousTrainingToday {
                return Copy(
                    "Take it easy for the rest of the day.",
                    "Остаток дня лучше держать лёгким."
                )
            }
            if owner == .activityPreparation {
                return Copy(
                    "You still have time before the session — don't add extra load at lunch.",
                    "До сессии ещё есть время — не добавляйте лишней нагрузки в середине дня."
                )
            }
            return nil

        case .afternoon:
            if isPostSession && completedSeriousTrainingToday {
                return Copy(
                    "The workout window is closing — go easy this afternoon.",
                    "Тренировочное окно закрывается — берегите остаток дня."
                )
            }
            if owner == .activityPreparation {
                return Copy(
                    "The main session is still ahead today.",
                    "Главная сессия на сегодня ещё впереди."
                )
            }
            return nil

        case .evening:
            if owner == .postActivityRecovery || owner == .recovery || (isPostSession && completedSeriousTrainingToday) {
                return Copy(
                    "Keep the evening calm.",
                    "Вечер сейчас лучше держать спокойным."
                )
            }
            if owner == .tomorrowProtection {
                return Copy(
                    "What you do tonight shapes tomorrow.",
                    "Вечерние решения сформируют завтра."
                )
            }
            if owner == .activityPreparation {
                return Copy(
                    "A late session needs a quiet lead-in.",
                    "Поздняя сессия требует спокойного входа."
                )
            }
            return nil

        case .lateEvening, .night:
            if owner == .postActivityRecovery || owner == .recovery || owner == .tomorrowProtection || completedSeriousTrainingToday {
                return Copy(
                    "It's late — sleep is what helps most now.",
                    "Уже поздно — сон сейчас важнее всего."
                )
            }
            if owner == .stableOverview || owner == .readiness {
                return Copy(
                    "The day is winding down.",
                    "День подходит к концу."
                )
            }
            if owner == .activeActivity {
                return Copy(
                    "It is late to add meaningful training load.",
                    "Поздно добавлять заметную нагрузку."
                )
            }
            return nil
        }
    }

    static func stableDayRead(timePhase: CoachFinalDecisionTimeOfDay) -> Copy {
        switch timePhase {
        case .morning:
            return Copy(
                "Morning's going fine — nothing needs your attention right now.",
                "Утро идёт ровно — срочного ничего не требует внимания."
            )
        case .midday, .afternoon:
            return Copy(
                "Today's going fine — nothing needs your attention right now.",
                "День идёт ровно — срочного ничего не требует внимания."
            )
        case .evening, .lateEvening, .night:
            return Copy(
                "Good day so far — keep the evening quiet.",
                "День в хорошем ритме — вечер лучше держать спокойным."
            )
        }
    }
}
