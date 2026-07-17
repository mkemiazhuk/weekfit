import SwiftUI

/// Inset grouped section chrome for Settings-style lists (one card, hairline dividers).
struct SettingsGroupedSection<Content: View>: View {
    var title: LocalizedStringResource? = nil
    var cornerRadius: CGFloat = 20
    @ViewBuilder var content: Content

    init(
        title: LocalizedStringResource? = nil,
        cornerRadius: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WeekFitTheme.primaryText.opacity(0.92))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
            }

            VStack(spacing: 0) {
                content
            }
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(WeekFitTheme.cardTertiary)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(WeekFitTheme.borderSoft, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

struct SettingsGroupDivider: View {
    /// Indent past leading icon + padding so the rule aligns with row text.
    var leadingInset: CGFloat = 63

    var body: some View {
        Rectangle()
            .fill(WeekFitTheme.borderSoft)
            .frame(height: 0.5)
            .padding(.leading, leadingInset)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Ensures Settings rows meet the 44pt minimum touch target while scaling with Dynamic Type.
    func settingsRowTouchTarget(minHeight: CGFloat = 52) -> some View {
        frame(minHeight: minHeight)
            .contentShape(Rectangle())
    }
}
