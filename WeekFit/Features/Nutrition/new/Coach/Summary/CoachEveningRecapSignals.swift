import Foundation

/// One compact evening line — supporting activities, sleep, or a soft body focus.
struct CoachEveningRecapSignal: Equatable, Identifiable, Sendable {
    enum Kind: String, Sendable {
        case activity
        case recovery
        case food
        case water
    }

    let id: String
    let kind: Kind
    let systemImage: String
    let title: String
    let detail: String
}

enum CoachEveningRecapSignalBuilder {

    static func build(
        activity: CoachEveningRecapActivitySummary,
        sleepHours: Double,
        recoveryPercent: Int,
        nutrition: CoachNutritionContext?,
        unitSystem: WeekFitResolvedUnitSystem
    ) -> [CoachEveningRecapSignal] {
        var signals: [CoachEveningRecapSignal] = []

        // Training → recovery sessions → sleep duration → single worst body focus.
        signals.append(contentsOf: trainingActivitySignals(from: activity))
        signals.append(contentsOf: recoveryActivitySignals(from: activity))
        if let sleep = sleepDurationSignal(sleepHours: sleepHours) {
            signals.append(sleep)
        }
        if let focus = worstBodyFocusSignal(
            sleepHours: sleepHours,
            recoveryPercent: recoveryPercent,
            nutrition: nutrition
        ) {
            signals.append(focus)
        }

        // Quiet day with health but nothing else to list.
        if signals.isEmpty,
           activity.healthAccessGranted,
           activity.hasAnyActivitySignal == false {
            // Leave empty — the view shows the empty copy near the hero.
        }

        _ = unitSystem // reserved for future activity distance lines
        return signals
    }

    // MARK: - Supporting activities (never repeats the hero metric)

    private static func trainingActivitySignals(
        from activity: CoachEveningRecapActivitySummary
    ) -> [CoachEveningRecapSignal] {
        let trainingRows = activity.rows.filter { $0.kind != .recovery }
        // Keep the list compact — at most two training lines under the hero.
        return trainingRows.prefix(2).enumerated().map { index, row in
            signal(from: row, index: index, kind: .activity)
        }
    }

    private static func recoveryActivitySignals(
        from activity: CoachEveningRecapActivitySummary
    ) -> [CoachEveningRecapSignal] {
        let recoveryRows = activity.rows.filter { $0.kind == .recovery }
        // Prefer the longest recovery sessions; still cap for a one-screen recap.
        return recoveryRows.prefix(2).enumerated().map { index, row in
            signal(from: row, index: index, kind: .recovery)
        }
    }

    private static func signal(
        from row: CoachEveningRecapActivityRow,
        index: Int,
        kind: CoachEveningRecapSignal.Kind
    ) -> CoachEveningRecapSignal {
        let detail: String
        if let secondary = row.secondaryValue, !secondary.isEmpty {
            detail = "\(row.primaryValue) · \(secondary)"
        } else {
            detail = row.primaryValue
        }
        return CoachEveningRecapSignal(
            id: "\(kind.rawValue).\(row.id).\(index)",
            kind: kind,
            systemImage: normalizedActivityIcon(row.systemImage, title: row.title),
            title: row.title,
            detail: detail
        )
    }

    private static func normalizedActivityIcon(_ icon: String, title: String) -> String {
        let haystack = "\(icon) \(title)".lowercased()
        if haystack.contains("yoga") || haystack.contains("йога") || haystack.contains("瑜伽") {
            return "figure.yoga"
        }
        if haystack.contains("cooldown") || haystack.contains("stretch") || haystack.contains("растяж")
            || haystack.contains("拉伸") {
            return "figure.cooldown"
        }
        if haystack.contains("pilates") || haystack.contains("пилатес") {
            return "figure.pilates"
        }
        if haystack.contains("breath") || haystack.contains("дых") || haystack.contains("呼吸") {
            return "wind"
        }
        if haystack.contains("sauna") || haystack.contains("саун") || haystack.contains("桑拿") {
            return "thermometer.sun.fill"
        }
        if icon.isEmpty {
            return "leaf.fill"
        }
        return icon
    }

    // MARK: - Sleep (factual duration — always when recorded)

    private static func sleepDurationSignal(sleepHours: Double) -> CoachEveningRecapSignal? {
        guard sleepHours >= 0.5 else { return nil }
        let minutes = max(Int((sleepHours * 60.0).rounded()), 1)
        return CoachEveningRecapSignal(
            id: "recovery.sleep",
            kind: .recovery,
            systemImage: "moon.fill",
            title: WeekFitLocalizedString("coach.eveningRecap.signal.sleep.title"),
            detail: CoachEveningRecapFormatting.formatNaturalDuration(minutes)
        )
    }

    // MARK: - Worst soft focus (recovery score / protein / water)

