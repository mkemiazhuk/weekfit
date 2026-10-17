import SwiftUI
import SwiftData
import UIKit
import WeekFitPlanner

/// Diary-entry detail for photo / quick food logs that are **not** Meals-library recipes.
/// Shows the attached diary photo, macros, components, and optional Save to Meals.
struct LoggedMealDetailView: View {
    let activity: PlannedActivity
    var existingMeals: [Meals]
    var onSavedToLibrary: ((Meals) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weekFitPalette) private var palette
    @EnvironmentObject private var languageManager: AppLanguageManager

    @State private var didSaveToLibrary = false
    @State private var saveError: String?

    private var accent: Color { QuickFoodAccent.actionOrange }
    private var snapshot: PhotoFoodDiarySnapshot? {
        PhotoFoodNutritionCalculator.decodeSnapshot(activity.nutritionSnapshotJSON)
    }

    private var photoFilename: String? {
        let candidates = [
            activity.diaryPhotoFilename,
            activity.imageName,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        return candidates.first { MealPhotoStore.image(for: $0) != nil }
            ?? candidates.first
    }

    private var mealName: String {
        let fromSnapshot = snapshot?.mealName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fromSnapshot.isEmpty ? activity.title : fromSnapshot
    }

    private var slotTitle: String? {
        if let raw = activity.mealSlotRaw ?? snapshot?.mealSlotRaw,
           let slot = WeekFitMealSlot(rawValue: raw) {
            return slot.title
        }
        return nil
    }

    private var timeText: String {
        PhotoFoodDiaryLogger.clockTimeString(from: activity.date)
    }

    private var isAlreadyInLibrary: Bool {
        if didSaveToLibrary { return true }
        if let id = activity.libraryMealId ?? snapshot?.libraryMealId,
           existingMeals.contains(where: { $0.id == id }) {
            return true
        }
        return false
    }

    private var estimateKind: PhotoFoodEstimateKind {
        if let raw = activity.nutritionEstimateKind,
           let kind = PhotoFoodEstimateKind(rawValue: raw) {
            return kind
        }
        return snapshot?.estimateKind ?? .estimated
    }

    var body: some View {
        let _ = languageManager.selectedLanguage

        ZStack {
            palette.appScreenBackground.ignoresSafeArea()
            WeekFitTheme.mealsAmbient
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        heroCard
                        if let components = snapshot?.components, !components.isEmpty {
                            componentsCard(components)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }

                if !isAlreadyInLibrary {
                    saveFooter
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            if activity.libraryMealId != nil || snapshot?.libraryMealId != nil {
                didSaveToLibrary = existingMeals.contains {
                    $0.id == activity.libraryMealId || $0.id == snapshot?.libraryMealId
                }
            }
        }
    }

    private var header: some View {
        WeekFitDetailScreenHeader(
            title: WeekFitLocalizedString("planner.loggedMeal.detail.title"),
            subtitle: WeekFitLocalizedString("planner.loggedMeal.detail.subtitle"),
            titleSize: 22,
            titleTracking: -0.35,
            titleColor: palette.textPrimary,
            subtitleColor: palette.textSecondary.opacity(0.76)
        ) {
            WeekFitDetailScreenBackButton { dismiss() }
        } trailing: {
            EmptyView()
        }
    }

    private var heroCard: some View {
        VStack(spacing: 12) {
            photoHero
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(mealName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .tracking(-0.4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if let slotTitle {
                        metaChip(icon: "fork.knife", text: slotTitle)
                    }
                    metaChip(icon: "clock", text: timeText)
                    if estimateKind != .database {
                        metaChip(
                            icon: "sparkles",
                            text: WeekFitLocalizedString("today.photoLog.confirm.estimatedNutrition")
                        )
                    }
                }

                MealNutritionSummaryStrip(
                    calories: activity.calories,
                    protein: activity.protein,
                    carbs: activity.carbs,
                    fats: activity.fats,
                    fiber: activity.fiber,
                    accent: accent,
                    style: .embedded
                )
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .weekFitPremiumCard(emphasis: .elevated, accent: accent, cornerRadius: 26)
    }

    @ViewBuilder
    private var photoHero: some View {
        if let filename = photoFilename {
            AsyncMealPhotoView(filename: filename, targetPixelSize: 720) { image in
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    photoPlaceholder
                }
            }
        } else {
            photoPlaceholder
        }
    }

    private var photoPlaceholder: some View {
        ZStack {
            accent.opacity(palette.isLight ? 0.10 : 0.16)
            Image(systemName: "fork.knife")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(palette.textSecondary.opacity(0.7))
        }
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(palette.textSecondary.opacity(0.85))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(palette.textSecondary.opacity(palette.isLight ? 0.08 : 0.14))
        )
    }

    private func componentsCard(_ components: [PhotoFoodComponent]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("today.photoLog.confirm.components"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.textSecondary.opacity(0.72))

            VStack(spacing: 0) {
                ForEach(Array(components.enumerated()), id: \.element.id) { index, component in
                    let preparation = component.preparation?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(component.displayName)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            if !preparation.isEmpty {
                                Text(preparation)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(palette.textSecondary.opacity(0.78))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 8)
                        Text("\(Int(component.grams.rounded())) g")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                        Text("\(component.calories) kcal")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                            .frame(minWidth: 64, alignment: .trailing)
                    }
                    .padding(.vertical, 10)

                    if index != components.count - 1 {
                        Rectangle()
                            .fill(palette.textSecondary.opacity(0.12))
                            .frame(height: 1)
                    }
                }
            }
        }
        .padding(14)
        .weekFitPremiumCard(emphasis: .standard, cornerRadius: 20)
    }

    private var saveFooter: some View {
        VStack(spacing: 8) {
            if let saveError {
                Text(saveError)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: saveToLibrary) {
                Text(WeekFitLocalizedString("today.photoLog.confirm.saveToLibrary"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryCTAForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(accent))
            }
            .buttonStyle(.plain)

            Text(WeekFitLocalizedString("planner.loggedMeal.detail.saveHint"))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private func saveToLibrary() {
        do {
            let meal = try PhotoFoodDiaryLogger.promoteToLibrary(
                activity: activity,
                existingMeals: existingMeals
            )
            try? modelContext.save()
            didSaveToLibrary = true
            saveError = nil
            onSavedToLibrary?(meal)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            saveError = WeekFitLocalizedString("planner.loggedMeal.detail.saveFailed")
        }
    }
}
