import SwiftUI
import HealthKit
internal import Combine

struct RecoveryScoreContext: Equatable {
    let baseline: RecoveryPhysiologyBaseline
    let priorDayLoad: RecoveryPriorDayLoad
    let bedtimeDeviationMinutes: Int?
}

final class RecoveryHealthKitProvider {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        var types = Set<HKObjectType>()

        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }

        if let restingHR = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }

        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }

        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }

        if let exerciseTime = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exerciseTime)
        }

        types.insert(HKObjectType.workoutType())

        do {
            try await healthStore.requestAuthorization(toShare: [], read: types)
            return true
        } catch {
            return false
        }
    }

    func loadSnapshot(for date: Date) async -> RecoveryDaySnapshot {
        async let sleepSamples = loadSleepSamples(for: date)
        async let restingHR = loadOvernightMedianQuantity(
            identifier: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            for: date
        )
        async let hrv = loadOvernightMedianQuantity(
            identifier: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            for: date
        )

        return await buildSnapshot(
            date: date,
            sleepSamples: sleepSamples,
            restingHeartRate: restingHR,
            hrv: hrv
        )
    }

    func loadRecoveryScoreContext(
        for date: Date,
        currentBedStart: Date?
    ) async -> RecoveryScoreContext {
        async let baseline = loadPhysiologyBaseline(for: date)
        async let priorDayLoad = loadPriorDayLoad(for: date)
        async let bedtimeDeviation = bedtimeDeviationMinutes(for: date, currentBedStart: currentBedStart)

        return RecoveryScoreContext(
            baseline: await baseline,
            priorDayLoad: await priorDayLoad,
            bedtimeDeviationMinutes: await bedtimeDeviation
        )
    }

    func loadOvernightVitals(for date: Date) async -> (hrv: Double?, restingHeartRate: Double?) {
        async let hrv = loadOvernightMedianQuantity(
            identifier: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            for: date
        )
        async let restingHR = loadOvernightMedianQuantity(
            identifier: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            for: date
        )

        return (await hrv, await restingHR)
    }

    func bedtimeDeviationMinutes(for date: Date, currentBedStart: Date?) async -> Int? {
        let calendar = calendar
        var historicalBedStarts: [Date] = []

        for dayOffset in 1...RecoveryPhysiologyBaseline.preferredWindowDays {
            guard let pastDate = calendar.date(byAdding: .day, value: -dayOffset, to: date) else { continue }
            let sleepSamples = await loadSleepSamples(for: pastDate)
            if let bedStart = primaryBedStart(from: sleepSamples) {
                historicalBedStarts.append(bedStart)
            }
        }

        return RecoveryScoreEngine.bedtimeDeviationMinutes(
            currentBedStart: currentBedStart,
            historicalBedStarts: historicalBedStarts,
            calendar: calendar
        )
    }

    func loadPhysiologyBaseline(for date: Date) async -> RecoveryPhysiologyBaseline {
        var hrvValues: [Double] = []
        var rhrValues: [Double] = []

        for dayOffset in 1...RecoveryPhysiologyBaseline.preferredWindowDays {
            guard let pastDate = calendar.date(byAdding: .day, value: -dayOffset, to: date) else { continue }

            if let hrv = await loadOvernightMedianQuantity(
                identifier: .heartRateVariabilitySDNN,
                unit: HKUnit.secondUnit(with: .milli),
                for: pastDate
            ) {
                hrvValues.append(hrv)
            }

            if let rhr = await loadOvernightMedianQuantity(
                identifier: .restingHeartRate,
                unit: HKUnit.count().unitDivided(by: .minute()),
                for: pastDate
            ) {
                rhrValues.append(rhr)
            }
        }

        return RecoveryPhysiologyBaseline(
            hrvMedian: RecoveryScoreEngine.medianBaseline(hrvValues),
            hrvSampleCount: hrvValues.count,
            restingHeartRateMedian: RecoveryScoreEngine.medianBaseline(rhrValues),
            restingHeartRateSampleCount: rhrValues.count,
            windowDays: RecoveryPhysiologyBaseline.preferredWindowDays
        )
    }

    func loadPriorDayLoad(for date: Date) async -> RecoveryPriorDayLoad {
        guard let priorDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) else {
            return .empty
        }

        let dayStart = calendar.startOfDay(for: priorDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? priorDate

        async let exerciseMinutes = loadDaySum(
            identifier: .appleExerciseTime,
            unit: .minute(),
            start: dayStart,
            end: dayEnd
        )
        async let activeCalories = loadDaySum(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            start: dayStart,
            end: dayEnd
        )
        async let workouts = loadWorkouts(start: dayStart, end: dayEnd)

        let resolvedExercise = Int(await exerciseMinutes.rounded())
        let resolvedWorkouts = await workouts

        return RecoveryPriorDayLoad(
            exerciseMinutes: resolvedExercise,
            activeCalories: await activeCalories,
            workoutCount: resolvedWorkouts.count
        )
    }

    private func primaryBedStart(from sleepSamples: [HKCategorySample]) -> Date? {
        let appleSamples = sleepSamples.filter {
            $0.sourceRevision.source.bundleIdentifier.hasPrefix("com.apple")
        }

        let samplesForParsing = appleSamples.isEmpty ? sleepSamples : appleSamples

        let inBedSamples = samplesForParsing.filter {
            $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue
        }

        let asleepSamples = samplesForParsing.filter {
            isAsleepValue($0.value)
        }

        return makePrimarySleepSession(
            inBedSamples: inBedSamples,
            asleepSamples: asleepSamples
        )?.start
    }

    private func loadSleepSamples(for date: Date) async -> [HKCategorySample] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }

        let range = sleepWindow(for: date)

        let predicate = HKQuery.predicateForSamples(
            withStart: range.start,
            end: range.end,
            options: []
        )

        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                guard error == nil else {
                    continuation.resume(returning: [])
                    return
                }

                continuation.resume(returning: samples as? [HKCategorySample] ?? [])
            }

            healthStore.execute(query)
        }
    }

    private func loadOvernightMedianQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        for date: Date
    ) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let range = sleepWindow(for: date)

        let predicate = HKQuery.predicateForSamples(
            withStart: range.start,
            end: range.end,
            options: []
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                let values = (samples as? [HKQuantitySample] ?? []).map {
                    $0.quantity.doubleValue(for: unit)
                }.filter { $0 > 0 }

                continuation.resume(returning: RecoveryScoreEngine.medianBaseline(values))
            }

            healthStore.execute(query)
        }
    }

    private func loadDaySum(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    private func loadWorkouts(start: Date, end: Date) async -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard error == nil else {
                    continuation.resume(returning: [])
                    return
                }

                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }

            healthStore.execute(query)
        }
    }

    private func sleepWindow(for date: Date) -> DateInterval {
        let dayStart = calendar.startOfDay(for: date)

        let start = calendar.date(
            byAdding: .hour,
            value: -12,
            to: dayStart
        ) ?? dayStart

        let end = calendar.date(
            byAdding: .hour,
            value: 14,
            to: dayStart
        ) ?? date

        return DateInterval(start: start, end: end)
    }

    private func buildSnapshot(
        date: Date,
        sleepSamples: [HKCategorySample],
        restingHeartRate: Double?,
        hrv: Double?
    ) -> RecoveryDaySnapshot {

        let appleSamples = sleepSamples.filter {
            $0.sourceRevision.source.bundleIdentifier.hasPrefix("com.apple")
        }

        let samplesForParsing = appleSamples.isEmpty ? sleepSamples : appleSamples

        let inBedSamples = samplesForParsing.filter {
            $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue
        }

        let awakeSamples = samplesForParsing.filter {
            $0.value == HKCategoryValueSleepAnalysis.awake.rawValue
        }

        let asleepSamples = samplesForParsing.filter {
            isAsleepValue($0.value)
        }

        let deepSamples = samplesForParsing.filter {
            isDeepSleepValue($0.value)
        }

        let remSamples = samplesForParsing.filter {
            isREMSleepValue($0.value)
        }

        let coreSamples = samplesForParsing.filter {
            isCoreSleepValue($0.value)
        }

        guard let session = makePrimarySleepSession(
            inBedSamples: inBedSamples,
            asleepSamples: asleepSamples
        ) else {
            return RecoveryDaySnapshot(
                date: date,
                recoveryScore: 0,
                recoveryBreakdown: .empty,
                sleepScore: 0,
                timeInBedMinutes: 0,
                asleepMinutes: 0,
                awakeMinutes: 0,
                deepSleepMinutes: 0,
                remSleepMinutes: 0,
                coreSleepMinutes: 0,
                bedStart: nil,
                wakeTime: nil,
                awakeningsCount: 0,
                restingHeartRate: restingHeartRate,
                hrv: hrv,
                recoveryInput: nil,
                insightTitle: "No sleep detected",
                insightText: "Apple Health does not have sleep data for this night.",
                actionTitle: "Recommended",
                actionText: "Use Apple Watch during sleep or check Sleep Focus settings."
            )
        }

        let sessionStart = session.start
        let sessionEnd = session.end
        let bedStart = firstAsleepStart(
            in: session,
            asleepSamples: asleepSamples,
            deepSamples: deepSamples,
            remSamples: remSamples,
            coreSamples: coreSamples
        ) ?? sessionStart
        let timeInBed = max(Int(sessionEnd.timeIntervalSince(sessionStart) / 60), 0)

        let filteredAsleepSamples = overlappingSamples(
            asleepSamples,
            start: sessionStart,
            end: sessionEnd
        )

        let filteredAwakeSamples = overlappingSamples(
            awakeSamples,
            start: sessionStart,
            end: sessionEnd
        )

        let filteredDeepSamples = overlappingSamples(
            deepSamples,
            start: sessionStart,
            end: sessionEnd
        )

        let filteredRemSamples = overlappingSamples(
            remSamples,
            start: sessionStart,
            end: sessionEnd
        )

        let filteredCoreSamples = overlappingSamples(
            coreSamples,
            start: sessionStart,
            end: sessionEnd
        )

        let deep = clippedMinutes(
            filteredDeepSamples,
            start: sessionStart,
            end: sessionEnd
        )

        let rem = clippedMinutes(
            filteredRemSamples,
            start: sessionStart,
            end: sessionEnd
        )

        let core = clippedMinutes(
            filteredCoreSamples,
            start: sessionStart,
            end: sessionEnd
        )

        let stagedAsleep = deep + rem + core

        let rawAsleep = clippedMinutes(
            filteredAsleepSamples,
            start: sessionStart,
            end: sessionEnd
        )

        let asleep = min(
            stagedAsleep > 0 ? stagedAsleep : rawAsleep,
            timeInBed
        )

        let rawAwake = clippedMinutes(
            filteredAwakeSamples,
            start: sessionStart,
            end: sessionEnd
        )

        let awake = min(
            max(rawAwake, timeInBed - asleep),
            timeInBed
        )

        let awakenings = filteredAwakeSamples.count

        let sleepScore = calculateSleepScore(
            asleepMinutes: asleep,
            deepMinutes: deep,
            remMinutes: rem,
            awakeMinutes: awake,
            awakenings: awakenings
        )

        let placeholderRecoveryScore = 0

        let insight = makeInsight(
            sleepScore: sleepScore,
            asleepMinutes: asleep,
            deepMinutes: deep,
            remMinutes: rem,
            awakenings: awakenings,
            hrv: hrv
        )

        return RecoveryDaySnapshot(
            date: date,
            recoveryScore: placeholderRecoveryScore,
            recoveryBreakdown: .empty,
            sleepScore: sleepScore,
            timeInBedMinutes: timeInBed,
            asleepMinutes: asleep,
            awakeMinutes: awake,
            deepSleepMinutes: deep,
            remSleepMinutes: rem,
            coreSleepMinutes: core,
            bedStart: bedStart,
            wakeTime: sessionEnd,
            awakeningsCount: awakenings,
            restingHeartRate: restingHeartRate,
            hrv: hrv,
            recoveryInput: nil,
            insightTitle: insight.title,
            insightText: insight.text,
            actionTitle: insight.actionTitle,
            actionText: insight.actionText
        )
    }

    private func makePrimarySleepSession(
        inBedSamples: [HKCategorySample],
        asleepSamples: [HKCategorySample]
    ) -> DateInterval? {

        let source = !inBedSamples.isEmpty ? inBedSamples : asleepSamples

        guard !source.isEmpty else {
            return nil
        }

        let sorted = source.sorted {
            $0.startDate < $1.startDate
        }

        var sessions: [DateInterval] = []

        for sample in sorted {
            let current = DateInterval(
                start: sample.startDate,
                end: sample.endDate
            )

            guard let last = sessions.last else {
                sessions.append(current)
                continue
            }

            let gap = current.start.timeIntervalSince(last.end)

            if gap <= 90 * 60 {
                sessions.removeLast()

                sessions.append(
                    DateInterval(
                        start: min(last.start, current.start),
                        end: max(last.end, current.end)
                    )
                )
            } else {
                sessions.append(current)
            }
        }

        return sessions.max {
            $0.duration < $1.duration
        }
    }

    private func overlappingSamples(
        _ samples: [HKCategorySample],
        start: Date,
        end: Date
    ) -> [HKCategorySample] {
        samples.filter { sample in
            sample.startDate < end && sample.endDate > start
        }
    }

    private func clippedMinutes(
        _ samples: [HKCategorySample],
        start: Date,
        end: Date
    ) -> Int {
        let seconds = samples.reduce(0.0) { result, sample in
            let clippedStart = max(sample.startDate, start)
            let clippedEnd = min(sample.endDate, end)

            guard clippedEnd > clippedStart else {
                return result
            }

            return result + clippedEnd.timeIntervalSince(clippedStart)
        }

        return Int(seconds / 60)
    }

    private func isAsleepValue(_ value: Int) -> Bool {
        if value == HKCategoryValueSleepAnalysis.asleep.rawValue {
            return true
        }

        if #available(iOS 16.0, *) {
            return value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        }

        return false
    }

    private func isDeepSleepValue(_ value: Int) -> Bool {
        if #available(iOS 16.0, *) {
            return value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
        }

        return false
    }

    private func isREMSleepValue(_ value: Int) -> Bool {
        if #available(iOS 16.0, *) {
            return value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
        }

        return false
    }

    private func isCoreSleepValue(_ value: Int) -> Bool {
        if #available(iOS 16.0, *) {
            return value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
        }

        return false
    }

    private func firstAsleepStart(
        in session: DateInterval,
        asleepSamples: [HKCategorySample],
        deepSamples: [HKCategorySample],
        remSamples: [HKCategorySample],
        coreSamples: [HKCategorySample]
    ) -> Date? {
        let stagedSamples = deepSamples + remSamples + coreSamples
        let sourceSamples = stagedSamples.isEmpty ? asleepSamples : stagedSamples

        return sourceSamples
            .filter { sample in
                sample.startDate >= session.start && sample.startDate <= session.end
            }
            .map(\.startDate)
            .min()
    }

    private func calculateSleepScore(
        asleepMinutes: Int,
        deepMinutes: Int,
        remMinutes: Int,
        awakeMinutes: Int,
        awakenings: Int
    ) -> Int {
        guard asleepMinutes > 0 else { return 0 }

        let durationScore = min(Double(asleepMinutes) / 480.0, 1.0) * 45

        let deepRatio = Double(deepMinutes) / Double(max(asleepMinutes, 1))
        let deepScore = min(deepRatio / 0.18, 1.0) * 20

        let remRatio = Double(remMinutes) / Double(max(asleepMinutes, 1))
        let remScore = min(remRatio / 0.22, 1.0) * 20

        let awakePenalty = min(Double(awakeMinutes) / 60.0, 1.0) * 8
        let wakePenalty = min(Double(awakenings) / 6.0, 1.0) * 7

        return Int(max(0, min(100, durationScore + deepScore + remScore + 15 - awakePenalty - wakePenalty)).rounded())
    }

    private func makeInsight(
        sleepScore: Int,
        asleepMinutes: Int,
        deepMinutes: Int,
        remMinutes: Int,
        awakenings: Int,
        hrv: Double?
    ) -> (title: String, text: String, actionTitle: String, actionText: String) {

        guard asleepMinutes > 0 else {
            return (
                "No sleep detected",
                "Apple Health does not have sleep data for this night.",
                "Recommended",
                "Use Apple Watch during sleep or check Sleep Focus settings."
            )
        }

        if sleepScore >= 82 {
            return (
                "Strong sleep recovery",
                "Sleep duration and sleep structure were supportive overnight.",
                "Night summary",
                "Your sleep pattern looks stable enough to support recovery."
            )
        }

        if sleepScore >= 65 {
            return (
                "Moderate sleep recovery",
                "Sleep was useful, but recovery signals were not fully optimal.",
                "Night summary",
                "Look at awake time, deep sleep and REM sleep to understand the score."
            )
        }

        if deepMinutes < 60 {
            return (
                "Low deep sleep",
                "Deep sleep was limited, which may reduce physical recovery quality.",
                "Night summary",
                "A consistent bedtime and lower late-evening stimulation may help."
            )
        }

        if awakenings >= 4 {
            return (
                "Interrupted sleep",
                "Several awake moments reduced sleep continuity during the night.",
                "Night summary",
                "Sleep continuity had a visible impact on recovery quality."
            )
        }

        return (
            "Light recovery night",
            "Sleep and overnight signals suggest recovery was not fully restored.",
            "Night summary",
            "Review sleep duration, awake time and HRV to understand the result."
        )
    }
}
