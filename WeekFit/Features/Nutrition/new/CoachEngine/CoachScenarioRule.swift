import Foundation

struct CoachScenarioRule {
    let stateLabel: String
    let title: String
    let message: String

    let supportFocus: [String]
    let supportActions: [CoachSupportActionTypeV3]
    let avoidNotes: [String]
}

struct CoachRecoveryContext {
    let recoveryPercent: Int
    let sleepHours: Double
}

enum CoachScenarioRuleEngine {

    static func resolve(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        nutritionContext: CoachNutritionContext? = nil,
        readiness: CoachReadinessStateV3,
        brain: HumanBrain.State
    ) -> CoachScenarioRule {

        switch scenario.stage {

        case .before:
            return beforeRule(
                scenario: scenario,
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                readiness: readiness,
                brain: brain
            )

        case .during:
            return duringRule(
                scenario: scenario,
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                readiness: readiness,
                brain: brain
            )

        case .after:
            return afterRule(
                scenario: scenario,
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                nutritionContext: nutritionContext,
                readiness: readiness,
                brain: brain
            )

        case .stable:
            return stableRule(
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                brain: brain
            )
        }
    }
}

// MARK: - Stage Routing

private extension CoachScenarioRuleEngine {

    static func beforeRule(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        readiness: CoachReadinessStateV3,
        brain: HumanBrain.State
    ) -> CoachScenarioRule {

        switch scenario.archetype {

        case .performance:
            return performanceBeforeRule(
                scenario: scenario,
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                readiness: readiness,
                brain: brain
            )

        case .endurance:
            return enduranceBeforeRule(
                scenario: scenario,
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                readiness: readiness,
                brain: brain
            )

        case .recovery:
            return recoveryBeforeRule(
                scenario: scenario,
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                readiness: readiness,
                brain: brain
            )

        case .heat:
            return heatBeforeRule(
                scenario: scenario,
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                brain: brain
            )

        case .meal, .stable:
            return stableRule(
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                brain: brain
            )
        }
    }

    static func duringRule(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        readiness: CoachReadinessStateV3,
        brain: HumanBrain.State
    ) -> CoachScenarioRule {

        switch scenario.archetype {

        case .performance:
            return performanceDuringRule(
                scenario: scenario,
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                readiness: readiness
            )

        case .endurance:
            return enduranceDuringRule(
                scenario: scenario,
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                readiness: readiness
            )

        case .recovery:
            return recoveryDuringRule(
                scenario: scenario,
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                readiness: readiness
            )

        case .heat:
            return heatDuringRule(
                scenario: scenario,
                dayContext: dayContext,
                recoveryContext: recoveryContext
            )

        case .meal, .stable:
            return stableRule(
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                brain: brain
            )
        }
    }

    static func afterRule(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        nutritionContext: CoachNutritionContext? = nil,
        readiness: CoachReadinessStateV3,
        brain: HumanBrain.State
    ) -> CoachScenarioRule {

        switch scenario.archetype {

        case .performance:
            return performanceAfterRule(
                scenario: scenario,
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                nutritionContext: nutritionContext,
                readiness: readiness,
                brain: brain
            )

        case .endurance:
            return enduranceAfterRule(
                scenario: scenario,
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                nutritionContext: nutritionContext,
                readiness: readiness,
                brain: brain
            )

        case .recovery:
            return recoveryAfterRule(
                scenario: scenario,
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                readiness: readiness,
                brain: brain
            )

        case .heat:
            return heatAfterRule(
                scenario: scenario,
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                nutritionContext: nutritionContext,
                brain: brain
            )

        case .meal, .stable:
            return stableRule(
                dayContext: dayContext,
                recoveryContext: recoveryContext,
                brain: brain
            )
        }
    }
}

// MARK: - Performance

private extension CoachScenarioRuleEngine {

    static func performanceBeforeRule(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        readiness: CoachReadinessStateV3,
        brain: HumanBrain.State
    ) -> CoachScenarioRule {

        let name = activityName(scenario)
        let hard = isHard(scenario)
        let late = isLate(scenario)
        let closeToStart = (scenario.minutesUntilStart ?? 999) <= 30
        let loadedDay = isLoadedDay(dayContext, readiness: readiness)

        if loadedDay {
            return CoachScenarioRule(
                stateLabel: "PREPARE",
                title: "Keep \(name.lowercased()) easy",
                message: loadedDayMessage(
                    dayContext: dayContext,
                    recoveryContext: recoveryContext,
                    action: "For \(name.lowercased()), make this quality work rather than extra volume."
                ),
                supportFocus: performanceFocus(
                    scenario: scenario,
                    loadedDay: true,
                    late: late
                ),
                supportActions: [
                    .controlIntensity,
                    .mobilityPrep,
                    late ? .sleepPriority : .lightRecoveryMovement
                ],
                avoidNotes: [
                    extraIntensityNote(dayContext)
                ]
            )
        }

        if closeToStart {
            return CoachScenarioRule(
                stateLabel: "PREPARE",
                title: "Get ready for \(name.lowercased())",
                message: "The session starts soon. Start below target effort and build only after the first block feels easy.",
                supportFocus: performanceFocus(
                    scenario: scenario,
                    loadedDay: false,
                    late: late
                ),
                supportActions: [
                    .mobilityPrep,
                    .controlIntensity,
                    .breathingReset
                ],
                avoidNotes: [
                    "Do not rush into working intensity from the first minute."
                ]
            )
        }

        return CoachScenarioRule(
            stateLabel: "PREPARE",
            title: hard ? "Prepare for a hard session" : "Prepare smoothly",
            message: hard
                ? "This session can create real training stress. Build into it gradually and keep quality higher than intensity."
                : "A short warm-up and easy start should be enough for this session.",
            supportFocus: performanceFocus(
                scenario: scenario,
                loadedDay: false,
                late: late
            ),
            supportActions: hard
                ? [
                    .mobilityPrep,
                    .controlIntensity,
                    late ? .sleepPriority : .breathingReset
                ]
                : [
                    .mobilityPrep,
                    .controlIntensity
                ],
            avoidNotes: late
                ? ["Avoid turning a late session into a max-effort workout."]
                : []
        )
    }

