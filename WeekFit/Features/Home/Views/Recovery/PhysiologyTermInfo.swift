import SwiftUI

struct RecoveryRowAccessibilityLabel: ViewModifier {
    let text: String?

    func body(content: Content) -> some View {
        if let text {
            content.accessibilityLabel(Text(text))
        } else {
            content
        }
    }
}

enum PhysiologyTerm: String, Identifiable {
    case hrv
    case restingHeartRate
    case sleep
    case sleepDuration
    case sleepConsistency
    case sleepContinuity
    case sleepArchitecture
    case deepSleep
    case remSleep
    case coreSleep
    case awake
    case awakenings
    case timeInBed

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .hrv:
            return "recovery.term.hrv.title"
        case .restingHeartRate:
            return "recovery.term.rhr.title"
        case .sleep:
            return "recovery.term.sleep.title"
        case .sleepDuration:
            return "recovery.term.sleep.duration.title"
        case .sleepConsistency:
            return "recovery.term.sleep.consistency.title"
        case .sleepContinuity:
            return "recovery.term.sleep.continuity.title"
        case .sleepArchitecture:
            return "recovery.term.sleep.architecture.title"
        case .deepSleep:
            return "recovery.term.sleep.deep.title"
        case .remSleep:
            return "recovery.term.sleep.rem.title"
        case .coreSleep:
            return "recovery.term.sleep.core.title"
        case .awake:
            return "recovery.term.sleep.awake.title"
        case .awakenings:
            return "recovery.term.sleep.awakenings.title"
        case .timeInBed:
            return "recovery.term.sleep.timeInBed.title"
        }
    }

    var bodyKey: String {
        switch self {
        case .hrv:
            return "recovery.term.hrv.body"
        case .restingHeartRate:
            return "recovery.term.rhr.body"
        case .sleep:
            return "recovery.term.sleep.body"
        case .sleepDuration:
            return "recovery.term.sleep.duration.body"
        case .sleepConsistency:
            return "recovery.term.sleep.consistency.body"
        case .sleepContinuity:
            return "recovery.term.sleep.continuity.body"
        case .sleepArchitecture:
            return "recovery.term.sleep.architecture.body"
        case .deepSleep:
            return "recovery.term.sleep.deep.body"
        case .remSleep:
            return "recovery.term.sleep.rem.body"
        case .coreSleep:
            return "recovery.term.sleep.core.body"
        case .awake:
            return "recovery.term.sleep.awake.body"
        case .awakenings:
            return "recovery.term.sleep.awakenings.body"
        case .timeInBed:
            return "recovery.term.sleep.timeInBed.body"
        }
    }
}

struct PhysiologyTermInfoButton: View {
    let term: PhysiologyTerm

    @Environment(\.weekFitPalette) private var palette
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.textTertiary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(WeekFitLocalizedString("recovery.term.info.a11y")))
        .accessibilityHint(Text(WeekFitLocalizedString(term.titleKey)))
        .sheet(isPresented: $isPresented) {
            PhysiologyTermSheet(term: term)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct PhysiologyTermSheet: View {
    let term: PhysiologyTerm

    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(WeekFitLocalizedString(term.bodyKey))
                    .font(.body)
                    .foregroundStyle(palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(20)
            }
            .background(sheetBackground.ignoresSafeArea())
            .navigationTitle(WeekFitLocalizedString(term.titleKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    WeekFitCloseButton(size: .large, playsHaptic: false) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var sheetBackground: Color {
        palette.isLight ? HealthDetailsSoftChrome.canvas : RecoveryStyle.screenBackground
    }
}
