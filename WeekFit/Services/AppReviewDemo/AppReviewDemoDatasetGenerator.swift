import Foundation

enum AppReviewDemoScenario: String, CaseIterable, Identifiable, Equatable {
    case readyToTrain
    case keepItModerate
    case recoveryFirst

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .readyToTrain:
            return "appReviewDemo.scenario.readyToTrain"
        case .keepItModerate:
            return "appReviewDemo.scenario.keepItModerate"
        case .recoveryFirst:
            return "appReviewDemo.scenario.recoveryFirst"
        }
    }

    var displayName: String {
        WeekFitLocalizedString(localizationKey)
    }
}

struct AppReviewDemoUserProfile: Equatable {
    let weightKg: Double
    let heightCm: Double
    let age: Int
    let biologicalSex: BiologicalSex
    let vo2Max: Double

    static let defaultProfile = AppReviewDemoUserProfile(
        weightKg: 72,
        heightCm: 178,
        age: 32,
        biologicalSex: .male,
        vo2Max: 42
    )
}

struct AppReviewDemoDayBundle: Equatable {
    let activityMetrics: ActivityMetricsSnapshot
    let sleepSnapshot: RecoverySleepSnapshot
    let nutrition: NutritionMetricsSnapshot?
    let hourlyActiveCalories: [Double]
}

struct AppReviewDemoDataset: Equatable {
    let referenceDate: Date
    let scenario: AppReviewDemoScenario
    let userProfile: AppReviewDemoUserProfile
    let dayBundles: [Date: AppReviewDemoDayBundle]

    func bundle(for date: Date, calendar: Calendar = .current) -> AppReviewDemoDayBundle? {
        dayBundles[calendar.startOfDay(for: date)]
    }

    func activityMetrics(for date: Date, calendar: Calendar = .current) -> ActivityMetricsSnapshot {
        bundle(for: date, calendar: calendar)?.activityMetrics ?? .empty
    }

    func sleepSnapshot(for date: Date, calendar: Calendar = .current) -> RecoverySleepSnapshot {
        bundle(for: date, calendar: calendar)?.sleepSnapshot ?? .empty
    }

    func nutrition(for date: Date, calendar: Calendar = .current) -> NutritionMetricsSnapshot? {
        bundle(for: date, calendar: calendar)?.nutrition
    }

    func hourlyActiveCalories(for date: Date, calendar: Calendar = .current) -> [Double] {
        bundle(for: date, calendar: calendar)?.hourlyActiveCalories ?? Array(repeating: 0, count: 24)
    }
}

enum AppReviewDemoDatasetGenerator {

    static let historyDayCount = 30
    static let futureDayCount = 7

    static func generate(
        scenario: AppReviewDemoScenario,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> AppReviewDemoDataset {
        let today = calendar.startOfDay(for: referenceDate)
        let profile = AppReviewDemoUserProfile.defaultProfile
        var bundles: [Date: AppReviewDemoDayBundle] = [:]

        for offset in 0..<historyDayCount {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            bundles[dayStart] = makeDayBundle(
                dayStart: dayStart,
                dayOffset: offset,
                scenario: scenario,
                profile: profile,
                calendar: calendar
            )
        }

        for offset in 1...futureDayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            bundles[dayStart] = makeDayBundle(
                dayStart: dayStart,
                dayOffset: -offset,
                scenario: scenario,
                profile: profile,
                calendar: calendar
            )
        }

        return AppReviewDemoDataset(
            referenceDate: today,
            scenario: scenario,
            userProfile: profile,
            dayBundles: bundles
        )
    }