    static func performanceDuringRule(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        readiness: CoachReadinessStateV3
    ) -> CoachScenarioRule {

        let hard = isHard(scenario)
        let loadedDay = isLoadedDay(dayContext, readiness: readiness)

        if isRacketSport(scenario) {
            if loadedDay {
                return CoachScenarioRule(
                    stateLabel: "IN SESSION",
                    title: "Keep rallies steady",
                    message: "\(trainingProgressLine(dayContext)) Play with control and avoid turning every rally into a maximal effort.",
                    supportFocus: [
                        "Stay below max effort",
                        "Use smooth footwork",
                        "Take short recovery pauses"
                    ],
                    supportActions: [
                        .controlIntensity,
                        .breathingReset
                    ],
                    avoidNotes: [
                        "Do not chase every point at full intensity today."
                    ]
                )
            }

            return CoachScenarioRule(
                stateLabel: "IN SESSION",
                title: hard ? "Control court intensity" : "Keep rallies smooth",
                message: hard
                    ? "Keep the effort repeatable and save the highest intensity for key points, not every rally."
                    : "Move smoothly, keep breathing steady and avoid rushing the pace early.",
                supportFocus: hard
                    ? [
                        "Stay below max effort",
                        "Recover between rallies",
                        "Keep reserve for final games"
                    ]
                    : [
                        "Move smoothly",
                        "Relax between points",
                        "Finish with control"
                    ],
                supportActions: [
                    .controlIntensity,
                    .breathingReset
                ],
                avoidNotes: []
            )
        }

        if loadedDay {
            return CoachScenarioRule(
                stateLabel: "IN SESSION",
                title: "Keep output steady",
                message: "\(trainingProgressLine(dayContext)) Make this a clean execution session, not a test of your limit.",
                supportFocus: [
                    "Leave 1–2 reps in reserve",
                    "Keep form clean",
                    "Stop before form drops"
                ],
                supportActions: [
                    .controlIntensity,
                    .breathingReset
                ],
                avoidNotes: [
                    "Do not chase personal records when daily load is already high."
                ]
            )
        }

        return CoachScenarioRule(
            stateLabel: "IN SESSION",
            title: hard ? "Control the hard work" : "Keep the session steady",
            message: hard
                ? "Stay repeatable before fatigue builds. Quality reps matter more than forcing intensity."
                : "Stay steady and keep the session under control.",
            supportFocus: hard
                ? [
                    "Work at 7–8/10 effort",
                    "Keep form stable",
                    "Rest before fatigue spikes"
                ]
                : [
                    "Keep rhythm",
                    "Use clean technique",
                    "Finish clean"
                ],
            supportActions: hard
                ? [
                    .controlIntensity,
                    .breathingReset
                ]
                : [
                    .controlIntensity
                ],
            avoidNotes: []
        )
    }

