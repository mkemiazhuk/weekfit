import Foundation

enum StressIndexAlcohol: Equatable {
    case beer
    case wine
    case mixed

    /// Matches catalog drinks and free-form planner titles. Water, coffee, tea and
    /// alcohol-free beer never count.
    static func classify(title: String, imageName: String) -> StressIndexAlcohol? {
        let image = imageName.lowercased()
        if image == "ingredient-beer" { return .beer }
        if image == "ingredient-white-wine" || image == "ingredient-red-wine" { return .wine }

        let text = title.lowercased()
        if alcoholFreeMarkers.contains(where: text.contains) { return nil }

        let tokens = text.split { !$0.isLetter }.map(String.init)
        let isBeer = tokens.contains { beerWords.contains($0) || $0.hasSuffix("bier") }
            || cjkBeerWords.contains(where: text.contains)
        let isWine = tokens.contains { wineWords.contains($0) || $0.hasSuffix("wein") }
            || cjkWineWords.contains(where: text.contains)

        switch (isBeer, isWine) {
        case (true, true): return .mixed
        case (true, false): return .beer
        case (false, true): return .wine
        case (false, false): return nil
        }
    }

    static func combine(_ kinds: [StressIndexAlcohol]) -> StressIndexAlcohol? {
        guard let first = kinds.first else { return nil }
        return kinds.allSatisfy { $0 == first } ? first : .mixed
    }

    private static let beerWords: Set<String> = [
        "beer", "lager", "stout", "пиво", "piwo", "bier", "cerveza", "bière", "birra"
    ]
    private static let wineWords: Set<String> = [
        "wine", "вино", "wino", "wein", "vino", "vin"
    ]
    private static let cjkBeerWords = ["ビール", "맥주", "啤酒"]
    private static let cjkWineWords = ["ワイン", "와인", "葡萄酒"]
    private static let alcoholFreeMarkers = [
        "non-alcoholic", "non alcoholic", "alcohol-free", "alcohol free", "0.0",
        "безалкоголь", "bezalkoholow", "alkoholfrei", "sin alcohol", "sans alcool", "analcolic",
        "ノンアルコール", "무알코올", "无醇", "无酒精"
    ]
}

/// A guess about yesterday, shown instead of the usual High meaning. Only for a sharp
/// overnight shift in both resting heart rate and HRV, because people often log
/// neither their workouts nor their drinks.
enum StressIndexMorningHint: Equatable {
    case alcohol(StressIndexAlcohol)
    case alcoholAfterLoad(StressIndexAlcohol)
    case unlogged

    static let restingHeartRateRiseBPM = 4.0
    static let hrvRatioCeiling = 0.85

    static func resolve(
        result: StressIndexResult,
        priorDayLoad: RecoveryPriorDayLoad?,
        alcohol: StressIndexAlcohol?
    ) -> StressIndexMorningHint? {
        guard result.level == .high, hasSharpVitalsShift(result) else { return nil }

        let hadLoad = priorDayLoad.map(isNotableLoad) ?? false
        switch (alcohol, hadLoad) {
        case let (alcohol?, true): return .alcoholAfterLoad(alcohol)
        case let (alcohol?, false): return .alcohol(alcohol)
        case (nil, false): return .unlogged
        case (nil, true): return nil
        }
    }

    /// A walk on its own (Health counts it as a workout) is not a notable load.
    static func isNotableLoad(_ load: RecoveryPriorDayLoad) -> Bool {
        load.exerciseMinutes >= 45 || load.activeCalories >= 450
    }

    private static func hasSharpVitalsShift(_ result: StressIndexResult) -> Bool {
        var rhrRise: Double?
        var hrvRatio: Double?
        for contributor in result.contributors {
            switch contributor.baselineNote {
            case .rhrDeltaBPM(let delta): rhrRise = delta
            case .hrvRatio(let ratio): hrvRatio = ratio
            default: break
            }
        }
        guard let rhrRise, let hrvRatio else { return false }
        return rhrRise >= restingHeartRateRiseBPM && hrvRatio < hrvRatioCeiling
    }

    var text: String {
        switch self {
        case .alcohol(.beer):
            return WeekFitLocalizedString("recovery.stressIndex.morning.beer")
        case .alcohol(.wine):
            return WeekFitLocalizedString("recovery.stressIndex.morning.wine")
        case .alcohol(.mixed):
            return WeekFitLocalizedString("recovery.stressIndex.morning.alcohol")
        case .alcoholAfterLoad(.beer):
            return WeekFitLocalizedString("recovery.stressIndex.morning.beerAfterLoad")
        case .alcoholAfterLoad(.wine):
            return WeekFitLocalizedString("recovery.stressIndex.morning.wineAfterLoad")
        case .alcoholAfterLoad(.mixed):
            return WeekFitLocalizedString("recovery.stressIndex.morning.alcoholAfterLoad")
        case .unlogged:
            return WeekFitLocalizedString("recovery.stressIndex.morning.unlogged")
        }
    }
}
