import SwiftUI

enum PlateLayoutMode {
    case detail
    case builder
    case preview
    case compactPreview
}

enum PlateIngredientCategory: String, CaseIterable {
    case base
    case protein
    case vegetables
    case fat
    case sauce
    case extras
    case garnish
    case other

    var rank: Int {
        switch self {
        case .base: return 0
        case .vegetables: return 1
        case .protein: return 2
        case .fat: return 3
        case .sauce: return 4
        case .extras: return 5
        case .garnish: return 6
        case .other: return 7
        }
    }

    var layerBase: Double {
        switch self {
        case .base: return 10
        case .vegetables: return 20
        case .protein: return 30
        case .fat, .sauce, .extras, .garnish: return 40
        case .other: return 25
        }
    }
}

struct PlateLayoutItem: Identifiable, Equatable {
    let item: MealBuilderImageItem
    let category: PlateIngredientCategory
    let sourceIndex: Int
    let offset: CGSize
    let width: CGFloat
    let rotation: Double
    let zIndex: Double

    var id: String { item.id }
}

enum PlateLayoutEngine {

    static func category(for item: MealBuilderImageItem) -> PlateIngredientCategory {
        let id = item.id.lowercased()

        if id.hasPrefix("base_") { return .base }
        if id.hasPrefix("protein_") { return .protein }
        if id.hasPrefix("veg_") || id.hasPrefix("vegetable_") { return .vegetables }
        if id.hasPrefix("fat_") { return .fat }
        if id.hasPrefix("sauce_") { return .sauce }
        if id.hasPrefix("garnish_") { return .garnish }
        if id.hasPrefix("extra_") {
            if isPourableExtra(id) { return .sauce }
            if isCrownGarnish(id) { return .garnish }
            return .extras
        }

        return .other
    }

    /// Oils, sauces, syrups — sit on the rim, not as a top garnish pile.
    private static func isPourableExtra(_ id: String) -> Bool {
        let tokens = [
            "oil", "sauce", "butter", "honey", "maple", "miso",
            "tahini", "soy", "sour_cream", "coconut_milk"
        ]
        return tokens.contains { id.contains($0) }
    }

    /// Fruit / seed toppings that crown the plate.
    private static func isCrownGarnish(_ id: String) -> Bool {
        let tokens = [
            "blueberr", "strawberr", "raspberr", "pomegranate", "chia",
            "sesame_seed", "almond", "walnut", "cashew", "pistachio",
            "mango", "pineapple", "date", "apple", "banana"
        ]
        return tokens.contains { id.contains($0) }
    }