    static func performanceAfterRule(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        nutritionContext: CoachNutritionContext?,
        readiness: CoachReadinessStateV3,
        brain: HumanBrain.State
    ) -> CoachScenarioRule {

        let hard = isHard(scenario)
        let late = isLate(scenario)
        let loadedDay = isLoadedDay(dayContext, readiness: readiness)

        if isRacketSport(scenario) && (hard || loadedDay) {
            return CoachScenarioRule(
                stateLabel: "RECOVERY",
                title: "Recover from court load",
                message: "\(completionLine(scenario)) \(trainingProgressLine(dayContext)) Keep the rest of the day easy so the session does not stack unnecessary fatigue.",
                supportFocus: recoveryNutritionFocus(
                    scenario: scenario,
                    nutritionContext: nutritionContext,
                    base: [
                        "Cool down 5–10 min",
                        "Keep movement light",
                        late ? "Protect sleep" : "Avoid extra intensity"
                    ],
                    late: late
                ),
                supportActions: recoveryNutritionActions(
                    scenario: scenario,
                    nutritionContext: nutritionContext,
                    fallback: [
                        .cooldown,
                        .lightRecoveryMovement,
                        late ? .sleepPriority : .downshiftNervousSystem
                    ],
                    late: late
                ),
                avoidNotes: [
                    "Avoid another high-intensity block today."
                ]
            )
        }

        if hard || loadedDay {
            return CoachScenarioRule(
                stateLabel: "RECOVERY",
                title: "Protect recovery now",
                message: "\(completionLine(scenario)) \(trainingProgressLine(dayContext)) Shift the rest of the day away from intensity so your body can absorb the load.",
                supportFocus: recoveryNutritionFocus(
                    scenario: scenario,
                    nutritionContext: nutritionContext,
                    base: [
                        "Cool down 5–10 min",
                        "Keep movement easy",
                        late ? "Protect sleep" : "Avoid extra intensity"
                    ],
                    late: late
                ),
                supportActions: recoveryNutritionActions(
                    scenario: scenario,
                    nutritionContext: nutritionContext,
                    fallback: [
                        .cooldown,
                        .lightRecoveryMovement,
                        late ? .sleepPriority : .downshiftNervousSystem
                    ],
                    late: late
                ),
                avoidNotes: [
                    "Avoid adding more hard work today."
                ]
            )
        }

        return CoachScenarioRule(
            stateLabel: "RECOVERY",
            title: "Return to baseline",
            message: "\(completionLine(scenario)) Cool down, keep the next block easy and let recovery start.",
            supportFocus: recoveryNutritionFocus(
                scenario: scenario,
                nutritionContext: nutritionContext,
                base: [
                    "Cool down 5–10 min",
                    "Walk easily",
                    "Keep the day steady"
                ],
                late: late
            ),
            supportActions: recoveryNutritionActions(
                scenario: scenario,
                nutritionContext: nutritionContext,
                fallback: [
                    .cooldown,
                    .lightRecoveryMovement,
                    .downshiftNervousSystem
                ],
                late: late
            ),
            avoidNotes: []
        )
    }
}

// MARK: - Endurance

private extension CoachScenarioRuleEngine {

    static func enduranceBeforeRule(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        readiness: CoachReadinessStateV3,
        brain: HumanBrain.State
    ) -> CoachScenarioRule {

        let name = activityName(scenario)
        let long = isLong(scenario)
        let hard = isHard(scenario)
        let loadedDay = isLoadedDay(dayContext, readiness: readiness)
        let closeToStart = (scenario.minutesUntilStart ?? 999) <= 30

        if loadedDay {
            return CoachScenarioRule(
                stateLabel: "PREPARE",
                title: "Keep endurance easy",
                message: loadedDayMessage(
                    dayContext: dayContext,
                    recoveryContext: recoveryContext,
                    action: "Use this \(name.lowercased()) session to build aerobic volume, not extra intensity."
                ),
                supportFocus: enduranceFocus(
                    scenario: scenario,
                    loadedDay: true
                ),
                supportActions: [
                    .controlIntensity,
                    .breathingReset,
                    .lightRecoveryMovement
                ],
                avoidNotes: [
                    extraIntensityNote(dayContext)
                ]
            )
        }

        if closeToStart {
            return CoachScenarioRule(
                stateLabel: "PREPARE",
                title: "Start endurance easy",
                message: "\(name) starts soon. Keep the first 10 minutes easy before deciding whether to build effort.",
                supportFocus: enduranceFocus(
                    scenario: scenario,
                    loadedDay: false
                ),
                supportActions: [
                    .controlIntensity,
                    .breathingReset
                ],
                avoidNotes: [
                    "Do not chase pace from the start."
                ]
            )
        }

        return CoachScenarioRule(
            stateLabel: "PREPARE",
            title: long || hard ? "Prepare for endurance" : "Prepare smoothly",
            message: long || hard
                ? "This session will feel better if you build gradually and keep the effort sustainable."
                : "An easy start is enough. Let the session settle before increasing pace.",
            supportFocus: enduranceFocus(
                scenario: scenario,
                loadedDay: false
            ),
            supportActions: [
                .controlIntensity,
                .breathingReset
            ],
            avoidNotes: []
        )
    }

    static func enduranceDuringRule(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        readiness: CoachReadinessStateV3
    ) -> CoachScenarioRule {

        let long = isLong(scenario)
        let hard = isHard(scenario)
        let loadedDay = isLoadedDay(dayContext, readiness: readiness)

        if loadedDay {
            return CoachScenarioRule(
                stateLabel: "IN SESSION",
                title: "Stay aerobic",
                message: "\(trainingProgressLine(dayContext)) Keep this steady and avoid turning volume into intensity.",
                supportFocus: [
                    "Hold conversational pace",
                    "Relax shoulders",
                    "Finish with control"
                ],
                supportActions: [
                    .controlIntensity,
                    .breathingReset
                ],
                avoidNotes: [
                    "Do not turn this into another hard session."
                ]
            )
        }

        return CoachScenarioRule(
            stateLabel: "IN SESSION",
            title: long || hard ? "Stay ahead of fatigue" : "Keep it comfortable",
            message: long || hard
                ? "Keep effort steady before fatigue appears. The goal is sustainable output."
                : "Keep the pace comfortable and let the session feel smooth.",
            supportFocus: long || hard
                ? [
                    "Hold steady effort",
                    "Keep breathing steady",
                    "Check effort every 10 min"
                ]
                : [
                    "Conversational pace",
                    "Stay relaxed",
                    "Finish fresh"
                ],
            supportActions: [
                .controlIntensity,
                .breathingReset
            ],
            avoidNotes: []
        )
    }