    /// One extra line: the softest recovery or nutrition signal.
    /// Sleep duration stays factual above; this only surfaces when something is actually soft.
    private static func worstBodyFocusSignal(
        sleepHours: Double,
        recoveryPercent: Int,
        nutrition: CoachNutritionContext?
    ) -> CoachEveningRecapSignal? {
        struct Candidate {
            let severity: Double
            let signal: CoachEveningRecapSignal
        }

        var candidates: [Candidate] = []

        // Soft recovery score — skip when sleep is missing and score is the only recovery fact
        // (then show score as the sleep substitute below).
        if recoveryPercent > 0, recoveryPercent < 70 {
            var severity = Double(70 - recoveryPercent)
            if recoveryPercent < 55 { severity += 18 }
            // When sleep already shown, still allow a soft recovery callout.
            // When no sleep, prefer score as the recovery row (handled after candidates).
            let detail: String
            if recoveryPercent < 55 {
                detail = WeekFitLocalizedString("coach.eveningRecap.signal.recovery.scoreSofter")
            } else {
                detail = WeekFitLocalizedString("coach.eveningRecap.signal.recovery.scoreOkay")
            }
            candidates.append(
                Candidate(
                    severity: severity,
                    signal: CoachEveningRecapSignal(
                        id: "recovery.score.focus",
                        kind: .recovery,
                        systemImage: "heart.fill",
                        title: WeekFitLocalizedString("coach.eveningRecap.signal.recovery.title"),
                        detail: detail
                    )
                )
            )
        }

        if let nutrition {
            let hasFoodEvidence = (nutrition.mealsCount ?? 0) > 0
                || nutrition.proteinCurrent > 5
                || nutrition.caloriesCurrent > 100

            // Empty food log ≠ low protein — only judge when something was logged.
            if hasFoodEvidence, nutrition.proteinGoal > 0 {
                let ratio = nutrition.proteinCurrent / nutrition.proteinGoal
                if ratio < 0.90 {
                    let severity = (1.0 - min(max(ratio, 0), 1)) * 85
                    let detail = ratio < 0.70
                        ? WeekFitLocalizedString("coach.eveningRecap.signal.food.proteinLight")
                        : WeekFitLocalizedString("coach.eveningRecap.signal.food.proteinPartial")
                    candidates.append(
                        Candidate(
                            severity: severity,
                            signal: CoachEveningRecapSignal(
                                id: "food.protein.focus",
                                kind: .food,
                                systemImage: "fork.knife",
                                title: WeekFitLocalizedString("coach.eveningRecap.signal.food.title"),
                                detail: detail
                            )
                        )
                    )
                }
            }

            if nutrition.waterGoal > 0 {
                let ratio = nutrition.waterCurrent / nutrition.waterGoal
                if nutrition.waterCurrent > 0.05, ratio < 0.60 {
                    let severity = (1.0 - min(max(ratio, 0), 1)) * 75
                    candidates.append(
                        Candidate(
                            severity: severity,
                            signal: CoachEveningRecapSignal(
                                id: "water.low.focus",
                                kind: .water,
                                systemImage: "drop.fill",
                                title: WeekFitLocalizedString("coach.eveningRecap.signal.water.title"),
                                detail: WeekFitLocalizedString("coach.eveningRecap.signal.food.waterLow")
                            )
                        )
                    )
                } else if nutrition.waterCurrent <= 0.05, hasFoodEvidence {
                    // Food was logged but water wasn't — soft hydration gap only.
                    candidates.append(
                        Candidate(
                            severity: 32,
                            signal: CoachEveningRecapSignal(
                                id: "water.missing.focus",
                                kind: .water,
                                systemImage: "drop.fill",
                                title: WeekFitLocalizedString("coach.eveningRecap.signal.water.title"),
                                detail: WeekFitLocalizedString("coach.eveningRecap.signal.food.waterLow")
                            )
                        )
                    )
                }
            }
        }

        // No sleep recorded — if nothing softer won, fall back to recovery score when present.
        if sleepHours < 0.5, recoveryPercent > 0,
           candidates.contains(where: { $0.signal.id == "recovery.score.focus" }) == false {
            let detail: String
            if recoveryPercent >= 70 {
                detail = WeekFitLocalizedString("coach.eveningRecap.signal.recovery.scoreSolid")
            } else if recoveryPercent < 55 {
                detail = WeekFitLocalizedString("coach.eveningRecap.signal.recovery.scoreSofter")
            } else {
                detail = WeekFitLocalizedString("coach.eveningRecap.signal.recovery.scoreOkay")
            }
            return CoachEveningRecapSignal(
                id: "recovery.score",
                kind: .recovery,
                systemImage: "heart.fill",
                title: WeekFitLocalizedString("coach.eveningRecap.signal.recovery.title"),
                detail: detail
            )
        }

        // Need a real soft signal — ignore mild noise.
        guard let best = candidates.max(by: { $0.severity < $1.severity }),
              best.severity >= 15 else {
            return nil
        }
        return best.signal
    }
}