    static func layout(
        items: [MealBuilderImageItem],
        plateSize: CGFloat,
        itemScale: CGFloat,
        offsetScale: CGFloat,
        mode: PlateLayoutMode = .detail
    ) -> [PlateLayoutItem] {
        let metrics = LayoutMetrics(mode: mode, plateSize: plateSize)
        let candidates = items.enumerated().map { index, item in
            Candidate(
                item: item,
                category: category(for: item),
                sourceIndex: index
            )
        }

        let sortedCandidates = candidates.sorted { lhs, rhs in
            if lhs.category.rank != rhs.category.rank {
                return lhs.category.rank < rhs.category.rank
            }

            if lhs.sourceIndex != rhs.sourceIndex {
                return lhs.sourceIndex < rhs.sourceIndex
            }

            return lhs.item.id < rhs.item.id
        }

        let categoryCounts = Dictionary(grouping: sortedCandidates, by: \.category)
            .mapValues(\.count)
        let composition = CompositionSignature(categories: Set(sortedCandidates.map(\.category)))
        let compositionSlots = compositionSlots(
            for: composition,
            totalCount: sortedCandidates.count
        )
        var categorySeen: [PlateIngredientCategory: Int] = [:]
        var placed: [PlacedCandidate] = []

        for candidate in sortedCandidates {
            let categoryIndex = categorySeen[candidate.category, default: 0]
            categorySeen[candidate.category] = categoryIndex + 1

            let categoryCount = categoryCounts[candidate.category, default: 1]
            var placedCandidate = PlacedCandidate(
                candidate: candidate,
                categoryIndex: categoryIndex,
                categoryCount: categoryCount,
                offset: initialOffset(
                    for: candidate,
                    categoryIndex: categoryIndex,
                    categoryCount: categoryCount,
                    totalCount: sortedCandidates.count,
                    offsetScale: offsetScale,
                    compositionSlots: compositionSlots,
                    metrics: metrics
                ),
                width: itemWidth(
                    for: candidate.item,
                    category: candidate.category,
                    totalCount: sortedCandidates.count,
                    categoryCount: categoryCount,
                    itemScale: itemScale,
                    plateSize: plateSize,
                    metrics: metrics
                ),
                rotation: itemRotation(
                    for: candidate,
                    categoryIndex: categoryIndex,
                    categoryCount: categoryCount,
                    totalCount: sortedCandidates.count,
                    metrics: metrics
                )
            )

            keepInsidePlate(&placedCandidate, plateSize: plateSize, metrics: metrics)
            resolveCollisions(for: &placedCandidate, against: placed, plateSize: plateSize, metrics: metrics)
            keepInsidePlate(&placedCandidate, plateSize: plateSize, metrics: metrics)

            placed.append(placedCandidate)
        }

        if metrics.shouldCenterGroup {
            centerPlacedItems(&placed, plateSize: plateSize, metrics: metrics)
        }

        return placed
            .map { placedCandidate in
                PlateLayoutItem(
                    item: placedCandidate.candidate.item,
                    category: placedCandidate.candidate.category,
                    sourceIndex: placedCandidate.candidate.sourceIndex,
                    offset: placedCandidate.offset,
                    width: placedCandidate.width,
                    rotation: placedCandidate.rotation,
                    zIndex: zIndex(for: placedCandidate)
                )
            }
            .sorted { lhs, rhs in
                if lhs.zIndex != rhs.zIndex {
                    return lhs.zIndex < rhs.zIndex
                }

                if lhs.category.rank != rhs.category.rank {
                    return lhs.category.rank < rhs.category.rank
                }

                if lhs.sourceIndex != rhs.sourceIndex {
                    return lhs.sourceIndex < rhs.sourceIndex
                }

                return lhs.item.id < rhs.item.id
            }
    }

    static func layoutItem(
        matching itemID: String,
        in items: [MealBuilderImageItem],
        plateSize: CGFloat,
        itemScale: CGFloat,
        offsetScale: CGFloat,
        mode: PlateLayoutMode = .detail
    ) -> PlateLayoutItem? {
        layout(
            items: items,
            plateSize: plateSize,
            itemScale: itemScale,
            offsetScale: offsetScale,
            mode: mode
        )
        .first { $0.item.id == itemID }
    }

    private static func itemWidth(
        for item: MealBuilderImageItem,
        category: PlateIngredientCategory,
        totalCount: Int,
        categoryCount: Int,
        itemScale: CGFloat,
        plateSize: CGFloat,
        metrics: LayoutMetrics
    ) -> CGFloat {
        let baseWidth = CGFloat(item.visualSize) * 1.12 * itemScale
        let ratio = CGFloat(item.grams) / 100
        let normalized = log2(max(ratio, 0.45))
        let isStandalone = totalCount == 1

        let gramScale: CGFloat
        if isStandalone, item.supportsStandalonePresentation {
            gramScale = standaloneScale(for: category, normalized: normalized, density: item.visualDensity)
        } else {
            gramScale = min(
                max(0.94 + normalized * item.visualDensity * 0.14, 0.78),
                1.34
            )
        }

        let countScale = itemCountScale(
            totalCount: totalCount,
            categoryCount: categoryCount,
            metrics: metrics
        )

        let categoryScale = itemCategoryScale(
            category: category,
            totalCount: totalCount,
            categoryCount: categoryCount,
            metrics: metrics
        )

        let resolvedWidth = baseWidth * gramScale * countScale * categoryScale * metrics.itemScaleMultiplier
        return min(resolvedWidth, plateSize * metrics.maxItemWidthRatio)
    }