    static func enduranceAfterRule(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        nutritionContext: CoachNutritionContext?,
        readiness: CoachReadinessStateV3,
        brain: HumanBrain.State
    ) -> CoachScenarioRule {

        let hard = isHard(scenario)
        let long = isLong(scenario)
        let loadedDay = isLoadedDay(dayContext, readiness: readiness)
        let late = isLate(scenario)

        if hard || long || loadedDay {
            return CoachScenarioRule(
                stateLabel: "RECOVERY",
                title: "Absorb the endurance load",
                message: "\(completionLine(scenario)) \(trainingProgressLine(dayContext)) Keep the next part of the day easy so the session supports fitness instead of adding fatigue.",
                supportFocus: recoveryNutritionFocus(
                    scenario: scenario,
                    nutritionContext: nutritionContext,
                    base: [
                        "Cool down 5–10 min",
                        "Walk or spin easy",
                        late ? "Protect sleep" : "Avoid extra intensity"
                    ],
                    late: late
                ),
                supportActions: recoveryNutritionActions(
                    scenario: scenario,
                    nutritionContext: nutritionContext,
                    fallback: [
                        .cooldown,
                        .lightRecoveryMovement,
                        late ? .sleepPriority : .downshiftNervousSystem
                    ],
                    late: late
                ),
                avoidNotes: [
                    "Avoid stacking another hard session today."
                ]
            )
        }

        return CoachScenarioRule(
            stateLabel: "RECOVERY",
            title: "Recover simply",
            message: "\(completionLine(scenario)) Return to baseline and keep the rest of the day steady.",
            supportFocus: recoveryNutritionFocus(
                scenario: scenario,
                nutritionContext: nutritionContext,
                base: [
                    "Cool down easy",
                    "Stay loose",
                    "Keep rhythm"
                ],
                late: late
            ),
            supportActions: recoveryNutritionActions(
                scenario: scenario,
                nutritionContext: nutritionContext,
                fallback: [
                    .cooldown,
                    .lightRecoveryMovement,
                    .stayConsistent
                ],
                late: late
            ),
            avoidNotes: []
        )
    }
}

// MARK: - Recovery / Walk / Stretching / Mobility / Breathing

private extension CoachScenarioRuleEngine {

    static func recoveryBeforeRule(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        readiness: CoachReadinessStateV3,
        brain: HumanBrain.State
    ) -> CoachScenarioRule {

        let name = activityName(scenario)
        let text = normalizedActivityText(scenario)
        let late = isLate(scenario)
        let loadedDay = isLoadedDay(dayContext, readiness: readiness)

        if text.isStretchingLike {
            return CoachScenarioRule(
                stateLabel: "RECOVERY",
                title: loadedDay ? "Use stretching to unload today" : "Ease into stretching",
                message: loadedDay
                    ? "\(activityVolumeLine(dayContext)) Keep this block easy: comfortable range only, no painful positions, and stop before discomfort."
                    : "Keep this calm and comfortable. The goal is to feel looser after the session.",
                supportFocus: stretchingFocus(
                    dayContext: dayContext,
                    loadedDay: loadedDay,
                    late: late
                ),
                supportActions: [
                    .mobilityPrep,
                    .breathingReset,
                    late ? .downshiftNervousSystem : .stayConsistent
                ],
                avoidNotes: [
                    "No need to increase range today."
                ]
            )
        }

        if text.isBreathingLike {
            return CoachScenarioRule(
                stateLabel: "RECOVERY",
                title: "Downshift now",
                message: loadedDay
                    ? "\(activityVolumeLine(dayContext)) Use this breathing block to lower arousal before the next part of the evening."
                    : "Use this block to slow down and reset. Keep the breathing easy and comfortable.",
                supportFocus: breathingFocus(late: late),
                supportActions: [
                    .breathingReset,
                    .downshiftNervousSystem
                ],
                avoidNotes: [
                    "Do not force deep breathing if it feels uncomfortable."
                ]
            )
        }

        if text.isWalkLike {
            return CoachScenarioRule(
                stateLabel: "RECOVERY",
                title: "Keep the walk easy",
                message: loadedDay
                    ? "\(activityVolumeLine(dayContext)) This walk should help recovery, not become extra training."
                    : "Keep it comfortable. This walk is here to support recovery, not add stress.",
                supportFocus: walkFocus(late: late),
                supportActions: [
                    .controlIntensity,
                    .breathingReset,
                    late ? .downshiftNervousSystem : .stayConsistent
                ],
                avoidNotes: [
                    "Do not turn this into another workout."
                ]
            )
        }

        return CoachScenarioRule(
            stateLabel: "RECOVERY",
            title: "Keep recovery easy",
            message: loadedDay
                ? "\(activityVolumeLine(dayContext)) This block should help you recover, not create more load."
                : "This block should support recovery, not create more load.",
            supportFocus: [
                "Keep effort at 2–3/10",
                "Breathe normally",
                "Finish relaxed"
            ],
            supportActions: [
                .controlIntensity,
                .breathingReset,
                .downshiftNervousSystem
            ],
            avoidNotes: [
                "Avoid adding intensity to recovery work."
            ]
        )
    }