    private static func makeDayBundle(
        dayStart: Date,
        dayOffset: Int,
        scenario: AppReviewDemoScenario,
        profile: AppReviewDemoUserProfile,
        calendar: Calendar
    ) -> AppReviewDemoDayBundle {
        let variation = deterministicVariation(dayOffset: dayOffset, scenario: scenario)
        let sleep = sleepSnapshot(
            dayStart: dayStart,
            dayOffset: dayOffset,
            scenario: scenario,
            variation: variation,
            calendar: calendar
        )
        let activity = activityMetrics(
            dayOffset: dayOffset,
            scenario: scenario,
            variation: variation,
            sleep: sleep,
            profile: profile
        )
        let nutrition = nutritionSnapshot(dayOffset: dayOffset, variation: variation)
        let hourly = hourlyCalories(
            totalActiveCalories: activity.activeCalories,
            variation: variation
        )

        return AppReviewDemoDayBundle(
            activityMetrics: activity,
            sleepSnapshot: sleep,
            nutrition: nutrition,
            hourlyActiveCalories: hourly
        )
    }

    private struct DayVariation {
        let sleepDelta: Int
        let hrvDelta: Double
        let rhrDelta: Double
        let activityScale: Double
        let stepsDelta: Int
    }

    private static func deterministicVariation(
        dayOffset: Int,
        scenario: AppReviewDemoScenario
    ) -> DayVariation {
        let seed = UInt64(10_000 + dayOffset * 37 + scenarioSeed(scenario))
        return DayVariation(
            sleepDelta: pseudoRandom(seed: seed, range: -35...30),
            hrvDelta: pseudoRandom(seed: seed &+ 11, range: -6.0...8.0),
            rhrDelta: pseudoRandom(seed: seed &+ 23, range: -2.5...3.0),
            activityScale: pseudoRandom(seed: seed &+ 41, range: 0.72...1.18),
            stepsDelta: Int(pseudoRandom(seed: seed &+ 59, range: -1800.0...2200.0))
        )
    }

    private static func scenarioSeed(_ scenario: AppReviewDemoScenario) -> Int {
        switch scenario {
        case .readyToTrain: return 1
        case .keepItModerate: return 2
        case .recoveryFirst: return 3
        }
    }

    private static func pseudoRandom(seed: UInt64, range: ClosedRange<Double>) -> Double {
        var value = seed &* 1_103_515_245 &+ 12_345
        value ^= value >> 13
        value ^= value << 7
        value ^= value >> 17
        let normalized = Double(value % 10_000) / 10_000.0
        return range.lowerBound + (range.upperBound - range.lowerBound) * normalized
    }

    private static func pseudoRandom(seed: UInt64, range: ClosedRange<Int>) -> Int {
        Int(pseudoRandom(seed: seed, range: Double(range.lowerBound)...Double(range.upperBound)).rounded())
    }

    private static func sleepSnapshot(
        dayStart: Date,
        dayOffset: Int,
        scenario: AppReviewDemoScenario,
        variation: DayVariation,
        calendar: Calendar
    ) -> RecoverySleepSnapshot {
        let targets = scenarioSleepTargets(scenario: scenario, dayOffset: dayOffset)
        let sleepMinutes = max(300, targets.sleepMinutes + variation.sleepDelta)
        let timeInBedMinutes = sleepMinutes + targets.timeInBedExtra + max(0, variation.sleepDelta / 4)
        let awakeMinutes = max(8, targets.awakeMinutes + abs(variation.sleepDelta / 6))
        let awakeningsCount = max(0, targets.awakenings + abs(variation.sleepDelta / 25))
        let deepSleepMinutes = Int(Double(sleepMinutes) * targets.deepRatio)
        let remSleepMinutes = Int(Double(sleepMinutes) * targets.remRatio)
        let coreSleepMinutes = max(0, sleepMinutes - deepSleepMinutes - remSleepMinutes - awakeMinutes)

        var bedComponents = calendar.dateComponents([.year, .month, .day], from: dayStart)
        bedComponents.hour = targets.bedHour
        bedComponents.minute = max(0, min(59, targets.bedMinute + (variation.sleepDelta % 17)))
        let bedStart = calendar.date(byAdding: .day, value: -1, to: calendar.date(from: bedComponents) ?? dayStart)
        let wakeTime = bedStart.map { $0.addingTimeInterval(TimeInterval(timeInBedMinutes * 60)) }

        return RecoverySleepSnapshot(
            sleepMinutes: sleepMinutes,
            timeInBedMinutes: timeInBedMinutes,
            awakeMinutes: awakeMinutes,
            awakeningsCount: awakeningsCount,
            deepSleepMinutes: deepSleepMinutes,
            remSleepMinutes: remSleepMinutes,
            coreSleepMinutes: coreSleepMinutes,
            bedStart: bedStart,
            wakeTime: wakeTime
        )
    }