    private static func standaloneScale(
        for category: PlateIngredientCategory,
        normalized: CGFloat,
        density: CGFloat
    ) -> CGFloat {
        let baseScale: CGFloat
        let maxScale: CGFloat

        switch category {
        case .base:
            baseScale = 0.92
            maxScale = 1.08
        case .protein:
            baseScale = 1.00
            maxScale = 1.14
        case .vegetables:
            baseScale = 1.06
            maxScale = 1.20
        default:
            baseScale = 1.10
            maxScale = 1.24
        }

        let scaled = baseScale + normalized * density * 0.10
        return min(max(scaled, 0.78), maxScale)
    }

    private static func initialOffset(
        for candidate: Candidate,
        categoryIndex: Int,
        categoryCount: Int,
        totalCount: Int,
        offsetScale: CGFloat,
        compositionSlots: [PlateIngredientCategory: [CGSize]],
        metrics: LayoutMetrics
    ) -> CGSize {
        guard totalCount > 1 || !candidate.item.supportsStandalonePresentation else {
            return CGSize(width: 0, height: metrics.standaloneYOffset)
        }

        if metrics.isCompact {
            let slot = slotOffset(
                for: candidate.category,
                index: categoryIndex,
                count: categoryCount,
                totalCount: totalCount,
                compositionSlots: compositionSlots,
                metrics: metrics
            )
            let spreadScale = compactSpreadScale(totalCount: totalCount)
            return CGSize(
                width: slot.width * spreadScale,
                height: slot.height * spreadScale
            )
        }

        let slot = slotOffset(
            for: candidate.category,
            index: categoryIndex,
            count: categoryCount,
            totalCount: totalCount,
            compositionSlots: compositionSlots,
            metrics: metrics
        )

        let legacy = legacyOffset(for: candidate.item, offsetScale: offsetScale, metrics: metrics)
        let legacyWeight: CGFloat = metrics.legacyWeight(totalCount: totalCount)
        let zoneWeight: CGFloat = 1 - legacyWeight

        return CGSize(
            width: (slot.width * zoneWeight + legacy.width * legacyWeight) * metrics.offsetCenteringMultiplier,
            height: (slot.height * zoneWeight + legacy.height * legacyWeight) * metrics.offsetCenteringMultiplier
        )
    }

    private static func legacyOffset(
        for item: MealBuilderImageItem,
        offsetScale: CGFloat,
        metrics: LayoutMetrics
    ) -> CGSize {
        var x = CGFloat(item.offsetX) * offsetScale * metrics.legacyOffsetMultiplier
        var y = (CGFloat(item.offsetY) * offsetScale - 2) * metrics.legacyOffsetMultiplier

        if item.offsetY < -20 {
            x *= 0.72
            y += 10 * metrics.legacyOffsetMultiplier
        }

        return CGSize(width: x, height: y)
    }

    private static func compactSpreadScale(totalCount: Int) -> CGFloat {
        switch totalCount {
        case 0...2:
            return 0.52
        case 3...4:
            return 0.64
        case 5...6:
            return 0.72
        default:
            return 0.78
        }
    }