    static func recoveryDuringRule(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        readiness: CoachReadinessStateV3
    ) -> CoachScenarioRule {

        let text = normalizedActivityText(scenario)
        let loadedDay = isLoadedDay(dayContext, readiness: readiness)

        if text.isStretchingLike {
            return CoachScenarioRule(
                stateLabel: "IN SESSION",
                title: "Keep mobility gentle",
                message: loadedDay
                    ? "\(activityVolumeLine(dayContext)) Use this as recovery support and stay within a comfortable range."
                    : "Stay within a comfortable range. Do not force depth or intensity.",
                supportFocus: [
                    "Hold 20–30s",
                    "Stay below discomfort",
                    "Relax on each exhale"
                ],
                supportActions: [
                    .controlIntensity,
                    .breathingReset
                ],
                avoidNotes: [
                    "Avoid pushing into discomfort."
                ]
            )
        }

        if text.isBreathingLike {
            return CoachScenarioRule(
                stateLabel: "IN SESSION",
                title: "Stay calm",
                message: "Keep the breath slow and natural. The goal is to downshift, not to perform.",
                supportFocus: [
                    "Aim for 4–6 breaths/min",
                    "Relax jaw and shoulders",
                    "Extend the exhale"
                ],
                supportActions: [
                    .breathingReset,
                    .downshiftNervousSystem
                ],
                avoidNotes: [
                    "Stop forcing the pattern if breathing feels strained."
                ]
            )
        }

        return CoachScenarioRule(
            stateLabel: "IN SESSION",
            title: "Keep it comfortable",
            message: loadedDay
                ? "\(activityVolumeLine(dayContext)) Let this movement help recovery rather than turning it into training."
                : "Let this movement help recovery rather than turning it into training.",
            supportFocus: [
                "Keep effort at 2–3/10",
                "Breathe relaxed",
                "Finish calmer"
            ],
            supportActions: [
                .controlIntensity,
                .breathingReset
            ],
            avoidNotes: [
                "Do not turn this into another workout."
            ]
        )
    }

    static func recoveryAfterRule(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        readiness: CoachReadinessStateV3,
        brain: HumanBrain.State
    ) -> CoachScenarioRule {

        let late = isLate(scenario)
        let loadedDay = isLoadedDay(dayContext, readiness: readiness)
        let text = normalizedActivityText(scenario)

        if text.isBreathingLike {
            return CoachScenarioRule(
                stateLabel: "RECOVERY",
                title: "Breathing block complete",
                message: late
                    ? "Good. Keep the evening quiet and let this downshift carry toward sleep."
                    : "Good reset. Keep the next block calm and avoid rushing back into intensity.",
                supportFocus: [
                    "Keep screens low",
                    "Avoid rushing",
                    late ? "Protect sleep" : "Keep rhythm"
                ],
                supportActions: [
                    .downshiftNervousSystem,
                    late ? .sleepPriority : .stayConsistent
                ],
                avoidNotes: []
            )
        }

        if text.isStretchingLike {
            return CoachScenarioRule(
                stateLabel: "RECOVERY",
                title: "Mobility block complete",
                message: loadedDay
                    ? "\(activityVolumeLine(dayContext)) Good. Keep the rest of the evening easy so this work supports recovery."
                    : "Good. Keep recovery simple and continue with the day at a comfortable pace.",
                supportFocus: [
                    "Stay loose",
                    "Avoid extra sets",
                    late ? "Wind down" : "Return calmly"
                ],
                supportActions: [
                    .lightRecoveryMovement,
                    late ? .downshiftNervousSystem : .stayConsistent
                ],
                avoidNotes: loadedDay
                    ? ["Avoid adding intensity after recovery work."]
                    : []
            )
        }

        return CoachScenarioRule(
            stateLabel: "RECOVERY",
            title: "Recovery block complete",
            message: loadedDay
                ? "\(activityVolumeLine(dayContext)) This was the right kind of work after a loaded day. Keep the next part easy and let recovery continue."
                : "Good. Keep recovery simple and continue with the day at a comfortable pace.",
            supportFocus: [
                "Stay loose",
                "Keep effort low",
                late ? "Wind down" : "Return calmly"
            ],
            supportActions: [
                .lightRecoveryMovement,
                late ? .downshiftNervousSystem : .stayConsistent
            ],
            avoidNotes: loadedDay
                ? ["Avoid adding intensity after recovery work."]
                : []
        )
    }
}

