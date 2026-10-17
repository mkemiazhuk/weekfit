import SwiftUI

struct PhotoFoodConfirmationSheet: View {
    @Bindable var draft: PhotoFoodLogDraft
    let isLogging: Bool
    let onLog: () -> Void
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    let errorMessage: String?

    @Environment(\.weekFitPalette) private var palette
    /// Expanded by default so every recognized item is visible before logging.
    @State private var componentsExpanded = true

    private var accent: Color { WeekFitTheme.meal }
    private var totals: PhotoFoodNutritionTotals { draft.totals }

    var body: some View {
        VStack(spacing: 0) {
            QuickSheetPremiumHeader(
                title: WeekFitLocalizedString("today.photoLog.confirm.title"),
                subtitle: WeekFitLocalizedString("today.photoLog.confirm.subtitle"),
                onClose: onDismiss
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(palette.isLight ? WeekFitLightTokens.critical : Color.red.opacity(0.9))
                    }

                    headerCard
                    macrosRow
                    portionControl
                    if !draft.uncertainties.isEmpty {
                        uncertaintiesBlock
                    }
                    if let question = draft.clarificationQuestion {
                        clarificationBlock(question)
                    }
                    componentsSection
                    saveToggle
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
            }

            footer
        }
        .background(QuickActionSheetDesign.Color.sheetBackground(for: .food).ignoresSafeArea())
        .interactiveDismissDisabled(isLogging)
    }

    private var headerCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if let image = draft.previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        accent.opacity(0.14)
                        Image(systemName: "fork.knife")
                            .foregroundStyle(accent)
                    }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                TextField(
                    WeekFitLocalizedString("today.photoLog.confirm.namePlaceholder"),
                    text: $draft.mealName
                )
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)

                HStack(spacing: 8) {
                    slotChip
                    if draft.showsEstimatedNutrition {
                        Text(WeekFitLocalizedString("today.photoLog.confirm.estimatedNutrition"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(WeekFitTheme.secondaryText)
                    }
                }
            }
        }
        .padding(14)
        .weekFitPremiumCard(emphasis: .elevated, accent: accent, cornerRadius: 20)
    }

    private var slotChip: some View {
        Menu {
            ForEach([WeekFitMealSlot.breakfast, .lunch, .dinner, .snack], id: \.rawValue) { slot in
                Button(slot.title) { draft.mealSlot = slot }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: draft.mealSlot.icon)
                Text(draft.mealSlot.title)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(accent.opacity(0.14)))
        }
    }

    private var macrosRow: some View {
        HStack(spacing: 8) {
            macroChip("kcal", value: "\(totals.calories)")
            macroChip("P", value: "\(totals.protein)g")
            macroChip("C", value: "\(totals.carbs)g")
            macroChip("F", value: "\(totals.fats)g")
        }
    }

    private func macroChip(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WeekFitTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .weekFitPremiumCard(emphasis: .compact, accent: nil, cornerRadius: 14)
    }

    private var portionControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("today.photoLog.confirm.portion"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(WeekFitTheme.secondaryText)

            HStack(spacing: 12) {
                portionButton("0.5×", value: 0.5)
                portionButton("1×", value: 1.0)
                portionButton("1.5×", value: 1.5)
                portionButton("2×", value: 2.0)
            }

            if componentsExpanded {
                Text(WeekFitLocalizedString("today.photoLog.confirm.gramsHint"))
                    .font(.caption2)
                    .foregroundStyle(WeekFitTheme.secondaryText)
            }
        }
    }

    private func portionButton(_ title: String, value: Double) -> some View {
        let selected = abs(draft.portionMultiplier - value) < 0.01
        return Button {
            draft.portionMultiplier = value
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(selected ? WeekFitTheme.primaryCTAForeground : WeekFitTheme.primaryText)
                .background {
                    Capsule().fill(selected ? accent : WeekFitTheme.secondaryText.opacity(0.12))
                }
        }
        .buttonStyle(.plain)
    }

    private var uncertaintiesBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(WeekFitLocalizedString("today.photoLog.confirm.uncertainties"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(WeekFitTheme.secondaryText)
            ForEach(Array(draft.uncertainties.prefix(3).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPremiumCard(emphasis: .compact, cornerRadius: 14)
    }

    private func clarificationBlock(_ question: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(WeekFitTheme.primaryText)
            TextField(
                WeekFitLocalizedString("today.photoLog.confirm.clarificationPlaceholder"),
                text: $draft.clarificationAnswer
            )
            .font(.subheadline)
            .padding(12)
            .weekFitPremiumCard(emphasis: .compact, cornerRadius: 14)
        }
        .padding(12)
        .weekFitPremiumCard(emphasis: .accent, accent: accent, cornerRadius: 16)
    }

    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    componentsExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(WeekFitLocalizedString("today.photoLog.confirm.components"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                    Spacer()
                    Image(systemName: componentsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)

            if componentsExpanded {
                ForEach($draft.components) { $component in
                    componentRow($component)
                }
            }
        }
    }

    private func componentRow(_ component: Binding<PhotoFoodComponent>) -> some View {
        let preparation = component.wrappedValue.preparation?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(component.wrappedValue.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if !preparation.isEmpty {
                        Text(preparation)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(WeekFitTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                if component.wrappedValue.isAIEstimated {
                    Text(WeekFitLocalizedString("today.photoLog.confirm.aiEstimateBadge"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                }
            }

            HStack {
                Text("\(Int(component.wrappedValue.grams.rounded())) g")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .frame(width: 52, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { component.wrappedValue.grams },
                        set: { component.wrappedValue.grams = max($0, 1) }
                    ),
                    in: 10...800,
                    step: 5
                )
                .tint(accent)
            }
        }
        .padding(12)
        .weekFitPremiumCard(emphasis: .compact, cornerRadius: 14)
    }

    private var saveToggle: some View {
        Toggle(isOn: $draft.saveToLibrary) {
            VStack(alignment: .leading, spacing: 2) {
                Text(WeekFitLocalizedString("today.photoLog.confirm.saveToLibrary"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WeekFitTheme.primaryText)
                Text(WeekFitLocalizedString("today.photoLog.confirm.saveToLibraryHint"))
                    .font(.caption)
                    .foregroundStyle(WeekFitTheme.secondaryText)
            }
        }
        .tint(accent)
        .padding(.vertical, 4)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button(action: onLog) {
                HStack(spacing: 8) {
                    if isLogging {
                        ProgressView().tint(WeekFitTheme.primaryCTAForeground)
                    }
                    Text(logTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(WeekFitTheme.primaryCTAForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background {
                    Capsule().fill(accent.opacity(draft.canLog && !isLogging ? 1 : 0.38))
                }
            }
            .buttonStyle(.plain)
            .disabled(!draft.canLog || isLogging)

            if let onRetry {
                Button(WeekFitLocalizedString("today.photoLog.confirm.retry"), action: onRetry)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .disabled(isLogging)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var logTitle: String {
        if isLogging {
            return WeekFitLocalizedString("today.photoLog.confirm.logging")
        }
        switch draft.mealSlot {
        case .breakfast:
            return WeekFitLocalizedString("today.photoLog.confirm.logBreakfast")
        case .lunch:
            return WeekFitLocalizedString("today.photoLog.confirm.logLunch")
        case .dinner:
            return WeekFitLocalizedString("today.photoLog.confirm.logDinner")
        case .snack:
            return WeekFitLocalizedString("today.photoLog.confirm.logSnack")
        }
    }
}
