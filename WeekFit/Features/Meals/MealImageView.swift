import SwiftUI
import UIKit

enum FoodMediaPresentation {
    case thumbnail(size: CGFloat)
    case hero(size: CGFloat)
}

enum FoodMediaShape {
    case circle
    case roundedRectangle(cornerRadius: CGFloat)
}

struct CustomFoodVisualView: View {
    let image: UIImage?
    var placeholderInitial: String
    var size: CGFloat
    var imageScale: CGFloat = 0.68
    var fallbackSystemImage: String = "fork.knife"

    var body: some View {
        MealAvatarView(
            image: image,
            placeholderInitial: placeholderInitial,
            size: size,
            imageScale: imageScale,
            fallbackSystemImage: fallbackSystemImage
        )
    }
}

struct AsyncMealPhotoView<Content: View>: View {
    let filename: String?
    var targetPixelSize: CGFloat
    let content: (UIImage?) -> Content

    @State private var loadedImage: UIImage?

    init(
        filename: String?,
        targetPixelSize: CGFloat = MealPhotoStore.thumbnailPixelSize,
        @ViewBuilder content: @escaping (UIImage?) -> Content
    ) {
        self.filename = filename
        self.targetPixelSize = targetPixelSize
        self.content = content
    }

    private var resolvedFilename: String {
        filename ?? ""
    }

    var body: some View {
        content(loadedImage)
        .onAppear {
            loadImageIfNeeded()
        }
        .onChange(of: resolvedFilename) { _ in
            loadedImage = nil
            loadImageIfNeeded()
        }
    }

    private func loadImageIfNeeded() {
        guard !resolvedFilename.isEmpty else {
            loadedImage = nil
            return
        }

        let requestedFilename = resolvedFilename
        MealPhotoStore.loadImage(for: requestedFilename, targetPixelSize: targetPixelSize) { image in
            guard requestedFilename == resolvedFilename else { return }
            loadedImage = image
        }
    }
}

struct AsyncCustomFoodVisualView: View {
    let filename: String?
    var placeholderInitial: String
    var size: CGFloat
    var imageScale: CGFloat = 0.68
    var fallbackSystemImage: String = "fork.knife"

    var body: some View {
        AsyncMealPhotoView(filename: filename) { image in
            CustomFoodVisualView(
                image: image,
                placeholderInitial: placeholderInitial,
                size: size,
                imageScale: imageScale,
                fallbackSystemImage: fallbackSystemImage
            )
        }
    }
}