    private struct SleepTargets {
        let sleepMinutes: Int
        let timeInBedExtra: Int
        let awakeMinutes: Int
        let awakenings: Int
        let deepRatio: Double
        let remRatio: Double
        let bedHour: Int
        let bedMinute: Int
    }

    private static func scenarioSleepTargets(
        scenario: AppReviewDemoScenario,
        dayOffset: Int
    ) -> SleepTargets {
        switch scenario {
        case .readyToTrain:
            return SleepTargets(
                sleepMinutes: dayOffset == 0 ? 485 : 455,
                timeInBedExtra: 20,
                awakeMinutes: 16,
                awakenings: 2,
                deepRatio: 0.18,
                remRatio: 0.22,
                bedHour: 22,
                bedMinute: 42
            )
        case .keepItModerate:
            return SleepTargets(
                sleepMinutes: dayOffset == 0 ? 455 : 448,
                timeInBedExtra: 22,
                awakeMinutes: 20,
                awakenings: 2,
                deepRatio: 0.17,
                remRatio: 0.21,
                bedHour: 22,
                bedMinute: 52
            )
        case .recoveryFirst:
            return SleepTargets(
                sleepMinutes: dayOffset == 0 ? 352 : 410,
                timeInBedExtra: 28,
                awakeMinutes: 34,
                awakenings: 4,
                deepRatio: 0.14,
                remRatio: 0.18,
                bedHour: 23,
                bedMinute: 18
            )
        }
    }

    private static func activityMetrics(
        dayOffset: Int,
        scenario: AppReviewDemoScenario,
        variation: DayVariation,
        sleep: RecoverySleepSnapshot,
        profile: AppReviewDemoUserProfile
    ) -> ActivityMetricsSnapshot {
        let workout = workoutPlan(dayOffset: dayOffset, scenario: scenario)
        let steps = max(1200, workout.baseSteps + variation.stepsDelta)
        let distanceKm = Double(steps) / 1350.0
        let activeCalories = max(120, (workout.activeCalories * variation.activityScale).rounded())
        let exerciseMinutes = max(0, Int((Double(workout.exerciseMinutes) * variation.activityScale).rounded()))
        let standHours = min(12, max(4, 8 + dayOffset % 3))
        let physiology = physiologyTargets(scenario: scenario, dayOffset: dayOffset)

        return ActivityMetricsSnapshot(
            activeCalories: activeCalories,
            steps: steps,
            exerciseMinutes: exerciseMinutes,
            sleepMinutes: sleep.sleepMinutes,
            timeInBedMinutes: sleep.timeInBedMinutes,
            awakeMinutes: sleep.awakeMinutes,
            awakeningsCount: sleep.awakeningsCount,
            distanceKm: distanceKm,
            standHours: standHours,
            vo2Max: profile.vo2Max,
            deepSleepMinutes: sleep.deepSleepMinutes,
            remSleepMinutes: sleep.remSleepMinutes,
            coreSleepMinutes: sleep.coreSleepMinutes,
            restingHeartRate: max(44, physiology.rhr + variation.rhrDelta),
            hrvSDNN: max(20, physiology.hrv + variation.hrvDelta)
        )
    }

    private struct WorkoutPlan {
        let activeCalories: Double
        let exerciseMinutes: Int
        let baseSteps: Int
    }