    private static func slotOffset(
        for category: PlateIngredientCategory,
        index: Int,
        count: Int,
        totalCount: Int,
        compositionSlots: [PlateIngredientCategory: [CGSize]],
        metrics: LayoutMetrics
    ) -> CGSize {
        let slots = compositionSlots[category] ?? slots(for: category, totalCount: totalCount)
        let base = slots[index % slots.count]
        let ring = index / slots.count
        let spread = min(CGFloat(max(count - 1, 0)) * metrics.spreadMultiplier, metrics.maxSpread)
        let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1

        return CGSize(
            width: (base.width + direction * CGFloat(ring) * metrics.ringStep + spread * direction * 0.5) * metrics.slotScale,
            height: (base.height + CGFloat(ring) * metrics.ringStep * 0.8) * metrics.slotScale
        )
    }

    /// Combination-aware anchors — denser, more “plated” than independent category fans.
    private static func compositionSlots(
        for signature: CompositionSignature,
        totalCount: Int
    ) -> [PlateIngredientCategory: [CGSize]] {
        switch signature.kind {
        case .breakfastBowl:
            // Base anchors the well; protein rests against it; crown garnish nests on top.
            return [
                .base: [CGSize(width: -8, height: 18)],
                .protein: [CGSize(width: 24, height: 4)],
                .garnish: [CGSize(width: 2, height: -34)],
                .extras: [CGSize(width: 18, height: -28)],
                .sauce: [CGSize(width: 40, height: 22)],
            ]

        case .proteinBowl:
            // Classic lunch bowl — base rear-left, protein front-right, veg crown-left.
            return [
                .base: [CGSize(width: -10, height: 16)],
                .protein: [CGSize(width: 26, height: 2)],
                .vegetables: [
                    CGSize(width: -26, height: -30),
                    CGSize(width: 8, height: -38),
                    CGSize(width: 34, height: -22),
                ],
                .sauce: [CGSize(width: 42, height: 20)],
                .extras: [CGSize(width: 14, height: -42)],
                .garnish: [CGSize(width: 6, height: -44)],
                .fat: [CGSize(width: -40, height: 18)],
            ]

        case .duo:
            return [
                .base: [CGSize(width: -16, height: 12)],
                .protein: [CGSize(width: 18, height: 2)],
                .vegetables: [CGSize(width: -12, height: -18)],
                .extras: [CGSize(width: 16, height: -22)],
                .garnish: [CGSize(width: 10, height: -26)],
                .sauce: [CGSize(width: 36, height: 16)],
            ]

        case .loaded:
            return [
                .base: [CGSize(width: -6, height: 18)],
                .protein: [CGSize(width: 28, height: 0)],
                .vegetables: [
                    CGSize(width: -30, height: -26),
                    CGSize(width: 4, height: -40),
                    CGSize(width: 36, height: -18),
                ],
                .extras: [
                    CGSize(width: 16, height: -36),
                    CGSize(width: -38, height: 6),
                ],
                .garnish: [CGSize(width: 0, height: -46)],
                .sauce: [
                    CGSize(width: 44, height: 18),
                    CGSize(width: -42, height: 22),
                ],
                .fat: [CGSize(width: 40, height: -6)],
            ]

        case .generic:
            return [:]
        }
    }

    private static func slots(
        for category: PlateIngredientCategory,
        totalCount: Int
    ) -> [CGSize] {
        let wide = totalCount >= 5

        switch category {
        case .base:
            return [
                CGSize(width: -10, height: 18),
                CGSize(width: 6, height: 24),
                CGSize(width: -28, height: 8)
            ]
        case .protein:
            return [
                CGSize(width: 26, height: 4),
                CGSize(width: 18, height: 24),
                CGSize(width: 40, height: -8),
                CGSize(width: 2, height: 16)
            ]
        case .vegetables:
            return wide
                ? [
                    CGSize(width: -28, height: -32),
                    CGSize(width: 2, height: -42),
                    CGSize(width: 30, height: -28),
                    CGSize(width: -42, height: -6),
                    CGSize(width: 16, height: -14)
                ]
                : [
                    CGSize(width: -24, height: -32),
                    CGSize(width: 8, height: -40),
                    CGSize(width: 32, height: -24),
                    CGSize(width: -36, height: -10)
                ]
        case .sauce, .fat:
            return [
                CGSize(width: 44, height: 20),
                CGSize(width: -44, height: 18),
                CGSize(width: 38, height: -4),
                CGSize(width: -36, height: 28)
            ]
        case .extras, .garnish:
            return [
                CGSize(width: 8, height: -38),
                CGSize(width: 30, height: -26),
                CGSize(width: -16, height: -36),
                CGSize(width: 42, height: 2),
                CGSize(width: -34, height: 4)
            ]
        case .other:
            return [
                CGSize(width: 0, height: -8),
                CGSize(width: 22, height: 14),
                CGSize(width: -22, height: 10),
                CGSize(width: 10, height: -28)
            ]
        }
    }