// MARK: - Heat

private extension CoachScenarioRuleEngine {

    static func heatBeforeRule(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        brain: HumanBrain.State
    ) -> CoachScenarioRule {

        let late = isLate(scenario)

        return CoachScenarioRule(
            stateLabel: "PREPARE",
            title: "Keep heat conservative",
            message: late
                ? "Use heat as recovery support tonight. Keep the session comfortable so it does not disturb sleep."
                : "Keep the heat session moderate. The goal is relaxation and recovery, not endurance.",
            supportFocus: [
                "Limit to 15–30 min",
                "Exit if dizzy",
                late ? "Cool down before bed" : "Avoid rushing after"
            ],
            supportActions: [
                .breathingReset,
                .controlIntensity,
                late ? .downshiftNervousSystem : .stayConsistent
            ],
            avoidNotes: [
                "Avoid pushing duration if you feel lightheaded."
            ]
        )
    }

    static func heatDuringRule(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext
    ) -> CoachScenarioRule {

        CoachScenarioRule(
            stateLabel: "IN SESSION",
            title: "Stay moderate",
            message: "Heat should feel comfortable. End the session early if it starts to feel draining.",
            supportFocus: [
                "Keep it moderate",
                "Notice dizziness",
                "Exit calmly"
            ],
            supportActions: [
                .controlIntensity,
                .breathingReset
            ],
            avoidNotes: [
                "Do not push through lightheadedness."
            ]
        )
    }

    static func heatAfterRule(
        scenario: CoachActivityScenario,
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        nutritionContext: CoachNutritionContext?,
        brain: HumanBrain.State
    ) -> CoachScenarioRule {

        let late = isLate(scenario)

        return CoachScenarioRule(
            stateLabel: "RECOVERY",
            title: "Cool down gradually",
            message: late
                ? "Let the body settle after heat and keep the evening calm."
                : "After heat, avoid rushing into hard effort. Let your body return to baseline.",
            supportFocus: recoveryNutritionFocus(
                scenario: scenario,
                nutritionContext: nutritionContext,
                base: [
                    "Cool down 10–15 min",
                    "Keep movement easy",
                    late ? "Wind down" : "Avoid hard effort"
                ],
                late: late
            ),
            supportActions: recoveryNutritionActions(
                scenario: scenario,
                nutritionContext: nutritionContext,
                fallback: [
                    .downshiftNervousSystem,
                    .lightRecoveryMovement,
                    late ? .sleepPriority : .stayConsistent
                ],
                late: late
            ),
            avoidNotes: [
                "Avoid hard training right after heat."
            ]
        )
    }
}

// MARK: - Stable

private extension CoachScenarioRuleEngine {

    static func stableRule(
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        brain: HumanBrain.State
    ) -> CoachScenarioRule {

        if dayContext.hasMeaningfulLoadCompleted {
            return CoachScenarioRule(
                stateLabel: "OVERVIEW",
                title: "Training load is already logged",
                message: "\(trainingProgressLine(dayContext)) No training moment needs attention right now.",
                supportFocus: [],
                supportActions: [],
                avoidNotes: []
            )
        }

        return CoachScenarioRule(
            stateLabel: "OVERVIEW",
            title: "No active focus right now",
            message: "No training or recovery moment needs attention right now.",
            supportFocus: [],
            supportActions: [],
            avoidNotes: []
        )
    }
}

// MARK: - Scenario-Specific Focus

private extension CoachScenarioRuleEngine {

    static func performanceFocus(
        scenario: CoachActivityScenario,
        loadedDay: Bool,
        late: Bool
    ) -> [String] {

        if isRacketSport(scenario) {
            if loadedDay {
                return [
                    "Start easy for 10 min",
                    "Avoid all-out rallies",
                    late ? "Stop before fatigue spikes" : "Keep reserve for final games"
                ]
            }

            if isHard(scenario) {
                return [
                    "Build intensity gradually",
                    "Recover between rallies",
                    "Keep reserve for final games"
                ]
            }

            return [
                "Build intensity gradually",
                "Stay light on footwork",
                "Finish with control"
            ]
        }

        if loadedDay {
            return [
                "Work at 70–80%",
                "Leave 1–2 reps in reserve",
                late ? "Stop before fatigue spikes" : "No extra sets"
            ]
        }

        if isHard(scenario) {
            return [
                "Build over 10 min",
                "Prioritize technique",
                "Rest before form drops"
            ]
        }

        return [
            "Warm up 5–10 min",
            "Start easy",
            "Keep form clean"
        ]
    }

    static func enduranceFocus(
        scenario: CoachActivityScenario,
        loadedDay: Bool
    ) -> [String] {

        if loadedDay {
            return [
                "Stay conversational",
                "Keep HR below threshold",
                "Finish with energy left"
            ]
        }

        if isLong(scenario) || isHard(scenario) {
            return [
                "Start easy for 10 min",
                "Hold sustainable effort",
                "Check effort every 10 min"
            ]
        }

        return [
            "Conversational pace",
            "Find rhythm",
            "Finish fresh"
        ]
    }