    private static func workoutPlan(dayOffset: Int, scenario: AppReviewDemoScenario) -> WorkoutPlan {
        switch dayOffset {
        case 0:
            switch scenario {
            case .readyToTrain:
                return WorkoutPlan(activeCalories: 280, exerciseMinutes: 24, baseSteps: 5400)
            case .keepItModerate:
                return WorkoutPlan(activeCalories: 340, exerciseMinutes: 28, baseSteps: 6100)
            case .recoveryFirst:
                return WorkoutPlan(activeCalories: 180, exerciseMinutes: 14, baseSteps: 4200)
            }
        case 1:
            switch scenario {
            case .readyToTrain:
                return WorkoutPlan(activeCalories: 580, exerciseMinutes: 58, baseSteps: 10_200)
            case .keepItModerate:
                return WorkoutPlan(activeCalories: 610, exerciseMinutes: 58, baseSteps: 10_400)
            case .recoveryFirst:
                return WorkoutPlan(activeCalories: 780, exerciseMinutes: 74, baseSteps: 11_200)
            }
        case 2:
            return WorkoutPlan(activeCalories: 390, exerciseMinutes: 38, baseSteps: 8200)
        case 3:
            return WorkoutPlan(activeCalories: 210, exerciseMinutes: 22, baseSteps: 6500)
        case 4:
            return WorkoutPlan(activeCalories: 640, exerciseMinutes: 62, baseSteps: 10_800)
        case 5:
            return WorkoutPlan(activeCalories: 450, exerciseMinutes: 44, baseSteps: 9100)
        case 6:
            return WorkoutPlan(activeCalories: 720, exerciseMinutes: 82, baseSteps: 12_400)
        default:
            let heavyDay = dayOffset % 5 == 0
            let restDay = dayOffset % 7 == 3
            if restDay {
                return WorkoutPlan(activeCalories: 240, exerciseMinutes: 20, baseSteps: 5600)
            }
            if heavyDay {
                return WorkoutPlan(activeCalories: 590, exerciseMinutes: 56, baseSteps: 9800)
            }
            return WorkoutPlan(activeCalories: 410, exerciseMinutes: 40, baseSteps: 7600)
        }
    }

    private struct PhysiologyTargets {
        let hrv: Double
        let rhr: Double
    }

    private static func physiologyTargets(
        scenario: AppReviewDemoScenario,
        dayOffset: Int
    ) -> PhysiologyTargets {
        switch scenario {
        case .readyToTrain:
            return PhysiologyTargets(hrv: dayOffset == 0 ? 56 : 53, rhr: dayOffset == 0 ? 52 : 52)
        case .keepItModerate:
            return PhysiologyTargets(hrv: dayOffset == 0 ? 52 : 51, rhr: dayOffset == 0 ? 53 : 52)
        case .recoveryFirst:
            return PhysiologyTargets(hrv: dayOffset == 0 ? 44 : 48, rhr: dayOffset == 0 ? 58 : 55)
        }
    }

    private static func nutritionSnapshot(
        dayOffset: Int,
        variation: DayVariation
    ) -> NutritionMetricsSnapshot? {
        guard dayOffset <= 6 else { return nil }

        let progress: Double
        if dayOffset == 0 {
            let hour = Calendar.current.component(.hour, from: Date())
            progress = min(1.0, max(0.35, Double(hour - 6) / 14.0))
        } else {
            progress = 1.0
        }

        let baseCalories = 2350.0 + Double(dayOffset % 3) * 90
        let calories = (baseCalories * progress).rounded()
        let protein = (calories * 0.28 / 4).rounded()
        let carbs = (calories * 0.42 / 4).rounded()
        let fats = (calories * 0.22 / 9).rounded()
        let waterLiters = (2.4 + Double(dayOffset % 4) * 0.2 + variation.activityScale * 0.3) * progress

        return NutritionMetricsSnapshot(
            protein: protein,
            carbs: carbs,
            fats: fats,
            calories: calories,
            waterLiters: waterLiters,
            mealsLoggedCount: dayOffset == 0 ? max(2, Int((progress * 4).rounded())) : 4,
            isResolved: true
        )
    }