    private static func itemRotation(
        for candidate: Candidate,
        categoryIndex: Int,
        categoryCount: Int,
        totalCount: Int,
        metrics: LayoutMetrics
    ) -> Double {
        guard totalCount > 1 || !candidate.item.supportsStandalonePresentation else {
            return 0
        }

        let base = Double(candidate.item.rotation)
        let spread = Double((categoryIndex % 3) - 1) * 3.0 * Double(metrics.rotationMultiplier)
        let categoryAdjustment: Double

        switch candidate.category {
        case .base:
            categoryAdjustment = min(max(base, -8), 8)
        case .protein:
            categoryAdjustment = base + spread
        case .vegetables:
            categoryAdjustment = base + spread * 1.2
        case .fat, .sauce, .extras, .garnish:
            categoryAdjustment = base + spread * 0.8
        case .other:
            categoryAdjustment = base
        }

        return min(max(categoryAdjustment, -metrics.maxRotation), metrics.maxRotation)
    }

    private static func resolveCollisions(
        for candidate: inout PlacedCandidate,
        against placed: [PlacedCandidate],
        plateSize: CGFloat,
        metrics: LayoutMetrics
    ) {
        guard !placed.isEmpty else { return }

        for _ in 0..<metrics.collisionIterations {
            var didMove = false

            for other in placed {
                let dx = candidate.offset.width - other.offset.width
                let dy = candidate.offset.height - other.offset.height
                let distance = max(sqrt(dx * dx + dy * dy), 0.1)
                let sameCategory = candidate.candidate.category == other.candidate.category
                let spacingMultiplier = sameCategory ? metrics.sameCategorySpacing : metrics.crossCategorySpacing
                let minimumDistance = (candidate.radius + other.radius) * spacingMultiplier

                guard distance < minimumDistance else { continue }

                let overlap = minimumDistance - distance
                let direction = pushDirection(
                    for: candidate,
                    awayFrom: other,
                    dx: dx,
                    dy: dy,
                    distance: distance
                )
                let maxPush = sameCategory ? metrics.sameCategoryMaxPush : metrics.crossCategoryMaxPush
                let push = min(overlap * metrics.collisionPushMultiplier, maxPush)

                candidate.offset.width += direction.width * push
                candidate.offset.height += direction.height * push
                keepInsidePlate(&candidate, plateSize: plateSize, metrics: metrics)
                didMove = true
            }

            if !didMove { break }
        }
    }

    private static func itemCategoryScale(
        category: PlateIngredientCategory,
        totalCount: Int,
        categoryCount: Int,
        metrics: LayoutMetrics
    ) -> CGFloat {
        if metrics.isCompact {
            switch category {
            case .base:
                return totalCount >= 5 ? 1.00 : 1.06
            case .protein:
                return totalCount >= 5 ? 0.98 : 1.04
            case .vegetables:
                if totalCount >= 5 { return categoryCount >= 3 ? 0.78 : 0.86 }
                return categoryCount >= 3 ? 0.90 : 0.96
            case .fat, .sauce, .extras, .garnish:
                return totalCount >= 5 ? 0.70 : 0.84
            case .other:
                return totalCount >= 5 ? 0.86 : 0.96
            }
        }

        switch category {
        case .base:
            return totalCount >= 5 ? 0.96 : 1.0
        case .fat, .sauce, .extras, .garnish:
            return totalCount >= 5 ? 0.94 : 1.0
        case .vegetables where categoryCount >= 3:
            return 0.94
        default:
            return 1.0
        }
    }