    static func stretchingFocus(
        dayContext: CoachDayContext,
        loadedDay: Bool,
        late: Bool
    ) -> [String] {

        if loadedDay {
            return [
                "Hold 20–30s",
                "Stay below discomfort",
                late ? "Finish calmer" : "Release tension"
            ]
        }

        return [
            "Move slowly",
            "Comfortable range only",
            "Relax on each exhale"
        ]
    }

    static func breathingFocus(late: Bool) -> [String] {
        [
            "Aim for 4–6 breaths/min",
            "Relax shoulders",
            late ? "Extend the exhale" : "Keep it natural"
        ]
    }

    static func walkFocus(late: Bool) -> [String] {
        [
            "Keep pace easy",
            "Relax breathing",
            late ? "Finish calmer" : "Stay loose"
        ]
    }
}

// MARK: - Helpers

private extension CoachScenarioRuleEngine {

    static func isRacketSport(_ scenario: CoachActivityScenario) -> Bool {
        let text = normalizedActivityText(scenario)

        return text.contains("tennis") ||
               text.contains("squash")
    }

    static func isHard(_ scenario: CoachActivityScenario) -> Bool {
        scenario.load == .high || scenario.load == .extreme
    }

    static func isLong(_ scenario: CoachActivityScenario) -> Bool {
        scenario.durationBucket == .sixtyTo90 || scenario.durationBucket == .over90
    }

    static func isLate(_ scenario: CoachActivityScenario) -> Bool {
        scenario.dayTime == .evening ||
        scenario.dayTime == .lateEvening ||
        scenario.dayTime == .night
    }

    static func isLoadedDay(
        _ dayContext: CoachDayContext,
        readiness: CoachReadinessStateV3
    ) -> Bool {
        dayContext.dayRisk == .high ||
        dayContext.dayType == .highLoad ||
        dayContext.completedTrainingStressScore >= 4 ||
        dayContext.completedTrainingMinutes >= 90 ||
        dayContext.completedActivityVolumeMinutes >= 120 ||
        readiness.recoveryProtectionUseful
    }

    static func activityName(_ scenario: CoachActivityScenario) -> String {
        let raw = scenario.activity?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? fallbackActivityName(scenario) : raw
    }

    static func fallbackActivityName(_ scenario: CoachActivityScenario) -> String {
        switch scenario.archetype {
        case .performance:
            return "Training"
        case .endurance:
            return "Endurance"
        case .recovery:
            return "Recovery"
        case .heat:
            return "Heat"
        case .meal, .stable:
            return "Activity"
        }
    }

    static func normalizedActivityText(_ scenario: CoachActivityScenario) -> String {
        let title = scenario.activity?.title ?? ""
        let type = scenario.activity?.type ?? ""
        return "\(title) \(type)".lowercased()
    }