struct MealAvatarView: View {
    let image: UIImage?
    var placeholderInitial: String
    var size: CGFloat
    var imageScale: CGFloat = 0.68
    var fallbackSystemImage: String = "fork.knife"

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            WeekFitTheme.elevatedCard.opacity(0.96),
                            WeekFitTheme.cardBackground.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
        }
        .shadow(
            color: WeekFitTheme.cardShadow.opacity(0.50),
            radius: max(6, size * 0.13),
            y: max(3, size * 0.06)
        )
    }

    private var fallback: some View {
        ZStack {
            if !placeholderInitial.isEmpty {
                Text(placeholderInitial)
                    .font(
                        .system(
                            size: max(16, size * 0.30),
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(textPrimary.opacity(0.90))
                    .offset(x: -size * 0.10)
            } else {
                Image(systemName: fallbackSystemImage)
                    .font(
                        .system(
                            size: max(15, size * 0.26),
                            weight: .bold
                        )
                    )
                    .foregroundStyle(textSecondary.opacity(0.84))
                    .offset(x: -size * 0.04)
            }
        }
        .frame(width: size * 0.60, height: size * 0.60)
    }
}

struct FoodMediaView: View {
    let meal: Meals
    var presentation: FoodMediaPresentation
    var forceCircleForLocalPhoto = false

    private let accent = WeekFitTheme.meal
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText

    var body: some View {
        if meal.isFoodProduct || forceCircleForLocalPhoto {
            switch presentation {
            case .thumbnail(let size):
                AsyncCustomFoodVisualView(
                    filename: meal.displayPhotoFilename,
                    placeholderInitial: meal.placeholderInitial,
                    size: size,
                    imageScale: 0.68
                )

            case .hero(let size):
                AsyncCustomFoodVisualView(
                    filename: meal.displayPhotoFilename,
                    placeholderInitial: meal.placeholderInitial,
                    size: size * 0.85,
                    imageScale: 0.66
                )
            }
        } else {
            switch presentation {
            case .thumbnail(let size):
                media(size: size, isHero: false)

            case .hero(let size):
                media(size: size * 0.85, isHero: true)
            }
        }
    }

    private func media(size: CGFloat, isHero: Bool) -> some View {
        ZStack {
            background(size: size, isHero: isHero)

            resolvedMedia(size: size, isHero: isHero)
                .frame(width: size, height: size)
                .clipShape(mediaShapePath(size: size, isHero: isHero))
        }
        .frame(width: size, height: size)
        .overlay {
            mediaShapePath(size: size, isHero: isHero)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isHero ? 0.12 : 0.09),
                            accent.opacity(isHero ? 0.10 : 0.07),
                            Color.white.opacity(0.030)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isHero ? 1.1 : 1
                )
        }
        .shadow(
            color: Color.black.opacity(isHero ? 0.24 : 0.16),
            radius: isHero ? 14 : 8,
            y: isHero ? 8 : 4
        )
        .shadow(
            color: accent.opacity(isHero ? 0.035 : 0.02),
            radius: isHero ? 10 : 6,
            y: isHero ? 4 : 2
        )
    }

    @ViewBuilder
    private func background(size: CGFloat, isHero: Bool) -> some View {
        mediaShapePath(size: size, isHero: isHero)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(isHero ? 0.10 : 0.07),
                        WeekFitTheme.cardBackground.opacity(0.96),
                        Color.black.opacity(isHero ? 0.22 : 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    @ViewBuilder
    private func resolvedMedia(size: CGFloat, isHero: Bool) -> some View {
        if let image = MealPhotoStore.image(for: meal.displayPhotoFilename) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()

        } else if let items = meal.builderImageItems, !items.isEmpty {
            BuiltMealPlateView(
                items: items,
                plateSize: size * (isHero ? 0.90 : 0.86),
                itemScale: isHero ? 0.84 : 0.34,
                offsetScale: isHero ? 0.66 : 0.32,
                plateOpacity: isHero ? 0.80 : 0.42,
                shadowOpacity: isHero ? 0.18 : 0.12
            )
            .frame(width: size, height: size)
            .offset(x: isHero ? -size * 0.04 : 0)

        } else if !meal.imageName.isEmpty, UIImage(named: meal.imageName) != nil {
            Image(meal.imageName)
                .resizable()
                .scaledToFill()

        } else {
            placeholder(size: size, isHero: isHero)
        }
    }

    private func mediaShape(size: CGFloat, isHero: Bool) -> FoodMediaShape {
        if !forceCircleForLocalPhoto && MealPhotoStore.image(for: meal.displayPhotoFilename) != nil {
            let radius: CGFloat = isHero ? 24 : min(22, max(18, size * 0.22))
            return .roundedRectangle(cornerRadius: radius)
        } else {
            return .circle
        }
    }

    private func mediaShapePath(size: CGFloat, isHero: Bool) -> FoodMediaShapePath {
        FoodMediaShapePath(shape: mediaShape(size: size, isHero: isHero))
    }

    private func placeholder(size: CGFloat, isHero: Bool) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            WeekFitTheme.elevatedCard.opacity(0.95),
                            WeekFitTheme.cardBackground.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if meal.isFoodProduct {
                Text(meal.placeholderInitial)
                    .font(
                        .system(
                            size: max(16, size * (isHero ? 0.30 : 0.34)),
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(textPrimary.opacity(0.90))
                    .offset(x: isHero ? -size * 0.10 : -size * 0.07)
            } else {
                Image(systemName: "fork.knife")
                    .font(
                        .system(
                            size: max(15, size * (isHero ? 0.26 : 0.30)),
                            weight: .bold
                        )
                    )
                    .foregroundStyle(textSecondary.opacity(0.84))
                    .offset(x: isHero ? -size * 0.04 : 0)
            }
        }
        .frame(width: size * (isHero ? 0.60 : 0.66), height: size * (isHero ? 0.60 : 0.66))
    }
}

private struct FoodMediaShapePath: InsettableShape {
    let shape: FoodMediaShape
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)

        switch shape {
        case .circle:
            return Circle().path(in: insetRect)

        case .roundedRectangle(let cornerRadius):
            let radius = max(0, cornerRadius - insetAmount)
            return RoundedRectangle(cornerRadius: radius, style: .continuous)
                .path(in: insetRect)
        }
    }

    func inset(by amount: CGFloat) -> FoodMediaShapePath {
        FoodMediaShapePath(shape: shape, insetAmount: insetAmount + amount)
    }
}
