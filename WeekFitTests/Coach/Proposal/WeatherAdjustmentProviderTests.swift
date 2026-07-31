import XCTest
@testable import WeekFit

final class WeatherAdjustmentProviderTests: XCTestCase {

    func testRiskResolve_precipAndHeat() {
        let rain = WeekFitWeatherSummary(
            temperature: Measurement(value: 18, unit: .celsius),
            feelsLike: Measurement(value: 18, unit: .celsius),
            highTemperature: nil,
            lowTemperature: nil,
            symbolName: "cloud.rain",
            condition: .rain,
            humidityPercent: 80,
            windSpeed: Measurement(value: 12, unit: .kilometersPerHour),
            uvIndex: 2,
            precipitationChance: 65
        )
        XCTAssertEqual(ProposalWeatherRisk.resolve(from: rain), .precip)

        let heat = WeekFitWeatherSummary(
            temperature: Measurement(value: 35, unit: .celsius),
            feelsLike: Measurement(value: 37, unit: .celsius),
            highTemperature: nil,
            lowTemperature: nil,
            symbolName: "sun.max",
            condition: .clear,
            humidityPercent: 40,
            windSpeed: Measurement(value: 8, unit: .kilometersPerHour),
            uvIndex: 9,
            precipitationChance: 0
        )
        XCTAssertEqual(ProposalWeatherRisk.resolve(from: heat), .heat)
        XCTAssertEqual(ProposalWeatherRisk.resolve(from: nil), .unavailable)
    }

    func testOutdoorClassifier_runningIsOutdoor() {
        let run = CoachPlannedActivitySnapshot(
            id: "r1",
            date: Date(),
            type: "running",
            title: "Easy Run",
            durationMinutes: 60,
            icon: "figure.run",
            imageName: "",
            isCompleted: false,
            isSkipped: false,
            source: "planner"
        )
        XCTAssertTrue(ProposalOutdoorClassifier.isOutdoorLikely(run))
    }

    func testWeatherProvider_movesAfternoonRunEarlierOnPrecip() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 31, hour: 8, minute: 0))!
        let runDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 31, hour: 18, minute: 0))!

        let run = CoachPlannedActivitySnapshot(
            id: "run-1",
            date: runDate,
            type: "running",
            title: "Tempo Run",
            durationMinutes: 60,
            icon: "figure.run",
            imageName: "",
            isCompleted: false,
            isSkipped: false,
            source: "planner"
        )

        let dayKey = ProposalInputFingerprintBuilder.dayKey(for: now)
        let fingerprint = ProposalInputFingerprintBuilder.make(
            dayKey: dayKey,
            todaySnapshots: [run],
            tomorrowSnapshots: [],
            recoveryBand: .moderate,
            sleepPresence: .present,
            scenarioKey: "none",
            yesterdayHeavy: false,
            generationMode: .optimize,
            weatherRiskToken: .precip
        )

        let input = MorningProposalEngineInput(
            now: now,
            dayKey: dayKey,
            fingerprint: fingerprint,
            scenarioKey: nil,
            recoveryBand: .moderate,
            sleepPresence: .present,
            yesterdayHeavy: false,
            tomorrowDemand: .none,
            stackedLoad: .clear,
            generationMode: .optimize,
            todayActivities: [run],
            tomorrowActivities: [],
            completedWalkToday: false,
            canMutate: true,
            recentDayTemplates: [],
            mealLibrary: [
                ProposalMealCandidate(
                    id: "m1",
                    title: "Fuel",
                    imageName: "plate-dark",
                    calories: 400,
                    protein: 20,
                    carbs: 40,
                    fats: 10,
                    fiber: 4,
                    mealsTypeRaw: "balanced",
                    suggestedTime: "13:00"
                )
            ],
            walkRejectPenalty: 0,
            stronglyRejectsWalk: false,
            weatherRiskToken: .precip
        )

        let proposal = MorningProposalEngine.generate(input: input)
        let moves = proposal.changes.filter { $0.kind == CoachChangeKind.moveActivity }
        let tips = proposal.changes.filter {
            guard case .guidanceOnly(let p) = $0.payload else { return false }
            return p.guidanceCode == .preferIndoorOrEarlier
        }

        XCTAssertFalse(moves.isEmpty, "Expected move-earlier for afternoon outdoor run in precip")
        XCTAssertFalse(tips.isEmpty, "Expected indoor/earlier weather tip")
        if case .moveActivity(let payload) = moves.first?.payload {
            let hour = calendar.component(.hour, from: payload.proposedDate)
            XCTAssertLessThan(hour, 12)
        } else {
            XCTFail("Expected move payload")
        }
    }

    func testWeatherProvider_shortensLongOutdoorOnHeat() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 31, hour: 8))!
        let rideDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 31, hour: 10))!

        let ride = CoachPlannedActivitySnapshot(
            id: "ride-1",
            date: rideDate,
            type: "cycling",
            title: "Outdoor Ride",
            durationMinutes: 90,
            icon: "bicycle",
            imageName: "",
            isCompleted: false,
            isSkipped: false,
            source: "planner"
        )

        let dayKey = ProposalInputFingerprintBuilder.dayKey(for: now)
        let fingerprint = ProposalInputFingerprintBuilder.make(
            dayKey: dayKey,
            todaySnapshots: [ride],
            tomorrowSnapshots: [],
            recoveryBand: .good,
            sleepPresence: .present,
            scenarioKey: "none",
            yesterdayHeavy: false,
            generationMode: .compose,
            weatherRiskToken: .heat
        )

        let input = MorningProposalEngineInput(
            now: now,
            dayKey: dayKey,
            fingerprint: fingerprint,
            scenarioKey: nil,
            recoveryBand: .good,
            sleepPresence: .present,
            yesterdayHeavy: false,
            tomorrowDemand: .none,
            stackedLoad: .clear,
            generationMode: .compose,
            todayActivities: [ride],
            tomorrowActivities: [],
            completedWalkToday: false,
            canMutate: true,
            recentDayTemplates: [],
            mealLibrary: [],
            walkRejectPenalty: 0,
            stronglyRejectsWalk: false,
            weatherRiskToken: .heat
        )

        let proposal = MorningProposalEngine.generate(input: input)
        let shortens = proposal.changes.filter { $0.kind == CoachChangeKind.modifyDuration }
        XCTAssertFalse(shortens.isEmpty, "Expected heat shorten for long outdoor ride")
        if case .modifyDuration(let payload) = shortens.first?.payload {
            XCTAssertLessThan(payload.proposedDurationMinutes, payload.originalDurationMinutes)
        }
    }
}