    private static func itemCountScale(
        totalCount: Int,
        categoryCount: Int,
        metrics: LayoutMetrics
    ) -> CGFloat {
        if metrics.isCompact {
            switch totalCount {
            case 0...1:
                return 1.0
            case 2...4:
                return categoryCount >= 3 ? 1.00 : 1.06
            case 5...7:
                return categoryCount >= 3 ? 0.92 : 0.97
            default:
                return categoryCount >= 3 ? 0.84 : 0.90
            }
        }

        switch totalCount {
        case 0...1:
            return 1.0
        case 2...4:
            return categoryCount >= 3 ? 0.96 : 1.0
        case 5...7:
            return categoryCount >= 3 ? 0.86 : 0.90
        default:
            return categoryCount >= 3 ? 0.76 : 0.82
        }
    }

    private static func centerPlacedItems(
        _ placed: inout [PlacedCandidate],
        plateSize: CGFloat,
        metrics: LayoutMetrics
    ) {
        guard !placed.isEmpty else { return }

        let bounds = visualBounds(for: placed)
        let centerX = (bounds.minX + bounds.maxX) / 2
        let centerY = (bounds.minY + bounds.maxY) / 2
        let correctionX = min(max(-centerX * metrics.groupCenteringStrength, -metrics.maxGroupCorrection), metrics.maxGroupCorrection)
        let correctionY = min(max(-centerY * metrics.groupCenteringStrength, -metrics.maxGroupCorrection), metrics.maxGroupCorrection)

        guard abs(correctionX) > 0.5 || abs(correctionY) > 0.5 else { return }

        for index in placed.indices {
            placed[index].offset.width += correctionX
            placed[index].offset.height += correctionY
            keepInsidePlate(&placed[index], plateSize: plateSize, metrics: metrics)
        }
    }

    private static func visualBounds(for placed: [PlacedCandidate]) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for item in placed {
            let halfWidth = item.width * 0.48
            let halfHeight = item.width * 0.36

            minX = min(minX, item.offset.width - halfWidth)
            maxX = max(maxX, item.offset.width + halfWidth)
            minY = min(minY, item.offset.height - halfHeight)
            maxY = max(maxY, item.offset.height + halfHeight)
        }

        return (minX, maxX, minY, maxY)
    }

    private static func pushDirection(
        for candidate: PlacedCandidate,
        awayFrom other: PlacedCandidate,
        dx: CGFloat,
        dy: CGFloat,
        distance: CGFloat
    ) -> CGSize {
        if distance > 0.5 {
            return CGSize(width: dx / distance, height: dy / distance)
        }

        let seed = stableSeed(candidate.candidate.item.id + other.candidate.item.id)
        let angle = CGFloat(seed % 360) * .pi / 180
        return CGSize(width: cos(angle), height: sin(angle))
    }

    private static func keepInsidePlate(
        _ candidate: inout PlacedCandidate,
        plateSize: CGFloat,
        metrics: LayoutMetrics
    ) {
        let horizontalRadius = plateSize * metrics.horizontalRadiusRatio
        let verticalRadius = plateSize * metrics.verticalRadiusRatio
        let safePadding = max(candidate.radius * metrics.safeRadiusPaddingMultiplier, metrics.minimumSafePadding)
        let maxX = max(horizontalRadius - safePadding, 8)
        let maxY = max(verticalRadius - safePadding, 8)

        let normalized = sqrt(
            pow(candidate.offset.width / maxX, 2) +
            pow(candidate.offset.height / maxY, 2)
        )

        guard normalized > 1 else { return }

        candidate.offset.width /= normalized
        candidate.offset.height /= normalized
    }

    private static func zIndex(for candidate: PlacedCandidate) -> Double {
        let originalHint = Double(candidate.candidate.item.zIndex) * 0.01
        let verticalHint = Double((candidate.offset.height + 80) / 400)
        let orderHint = Double(candidate.candidate.sourceIndex) * 0.001

        return candidate.candidate.category.layerBase + verticalHint + originalHint + orderHint
    }

    private static func stableSeed(_ value: String) -> Int {
        value.unicodeScalars.reduce(0) { partial, scalar in
            ((partial &* 31) &+ Int(scalar.value)) & 0x7fffffff
        }
    }
}