    static func loadedDayMessage(
        dayContext: CoachDayContext,
        recoveryContext: CoachRecoveryContext,
        action: String
    ) -> String {
        "\(recoveryLine(recoveryContext)) \(loadProgressLine(dayContext)) \(action)"
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func recoveryLine(_ context: CoachRecoveryContext) -> String {
        let recovery = context.recoveryPercent
        let sleep = context.sleepHours

        guard recovery > 0 else {
            return ""
        }

        if recovery >= 80 {
            if sleep > 0 {
                return "Recovery remains strong at \(recovery)% after \(oneDecimal(sleep))h sleep."
            }

            return "Recovery remains strong at \(recovery)%."
        }

        if recovery >= 65 {
            if sleep > 0 {
                return "Recovery is moderate at \(recovery)% after \(oneDecimal(sleep))h sleep."
            }

            return "Recovery is moderate at \(recovery)%."
        }

        if sleep > 0 {
            return "Recovery is limited at \(recovery)% after \(oneDecimal(sleep))h sleep."
        }

        return "Recovery is limited at \(recovery)%."
    }

    static func loadProgressLine(_ dayContext: CoachDayContext) -> String {
        let completedTraining = dayContext.completedTrainingMinutes
        let completedActivity = dayContext.completedActivityVolumeMinutes
        let upcoming = dayContext.upcomingTrainingMinutes

        if completedTraining > 0 && upcoming > 0 {
            return "You've completed \(formatMinutes(completedTraining)) of training, with \(formatMinutes(upcoming)) still planned."
        }

        if completedTraining > 0 {
            return "You've completed \(formatMinutes(completedTraining)) of training today."
        }

        if completedActivity > 0 && upcoming > 0 {
            return "You've completed \(formatMinutes(completedActivity)) of activity, with \(formatMinutes(upcoming)) of training still planned."
        }

        if completedActivity > 0 {
            return "You've completed \(formatMinutes(completedActivity)) of activity today."
        }

        if upcoming > 0 {
            return "\(formatMinutes(upcoming)) of training is still planned today."
        }

        return "Today is already a loaded day."
    }

    static func activityVolumeLine(_ dayContext: CoachDayContext) -> String {
        let completed = dayContext.completedActivityVolumeMinutes
        let upcoming = dayContext.upcomingTrainingMinutes

        if completed > 0 && upcoming > 0 {
            return "You've already completed \(formatMinutes(completed)) of activity today, with \(formatMinutes(upcoming)) of training still planned."
        }

        if completed > 0 {
            return "You've already completed \(formatMinutes(completed)) of activity today."
        }

        if upcoming > 0 {
            return "\(formatMinutes(upcoming)) of training is still planned today."
        }

        return "Today is already a loaded day."
    }

    static func trainingProgressLine(_ dayContext: CoachDayContext) -> String {
        let completedTraining = dayContext.completedTrainingMinutes
        let completedActivity = dayContext.completedActivityVolumeMinutes
        let upcoming = dayContext.upcomingTrainingMinutes

        if completedTraining > 0 && upcoming > 0 {
            return "You've completed \(formatMinutes(completedTraining)) of training, with \(formatMinutes(upcoming)) still ahead."
        }

        if completedTraining > 0 {
            return "You've completed \(formatMinutes(completedTraining)) of training today."
        }

        if completedActivity > 0 && upcoming > 0 {
            return "You've completed \(formatMinutes(completedActivity)) of activity, with \(formatMinutes(upcoming)) of training still ahead."
        }

        if completedActivity > 0 {
            return "You've completed \(formatMinutes(completedActivity)) of activity today."
        }

        return "Today's load is already meaningful."
    }

    static func completionLine(_ scenario: CoachActivityScenario) -> String {
        let name = activityName(scenario)
        let minutes = scenario.minutesSinceEnd ?? 0

        if minutes > 0 {
            return "\(name) finished \(minutes)m ago."
        }

        return "\(name) is completed."
    }

    static func extraIntensityNote(_ dayContext: CoachDayContext) -> String {
        if dayContext.upcomingTrainingMinutes > 0 {
            return "Extra intensity now adds fatigue on top of the remaining plan."
        }

        return "Extra intensity adds fatigue without adding much benefit today."
    }


    static func recoveryNutritionFocus(
        scenario: CoachActivityScenario,
        nutritionContext: CoachNutritionContext?,
        base: [String],
        late: Bool
    ) -> [String] {

        var result: [String] = []

        func add(_ value: String?) {
            guard let value else { return }

            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }

            guard !result.contains(where: {
                $0.caseInsensitiveCompare(cleaned) == .orderedSame
            }) else {
                return
            }

            result.append(cleaned)
        }

        add(base.first)

        if let proteinText = nutritionContext?.recommendedProteinText {
            add(proteinText)
        }

        if needsElectrolytesAfter(scenario) {
            if nutritionContext?.recommendedHydrationText != nil {
                add("Water + electrolytes")
            } else {
                add("Electrolytes if you sweat")
            }
        } else if let hydrationText = nutritionContext?.recommendedHydrationText {
            add(hydrationText)
        }

        if late {
            add("Protect sleep")
        }

        base.dropFirst().forEach { add($0) }

        return Array(result.prefix(3))
    }

    static func recoveryNutritionActions(
        scenario: CoachActivityScenario,
        nutritionContext: CoachNutritionContext?,
        fallback: [CoachSupportActionTypeV3],
        late: Bool
    ) -> [CoachSupportActionTypeV3] {

        var result: [CoachSupportActionTypeV3] = []

        func add(_ type: CoachSupportActionTypeV3) {
            guard !result.contains(type) else { return }
            result.append(type)
        }

        if fallback.contains(.cooldown) {
            add(.cooldown)
        }

        if nutritionContext?.recommendedProteinText != nil {
            add(.recoveryMeal)
        }

        if needsElectrolytesAfter(scenario) {
            add(.electrolyteRecovery)
        } else if nutritionContext?.recommendedHydrationText != nil {
            add(.rehydrateGradually)
        }

        if late {
            add(.sleepPriority)
        }

        fallback.forEach { add($0) }

        return Array(result.prefix(3))
    }

    static func needsElectrolytesAfter(_ scenario: CoachActivityScenario) -> Bool {
        let text = normalizedActivityText(scenario)

        let isSweatySport =
            text.contains("running") ||
            text.contains("run") ||
            text.contains("cycling") ||
            text.contains("cycle") ||
            text.contains("bike") ||
            text.contains("tennis") ||
            text.contains("squash") ||
            text.contains("sauna") ||
            text.contains("heat")

        guard isSweatySport else {
            return false
        }

        return scenario.load == .high ||
               scenario.load == .extreme ||
               scenario.durationBucket == .sixtyTo90 ||
               scenario.durationBucket == .over90 ||
               text.contains("sauna") ||
               text.contains("heat")
    }


    static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    static func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remainder = minutes % 60

        if remainder == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainder)m"
    }
}

private extension String {

    var isStretchingLike: Bool {
        contains("stretch") ||
        contains("mobility") ||
        contains("yoga")
    }

    var isBreathingLike: Bool {
        contains("breath") ||
        contains("breathing")
    }

    var isWalkLike: Bool {
        contains("walk") ||
        contains("walking") ||
        contains("hike")
    }
}
