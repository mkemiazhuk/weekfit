import SwiftUI
import UIKit

/// Evening Coach recap — compact one-screen layout with soft glow (no hard horizon line).
struct CoachEveningRecapView: View {
    let activitySummary: CoachEveningRecapActivitySummary
    let daySignals: [CoachEveningRecapSignal]
    let commentary: String?
    /// Set when the note belongs to a previous local day ("Yesterday" or a date).
    var summaryDayCaption: String? = nil
    let isLoadingCommentary: Bool
    let commentaryFailed: Bool
    let selectedFeeling: CoachFeelingKind?
    let unitSystem: WeekFitResolvedUnitSystem
    let showsHealthConnect: Bool
    let onSelectFeeling: (CoachFeelingKind) -> Void
    let onConnectHealth: () -> Void

    @Environment(\.weekFitPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var languageManager: AppLanguageManager

    @ScaledMetric(relativeTo: .largeTitle) private var heroValueSize: CGFloat = WeekFitType.heroMetricBase
    @ScaledMetric(relativeTo: .largeTitle) private var heroCompactValueSize: CGFloat = WeekFitType.heroMetricCompactBase

    private let eveningFeelings: [CoachFeelingKind] = [.tired, .okay, .energized]

    private var primary: Color { CoachEveningRecapChrome.primaryText(isLight: palette.isLight) }
    private var secondary: Color { CoachEveningRecapChrome.secondaryText(isLight: palette.isLight) }
    private var copper: Color { CoachEveningRecapChrome.copper }
    private var champagne: Color { CoachEveningRecapChrome.champagne }

    private var headline: String {
        CoachEveningRecapCopy.headline(
            tone: activitySummary.dayTone,
            givenName: ProfileService.resolvedGivenName()
        )
    }

    private var feelingReaction: String? {
        guard let selectedFeeling else { return nil }
        return CoachEveningRecapCopy.feelingReaction(
            feeling: selectedFeeling,
            tone: activitySummary.dayTone
        )
    }

    private var usesCompactHero: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var dividerColor: Color {
        palette.isLight
            ? Color.black.opacity(0.07)
            : Color.white.opacity(0.08)
    }

    var body: some View {
        let _ = languageManager.selectedLanguage

        VStack(alignment: .leading, spacing: 0) {
            personalHeader
                .padding(.bottom, 14)

            if showsHealthConnect {
                healthConnectRow
                    .padding(.bottom, 14)
            }

            if activitySummary.healthAccessGranted || activitySummary.hero != nil || !daySignals.isEmpty {
                dayOverview
            } else if !showsHealthConnect {
                Text(WeekFitLocalizedString("coach.eveningRecap.yourDay.empty"))
                    .font(WeekFitType.body.weight(.medium))
                    .fontDesign(.rounded)
                    .foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            noteCard
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coach.eveningRecap")
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: selectedFeeling)
    }

    // MARK: - Header

    private var personalHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(WeekFitLocalizedString("coach.eveningRecap.yourDay.subtitle"))
                .font(WeekFitType.sectionLabel.weight(.semibold))
                .fontDesign(.rounded)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(copper.opacity(palette.isLight ? 0.85 : 0.90))

            if let summaryDayCaption {
                Text(summaryDayCaption)
                    .font(WeekFitType.secondary.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(primary.opacity(0.88))
                    .accessibilityIdentifier("coach.eveningRecap.summaryDay")
            }

            Text(headline)
                .font(WeekFitType.cardTitle)
                .fontDesign(.rounded)
                .foregroundStyle(primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Day overview

    private var dayOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let hero = activitySummary.hero {
                heroBlock(hero)
            }

            if !daySignals.isEmpty {
                signalList
            } else if activitySummary.hero == nil, activitySummary.healthAccessGranted {
                Text(WeekFitLocalizedString("coach.eveningRecap.yourDay.empty"))
                    .font(WeekFitType.body.weight(.medium))
                    .fontDesign(.rounded)
                    .foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func heroBlock(_ hero: CoachEveningRecapHero) -> some View {
        let parts = hero.localizedValueParts(unitSystem: unitSystem)
        let heroSize = usesCompactHero ? heroCompactValueSize : heroValueSize
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(parts.value)
                    .font(.system(size: heroSize, weight: .bold, design: .rounded))
                    .foregroundStyle(primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .layoutPriority(1)

                if let unit = parts.unit, !unit.isEmpty {
                    Text(unit)
                        .font(
                            usesCompactHero
                                ? WeekFitType.compactCardTitle.weight(.medium)
                                : WeekFitType.heroMetricUnit
                        )
                        .fontDesign(.rounded)
                        .foregroundStyle(secondary.opacity(0.90))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(hero.localizedCaption())
                    .font(WeekFitType.body.weight(.medium))
                    .fontDesign(.rounded)
                    .foregroundStyle(primary.opacity(0.90))

                if let secondaryValue = hero.localizedSecondary(unitSystem: unitSystem) {
                    Text("·")
                        .foregroundStyle(secondary.opacity(0.45))
                    Text(secondaryValue)
                        .font(WeekFitType.body.weight(.medium))
                        .fontDesign(.rounded)
                        .foregroundStyle(secondary.opacity(0.82))
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Signal list (full-width rows, no navigation)

    private var signalList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(daySignals.enumerated()), id: \.element.id) { index, signal in
                if index > 0 {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                }
                signalRow(signal)
                    .padding(.vertical, 10)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func signalRow(_ signal: CoachEveningRecapSignal) -> some View {
        let accent = CoachEveningRecapChrome.accent(for: signal.kind, isLight: palette.isLight)
        // Single full-width row: icon + title … value — uses the right side, shortens the screen.
        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: signal.systemImage)
                .font(.system(size: 22, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(accent)
                .frame(width: 28, alignment: .center)

            Text(signal.title)
                .font(WeekFitType.body.weight(.medium))
                .fontDesign(.rounded)
                .foregroundStyle(secondary.opacity(0.90))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(signal.detail)
                .font(
                    usesCompactHero
                        ? WeekFitType.compactCardTitle
                        : WeekFitType.heroMetricSignal
                )
                .fontDesign(.rounded)
                .foregroundStyle(primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(signal.title). \(signal.detail)")
    }

    // MARK: - Coach note card

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("coach.eveningRecap.note.title"))
                .font(WeekFitType.sectionLabel.weight(.semibold))
                .fontDesign(.rounded)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(copper.opacity(palette.isLight ? 0.85 : 0.90))

            noteBody

            feelingSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(CoachEveningRecapChrome.noteCardFill(isLight: palette.isLight))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            CoachEveningRecapChrome.noteCardStroke(isLight: palette.isLight),
                            lineWidth: 1
                        )
                }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var noteBody: some View {
        // After feeling is chosen, keep the AI/local note — reaction lives in the pill.
        let noteFeeling: String? = selectedFeeling == nil ? feelingReaction : nil
        if let text = CoachEveningRecapCopy.noteText(
            commentary: commentary,
            comparison: activitySummary.dayComparisonDisplay(unitSystem: unitSystem),
            feelingReaction: noteFeeling,
            isLoading: isLoadingCommentary && selectedFeeling == nil,
            failed: commentaryFailed && selectedFeeling == nil
        ) {
            Text(text)
                .font(WeekFitType.body.weight(.medium))
                .fontDesign(.rounded)
                .foregroundStyle(primary.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                #if DEBUG
                .onAppear {
                    // Exact card text after comparison/fallback merge — not only raw AI passages.
                    CoachEveningSummaryDebugTape.logUI(
                        source: "card",
                        requestId: nil,
                        generatedAt: nil,
                        displayedNote: text
                    )
                }
                .onLongPressGesture {
                    // Explicit developer action: write last INPUT/OUTPUT tape to Application Support.
                    do {
                        let url = try CoachEveningSummaryDebugTape.exportLastToApplicationSupport()
                        print("[CoachSummary][EXPORT] saved \(url.lastPathComponent)")
                    } catch {
                        print("[CoachSummary][EXPORT] failed error=\(String(describing: type(of: error)))")
                    }
                }
                #endif
        } else if isLoadingCommentary, selectedFeeling == nil {
            HStack(spacing: 8) {
                ProgressView()
                Text(WeekFitLocalizedString("coach.eveningRecap.forEvening.loading"))
                    .font(WeekFitType.secondary.weight(.medium))
                    .fontDesign(.rounded)
                    .foregroundStyle(secondary)
            }
        }
    }

    // MARK: - Feeling

    private var feelingSection: some View {
        Group {
            if let selectedFeeling {
                feelingSettled(selectedFeeling)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(WeekFitLocalizedString("coach.eveningRecap.feeling.prompt"))
                        .font(WeekFitType.secondary.weight(.medium))
                        .fontDesign(.rounded)
                        .foregroundStyle(secondary.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        ForEach(eveningFeelings, id: \.rawValue) { feeling in
                            feelingChoice(feeling)
                        }
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    private func feelingChoice(_ feeling: CoachFeelingKind) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelectFeeling(feeling)
        } label: {
            Text(feelingLabel(feeling))
                .font(WeekFitType.secondary.weight(.semibold))
                .fontDesign(.rounded)
                .lineLimit(1)
                .foregroundStyle(primary.opacity(0.92))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background {
                    Capsule(style: .continuous)
                        .fill(CoachEveningRecapChrome.feelingPillFill(isLight: palette.isLight))
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(copper.opacity(palette.isLight ? 0.14 : 0.16), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("coach.eveningRecap.feeling.\(feeling.rawValue)")
    }

    private func feelingSettled(_ feeling: CoachFeelingKind) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(champagne.opacity(0.92))
                    .frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.85))
            }

            Text(
                String(
                    format: WeekFitLocalizedString("coach.eveningRecap.feeling.settledFormat"),
                    feelingLabel(feeling)
                )
            )
            .font(WeekFitType.body.weight(.medium))
            .fontDesign(.rounded)
            .foregroundStyle(primary.opacity(0.94))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background {
            Capsule(style: .continuous)
                .fill(CoachEveningRecapChrome.feelingPillFill(isLight: palette.isLight))
        }
        .accessibilityElement(children: .combine)
    }

    private func feelingLabel(_ feeling: CoachFeelingKind) -> String {
        switch feeling {
        case .tired:
            return WeekFitLocalizedString("coach.eveningRecap.feeling.tired")
        case .okay:
            return WeekFitLocalizedString("coach.eveningRecap.feeling.good")
        case .energized:
            return WeekFitLocalizedString("coach.eveningRecap.feeling.energized")
        case .low:
            return WeekFitLocalizedString("coach.feeling.choice.low")
        }
    }

    // MARK: - Health

    private var healthConnectRow: some View {
        Button(action: onConnectHealth) {
            HStack(spacing: 10) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(WeekFitLocalizedString("today.connectAppleHealth"))
                        .font(WeekFitType.button)
                        .fontDesign(.rounded)
                        .foregroundStyle(primary)
                    Text(WeekFitLocalizedString("coach.eveningRecap.health.connectHint"))
                        .font(WeekFitType.caption)
                        .fontDesign(.rounded)
                        .foregroundStyle(secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