private struct Candidate {
    let item: MealBuilderImageItem
    let category: PlateIngredientCategory
    let sourceIndex: Int
}

private struct PlacedCandidate {
    let candidate: Candidate
    let categoryIndex: Int
    let categoryCount: Int
    var offset: CGSize
    var width: CGFloat
    var rotation: Double

    var radius: CGFloat {
        width * 0.42
    }
}

private struct LayoutMetrics {
    let mode: PlateLayoutMode
    let plateSize: CGFloat

    var isCompact: Bool {
        mode == .compactPreview
    }

    var slotScale: CGFloat {
        switch mode {
        case .compactPreview:
            return min(max(plateSize / 200, 0.24), 0.46)
        case .preview:
            return 0.72
        case .detail, .builder:
            return 1.0
        }
    }

    var legacyOffsetMultiplier: CGFloat {
        switch mode {
        case .compactPreview:
            return min(max(plateSize / 180, 0.34), 0.55)
        case .preview:
            return 0.84
        case .detail, .builder:
            return 1.0
        }
    }

    var itemScaleMultiplier: CGFloat {
        switch mode {
        case .compactPreview:
            return 0.96
        case .preview:
            return 0.96
        case .detail, .builder:
            return 1.0
        }
    }

    var maxItemWidthRatio: CGFloat {
        switch mode {
        case .compactPreview:
            return 0.40
        case .preview:
            return 0.48
        case .detail, .builder:
            return 0.62
        }
    }

    var horizontalRadiusRatio: CGFloat {
        switch mode {
        case .compactPreview:
            return 0.24
        case .preview:
            return 0.33
        case .detail, .builder:
            return 0.36
        }
    }

    var verticalRadiusRatio: CGFloat {
        switch mode {
        case .compactPreview:
            return 0.20
        case .preview:
            return 0.28
        case .detail, .builder:
            return 0.30
        }
    }

    var safeRadiusPaddingMultiplier: CGFloat {
        switch mode {
        case .compactPreview:
            return 0.34
        case .preview:
            return 0.28
        case .detail, .builder:
            return 0.24
        }
    }

    var minimumSafePadding: CGFloat {
        switch mode {
        case .compactPreview:
            return 3
        case .preview:
            return 5
        case .detail, .builder:
            return 8
        }
    }

    var spreadMultiplier: CGFloat {
        switch mode {
        case .compactPreview:
            return 0.20
        case .preview:
            return 1.0
        case .detail, .builder:
            return 1.5
        }
    }

    var maxSpread: CGFloat {
        switch mode {
        case .compactPreview:
            return 0.65
        case .preview:
            return 4.5
        case .detail, .builder:
            return 7
        }
    }

    var ringStep: CGFloat {
        switch mode {
        case .compactPreview:
            return 0.75
        case .preview:
            return 3.5
        case .detail, .builder:
            return 5
        }
    }

    var rotationMultiplier: CGFloat {
        switch mode {
        case .compactPreview:
            return 0.45
        case .preview:
            return 0.75
        case .detail, .builder:
            return 1.0
        }
    }

    var maxRotation: Double {
        switch mode {
        case .compactPreview:
            return 4
        case .preview:
            return 11
        case .detail, .builder:
            return 14
        }
    }