    private static func hourlyCalories(
        totalActiveCalories: Double,
        variation: DayVariation
    ) -> [Double] {
        let weights: [Double] = [
            0.01, 0.01, 0.01, 0.01, 0.02, 0.03,
            0.05, 0.07, 0.08, 0.07, 0.06, 0.05,
            0.05, 0.06, 0.07, 0.08, 0.09, 0.10,
            0.08, 0.05, 0.04, 0.03, 0.02, 0.01
        ]
        let scale = max(0.8, variation.activityScale)
        return weights.map { weight in
            (totalActiveCalories * weight * scale).rounded()
        }
    }
}

extension AppReviewDemoDatasetGenerator {

    static func recoveryScoreContext(
        for date: Date,
        dataset: AppReviewDemoDataset,
        calendar: Calendar = .current
    ) -> RecoveryScoreContext {
        let dayStart = calendar.startOfDay(for: date)
        let baseline = physiologyBaseline(endingAt: dayStart, dataset: dataset, calendar: calendar)
        let priorDayLoad = priorDayLoad(for: dayStart, dataset: dataset, calendar: calendar)
        let bedtimeDeviation = bedtimeDeviationMinutes(for: dayStart, dataset: dataset, calendar: calendar)
        return RecoveryScoreContext(
            baseline: baseline,
            priorDayLoad: priorDayLoad,
            bedtimeDeviationMinutes: bedtimeDeviation
        )
    }

    private static func physiologyBaseline(
        endingAt date: Date,
        dataset: AppReviewDemoDataset,
        calendar: Calendar
    ) -> RecoveryPhysiologyBaseline {
        var hrvValues: [Double] = []
        var rhrValues: [Double] = []

        for offset in 1...RecoveryPhysiologyBaseline.preferredWindowDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else { continue }
            let metrics = dataset.activityMetrics(for: day, calendar: calendar)
            if metrics.hrvSDNN > 0 { hrvValues.append(metrics.hrvSDNN) }
            if metrics.restingHeartRate > 0 { rhrValues.append(metrics.restingHeartRate) }
        }

        return RecoveryPhysiologyBaseline(
            hrvMedian: median(hrvValues),
            hrvSampleCount: hrvValues.count,
            restingHeartRateMedian: median(rhrValues),
            restingHeartRateSampleCount: rhrValues.count,
            windowDays: RecoveryPhysiologyBaseline.preferredWindowDays
        )
    }

    private static func priorDayLoad(
        for date: Date,
        dataset: AppReviewDemoDataset,
        calendar: Calendar
    ) -> RecoveryPriorDayLoad {
        guard let priorDay = calendar.date(byAdding: .day, value: -1, to: date) else {
            return .empty
        }
        let metrics = dataset.activityMetrics(for: priorDay, calendar: calendar)
        let workoutCount = metrics.exerciseMinutes >= 45 ? 1 : 0
        return RecoveryPriorDayLoad(
            exerciseMinutes: metrics.exerciseMinutes,
            activeCalories: metrics.activeCalories,
            workoutCount: workoutCount + (metrics.exerciseMinutes >= 75 ? 1 : 0)
        )
    }

    private static func bedtimeDeviationMinutes(
        for date: Date,
        dataset: AppReviewDemoDataset,
        calendar: Calendar
    ) -> Int? {
        guard let sleep = dataset.bundle(for: date, calendar: calendar)?.sleepSnapshot,
              let bedStart = sleep.bedStart else {
            return nil
        }

        var recent: [Int] = []
        for offset in 1...7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date),
                  let priorBed = dataset.bundle(for: day, calendar: calendar)?.sleepSnapshot.bedStart else {
                continue
            }
            recent.append(RecoveryScoreEngine.normalizedBedtimeMinutes(priorBed))
        }

        guard !recent.isEmpty else { return nil }
        let medianBedtime = median(recent.map(Double.init)) ?? Double(RecoveryScoreEngine.normalizedBedtimeMinutes(bedStart))
        let current = RecoveryScoreEngine.normalizedBedtimeMinutes(bedStart)
        return abs(current - Int(medianBedtime.rounded()))
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}
