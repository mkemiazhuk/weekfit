import SwiftUI
import UIKit

struct MealPhotoCropEditorView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onUse: (UIImage) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = 300
    private let outputSize: CGFloat = 720
    private let background = WeekFitTheme.backgroundColor
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let accent = WeekFitTheme.meal

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 22) {
                header

                Spacer(minLength: 8)

                cropSurface

                hintText

                Spacer(minLength: 8)

                actionBar
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Button {
                onCancel()
            } label: {
                Text(AppText.Common.Action.cancel)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.82))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(AppText.Meals.PhotoCrop.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)

            Spacer()

            Button {
                resetCrop()
            } label: {
                Text(AppText.Common.Action.reset)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(accent.opacity(0.92))
            }
            .buttonStyle(.plain)
        }
    }

    private var cropSurface: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: cropSize, height: cropSize)
                .scaleEffect(scale)
                .offset(offset)
                .clipShape(Circle())

            Circle()
                .stroke(WeekFitTheme.whiteOpacity(0.88), lineWidth: 2)
                .frame(width: cropSize, height: cropSize)

            Circle()
                .stroke(accent.opacity(0.28), lineWidth: 8)
                .frame(width: cropSize + 8, height: cropSize + 8)
        }
        .frame(width: cropSize + 36, height: cropSize + 36)
        .background {
            Circle()
                .fill(Color.black.opacity(0.24))
                .blur(radius: 0.2)
        }
        .contentShape(Circle())
        .gesture(dragGesture.simultaneously(with: magnificationGesture))
    }

    private var hintText: some View {
        Text(AppText.Meals.PhotoCrop.hint)
            .font(.system(size: 13.2, weight: .semibold, design: .rounded))
            .foregroundStyle(textSecondary.opacity(0.72))
            .multilineTextAlignment(.center)
    }

    private var actionBar: some View {
        Button {
            let cropped = Self.crop(
                image,
                outputSize: outputSize,
                previewSize: cropSize,
                scale: scale,
                offset: offset
            )
            onUse(cropped)
        } label: {
            Text(AppText.Common.Action.usePhoto)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.84))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background {
                    Capsule()
                        .fill(accent.opacity(0.94))
                }
        }
        .buttonStyle(.plain)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = clampedOffset(
                    CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    ),
                    scale: scale
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 4)
                offset = clampedOffset(offset, scale: scale)
            }
            .onEnded { _ in
                lastScale = scale
                lastOffset = offset
            }
    }

    private func resetCrop() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
        }
    }

    private func clampedOffset(_ proposed: CGSize, scale: CGFloat) -> CGSize {
        let limit = (cropSize * max(scale - 1, 0)) / 2
        return CGSize(
            width: min(max(proposed.width, -limit), limit),
            height: min(max(proposed.height, -limit), limit)
        )
    }

    static func crop(
        _ image: UIImage,
        outputSize: CGFloat,
        previewSize: CGFloat,
        scale: CGFloat,
        offset: CGSize
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputSize, height: outputSize),
            format: format
        )

        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: outputSize, height: outputSize))

            let imageSize = normalizedSize(for: image)
            let baseScale = max(previewSize / imageSize.width, previewSize / imageSize.height)
            let finalScale = baseScale * max(scale, 1)
            let renderedSize = CGSize(
                width: imageSize.width * finalScale,
                height: imageSize.height * finalScale
            )
            let outputRatio = outputSize / previewSize
            let origin = CGPoint(
                x: (outputSize - renderedSize.width * outputRatio) / 2 + offset.width * outputRatio,
                y: (outputSize - renderedSize.height * outputRatio) / 2 + offset.height * outputRatio
            )
            let rect = CGRect(
                origin: origin,
                size: CGSize(
                    width: renderedSize.width * outputRatio,
                    height: renderedSize.height * outputRatio
                )
            )

            image.draw(in: rect)
        }
    }

    private static func normalizedSize(for image: UIImage) -> CGSize {
        if image.imageOrientation == .left || image.imageOrientation == .right ||
            image.imageOrientation == .leftMirrored || image.imageOrientation == .rightMirrored {
            return CGSize(width: image.size.height, height: image.size.width)
        }

        return image.size
    }
}
