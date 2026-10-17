import Foundation

/// Client-computed day vs usual walking/running distance — never invented by the model.
enum CoachEveningRecapDayComparison {

    struct Result: Equatable, Sendable {
        let todayKm: Double
        let baselineKm: Double
        let deltaKm: Double
        let sampleCount: Int

        /// Untrusted-data style fact for `/v1/coach/day-summary` (English, numeric).
        var aiFactText: String {
            let absDelta = abs(deltaKm)
            let direction = deltaKm >= 0 ? "more" : "less"
            return String(
                format: "Client-computed comparison (do not recalculate): today walking/running distance %.1f km vs usual %.1f km (median of %d complete prior days). Delta %.1f km %@ than usual. Use at most once if helpful.",
                todayKm,
                baselineKm,
                sampleCount,
                absDelta,
                direction
            )
        }

        func displayText(unitSystem: WeekFitResolvedUnitSystem) -> String {
            let absDelta = abs(deltaKm)
            let formatted = CoachEveningRecapFormatting.formatDistance(
                kilometers: absDelta,
                system: unitSystem
            )
            if deltaKm >= 0 {
                return String(
                    format: WeekFitLocalizedString("coach.eveningRecap.comparison.moreThanUsual"),
                    formatted
                )
            }
            return String(
                format: WeekFitLocalizedString("coach.eveningRecap.comparison.lessThanUsual"),
                formatted
            )
        }
    }

    /// Minimum complete prior days and meaningful delta (km) before surfacing a comparison.
    static let minimumSamples = 5
    static let lookbackDays = 21
    static let minimumMeaningfulDeltaKm = 1.5
    static let completeDayDistanceKm = 0.5
    static let completeDaySteps = 1_500

    static func compute(
        todayDistanceKm: Double,
        priorDayMetrics: [(distanceKm: Double, steps: Int)]
    ) -> Result? {
        guard todayDistanceKm >= completeDayDistanceKm else { return nil }

        let complete = priorDayMetrics.compactMap { day -> Double? in
            guard day.distanceKm >= completeDayDistanceKm || day.steps >= completeDaySteps else {
                return nil
            }
            return day.distanceKm
        }
        guard complete.count >= minimumSamples else { return nil }

        let baseline = median(complete)
        guard baseline > 0 else { return nil }
        let delta = todayDistanceKm - baseline
        guard abs(delta) >= minimumMeaningfulDeltaKm else { return nil }

        return Result(
            todayKm: todayDistanceKm,
            baselineKm: baseline,
            deltaKm: delta,
            sampleCount: complete.count
        )
    }

    static func loadPriorMetrics(
        relativeTo now: Date,
        healthManager: HealthManager,
        calendar: Calendar = .current
    ) async -> [(distanceKm: Double, steps: Int)] {
        // Parallel lightweight reads — previously this awaited full day metrics
        // (workouts/sleep/HRV…) 21 times in series and stalled first Coach paint.
        let days: [Date] = (1...lookbackDays).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: now)
        }
        return await withTaskGroup(
            of: (Int, Double, Int).self,
            returning: [(distanceKm: Double, steps: Int)].self
        ) { group in
            for (index, day) in days.enumerated() {
                group.addTask {
                    let metrics = await healthManager.readStepsAndWalkingDistance(for: day)
                    return (index, metrics.distanceKm, metrics.steps)
                }
            }
            var ranked: [(Int, Double, Int)] = []
            ranked.reserveCapacity(days.count)
            for await item in group {
                ranked.append(item)
            }
            return ranked
                .sorted { $0.0 < $1.0 }
                .map { (distanceKm: $0.1, steps: $0.2) }
        }
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}