    var collisionIterations: Int {
        switch mode {
        case .compactPreview:
            return 2
        case .preview:
            return 2
        case .detail, .builder:
            return 3
        }
    }

    var sameCategorySpacing: CGFloat {
        switch mode {
        case .compactPreview:
            return 0.08
        case .preview:
            return 0.40
        case .detail, .builder:
            return 0.48
        }
    }

    var crossCategorySpacing: CGFloat {
        switch mode {
        case .compactPreview:
            return 0.10
        case .preview:
            return 0.26
        case .detail, .builder:
            // Allow gentle nesting so bowls read as one composition.
            return 0.28
        }
    }

    var sameCategoryMaxPush: CGFloat {
        switch mode {
        case .compactPreview:
            return 0.35
        case .preview:
            return 5
        case .detail, .builder:
            return 10
        }
    }

    var crossCategoryMaxPush: CGFloat {
        switch mode {
        case .compactPreview:
            return 0.25
        case .preview:
            return 3.5
        case .detail, .builder:
            return 6
        }
    }

    var collisionPushMultiplier: CGFloat {
        switch mode {
        case .compactPreview:
            return 0.10
        case .preview:
            return 0.40
        case .detail, .builder:
            return 0.56
        }
    }

    var standaloneYOffset: CGFloat {
        switch mode {
        case .compactPreview:
            return 0
        case .preview:
            return -2
        case .detail, .builder:
            return -4
        }
    }

    func legacyWeight(totalCount: Int) -> CGFloat {
        switch mode {
        case .compactPreview:
            return totalCount <= 4 ? 0.10 : 0.06
        case .preview:
            return totalCount <= 4 ? 0.16 : 0.10
        case .detail, .builder:
            // Prefer composition templates over per-ingredient demo offsets.
            return totalCount <= 4 ? 0.10 : 0.06
        }
    }

    var offsetCenteringMultiplier: CGFloat {
        switch mode {
        case .compactPreview:
            return 0.90
        case .preview:
            return 0.96
        case .detail, .builder:
            return 1.0
        }
    }

    var shouldCenterGroup: Bool {
        switch mode {
        case .compactPreview, .detail, .builder:
            return true
        case .preview:
            return true
        }
    }

    var groupCenteringStrength: CGFloat {
        switch mode {
        case .compactPreview:
            return 0.48
        case .preview:
            return 0.28
        case .detail, .builder:
            return 0.32
        }
    }

    var maxGroupCorrection: CGFloat {
        switch mode {
        case .compactPreview:
            return max(2, plateSize * 0.18)
        case .preview:
            return max(4, plateSize * 0.05)
        case .detail, .builder:
            return max(6, plateSize * 0.06)
        }
    }
}

/// Detects plated combination patterns so slots nest like a real composed meal.
private struct CompositionSignature {
    enum Kind {
        case breakfastBowl
        case proteinBowl
        case duo
        case loaded
        case generic
    }

    let kind: Kind

    init(categories: Set<PlateIngredientCategory>) {
        let hasBase = categories.contains(.base)
        let hasProtein = categories.contains(.protein)
        let hasVeg = categories.contains(.vegetables)
        let hasCrown = categories.contains(.garnish) || categories.contains(.extras)
        let hasSauce = categories.contains(.sauce) || categories.contains(.fat)
        let count = categories.count

        if hasBase && hasProtein && hasCrown && !hasVeg && count <= 4 {
            kind = .breakfastBowl
        } else if hasBase && hasProtein && hasVeg {
            kind = count >= 4 || hasSauce || hasCrown ? .loaded : .proteinBowl
        } else if count == 2 {
            kind = .duo
        } else if count >= 4 {
            kind = .loaded
        } else if hasBase && hasProtein {
            kind = .proteinBowl
        } else {
            kind = .generic
        }
    }
}
