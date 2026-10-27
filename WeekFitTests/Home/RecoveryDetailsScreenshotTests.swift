import SwiftUI
import XCTest
@testable import WeekFit

@MainActor
final class RecoveryDetailsScreenshotTests: XCTestCase {

    func testRenderRecoveryDetailsLightRussian() throws {
        let previous = WeekFitCurrentAppLanguage()
        WeekFitSetCurrentLanguage(.russian)
        defer { WeekFitSetCurrentLanguage(previous) }

        let night = try makeNight()
        let directory = URL(fileURLWithPath: "/Users/maxk/Dev/WeekFit/.tmp/recovery-redesign", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let topSource = render(
            host(night: night, showsAll: false, appearance: .light),
            height: 900
        )
        let expandedSource = render(
            host(night: night, showsAll: true, appearance: .light),
            height: nil
        )
        let darkSource = render(
            host(night: night, showsAll: false, appearance: .dark),
            height: 900
        )

        let top = try XCTUnwrap(topSource)
        let expanded = try XCTUnwrap(expandedSource)
        try XCTUnwrap(darkSource)

        try write(crop(top, height: 844, fromTop: true), to: directory.appendingPathComponent("top.png"))
        try write(crop(top, height: 844, fromTop: false), to: directory.appendingPathComponent("bottom.png"))
        try write(crop(expanded, height: 980, fromTop: false), to: directory.appendingPathComponent("factors.png"))
        try write(darkSource!, to: directory.appendingPathComponent("dark-top.png"))

        let highlights = RecoveryFactorHighlights.select(
            breakdown: night.snapshot.recoveryBreakdown,
            hasSleep: true
        )
        XCTAssertNotNil(highlights.supporting)
        XCTAssertNotNil(highlights.limiting)
        let explanation = try XCTUnwrap(
            RecoveryFactorCopy.heroExplanation(hasSleep: true, highlights: highlights)
        )
        XCTAssertFalse(explanation.contains("Поздний отбой"))
        XCTAssertTrue(explanation.contains(RecoveryFactorCopy.supportSentence(highlights.supporting!)))
        XCTAssertTrue(explanation.contains(RecoveryFactorCopy.limitSentence(highlights.limiting!)))
    }

    private func host(
        night: RecoveryNightFixture,
        showsAll: Bool,
        appearance: WeekFitAppearance
    ) -> some View {
        RecoveryDetailsSnapshotHost(night: night, showsAllFactors: showsAll)
            .frame(width: 393)
            .background(appearance == .light ? HealthDetailsSoftChrome.canvas : RecoveryStyle.screenBackground)
            .weekFitAppearancePreview(appearance)
            .environment(\.colorScheme, appearance == .light ? .light : .dark)
    }

    private func render<V: View>(_ view: V, height: CGFloat?) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: 393, height: height)
        return renderer.uiImage
    }

    private func crop(_ image: UIImage, height: CGFloat, fromTop: Bool) -> UIImage {
        let scale = image.scale
        let pixelHeight = min(image.size.height, height) * scale
        let y = fromTop ? 0 : max(0, image.size.height * scale - pixelHeight)
        let rect = CGRect(x: 0, y: y, width: image.size.width * scale, height: pixelHeight)
        guard let part = image.cgImage?.cropping(to: rect) else { return image }
        return UIImage(cgImage: part, scale: scale, orientation: image.imageOrientation)
    }

    private func write(_ image: UIImage, to url: URL) throws {
        let data = try XCTUnwrap(image.pngData())
        try data.write(to: url)
    }

    private func makeNight() throws -> RecoveryNightFixture {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 20)))
        let bed = try XCTUnwrap(calendar.date(byAdding: .hour, value: -8, to: day))
        let wake = try XCTUnwrap(calendar.date(byAdding: .minute, value: 430, to: bed))
        let input = RecoveryScoreInput(
            sleepMinutes: 430,
            timeInBedMinutes: 470,
            awakeMinutes: 22,
            awakeningsCount: 2,
            deepSleepMinutes: 78,
            remSleepMinutes: 96,
            hrvSDNN: 42,
            restingHeartRate: 54,
            bedtimeDeviationMinutes: 95,
            baseline: RecoveryPhysiologyBaseline(
                hrvMedian: 68,
                hrvSampleCount: 14,
                restingHeartRateMedian: 52,
                restingHeartRateSampleCount: 14,
                windowDays: 21
            ),
            priorDayLoad: RecoveryPriorDayLoad(exerciseMinutes: 30, activeCalories: 220, workoutCount: 1)
        )
        let breakdown = RecoveryScoreEngine.calculate(input)
        let stress = StressIndexEngine.calculate(input, at: day)
        let base = RecoveryDaySnapshot(
            date: day,
            recoveryScore: 0,
            recoveryBreakdown: .empty,
            sleepScore: 0,
            timeInBedMinutes: input.timeInBedMinutes,
            asleepMinutes: input.sleepMinutes,
            awakeMinutes: input.awakeMinutes,
            deepSleepMinutes: input.deepSleepMinutes,
            remSleepMinutes: input.remSleepMinutes,
            coreSleepMinutes: 256,
            bedStart: bed,
            wakeTime: wake,
            awakeningsCount: input.awakeningsCount,
            restingHeartRate: input.restingHeartRate,
            hrv: input.hrvSDNN,
            recoveryInput: nil,
            insightTitle: "",
            insightText: "",
            actionTitle: "",
            actionText: ""
        )
        return RecoveryNightFixture(
            date: day,
            snapshot: base.withRecovery(score: breakdown.total, breakdown: breakdown, input: input),
            stress: stress
        )
    }
}

struct RecoveryNightFixture {
    let date: Date
    let snapshot: RecoveryDaySnapshot
    let stress: StressIndexResult
}

private struct RecoveryDetailsSnapshotHost: View {
    let night: RecoveryNightFixture
    let showsAllFactors: Bool
    @State private var date: Date
    @State private var showsAll: Bool

    init(night: RecoveryNightFixture, showsAllFactors: Bool) {
        self.night = night
        self.showsAllFactors = showsAllFactors
        _date = State(initialValue: night.date)
        _showsAll = State(initialValue: showsAllFactors)
    }

    var body: some View {
        RecoveryDetailsPage(
            activeDate: $date,
            snapshot: night.snapshot,
            stressIndex: night.stress,
            showsAllFactors: $showsAll,
            onClose: {},
            onOpenStress: {}
        )
    }
}
