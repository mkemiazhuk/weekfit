import Foundation
import SwiftData
import UIKit
import WeekFitPlanner

enum PhotoFoodDiaryLogger {

    struct LogResult: Equatable, Sendable {
        let activityId: String
        let libraryMealId: String?
        let savedToLibrary: Bool
    }

    enum LogError: Error, Equatable {
        case invalidDraft
        case duplicateInFlight
        case saveFailed
    }

    /// Prevents double-tap duplicate diary rows / library saves.
    private static let submitLock = NSLock()
    private static var inFlightKeys = Set<String>()

    @MainActor
    static func log(
        draft: PhotoFoodLogDraft,
        modelContext: ModelContext,
        existingMeals: [Meals],
        onSaveLibraryMeal: ((Meals) -> Void)?,
        analyticsSource: AnalyticsSource = .today
    ) throws -> LogResult {
        guard draft.canLog else { throw LogError.invalidDraft }

        let submitKey = submitKey(for: draft)
        submitLock.lock()
        if inFlightKeys.contains(submitKey) {
            submitLock.unlock()
            throw LogError.duplicateInFlight
        }
        inFlightKeys.insert(submitKey)
        submitLock.unlock()
        defer {
            submitLock.lock()
            inFlightKeys.remove(submitKey)
            submitLock.unlock()
        }

        let totals = draft.totals
        let estimateKind = draft.estimateKind
        var libraryMealId: String?
        var imageName = ""
        var diaryPhotoFilename = draft.diaryPhotoFilename

        if draft.saveToLibrary {
            let meal = try makeLibraryMeal(from: draft, existingMeals: existingMeals)
            onSaveLibraryMeal?(meal)
            libraryMealId = meal.id
            imageName = meal.imageName
            if diaryPhotoFilename == nil {
                diaryPhotoFilename = meal.localPhotoThumbnailFilename ?? meal.localPhotoFilename
            }
        } else if let preview = draft.previewImage, diaryPhotoFilename == nil {
            // Retain photo only when user confirms log (not for abandoned analysis).
            if let photoSet = try? MealPhotoStore.savePhotoSet(preview) {
                diaryPhotoFilename = photoSet.thumbnailFilename
                imageName = photoSet.thumbnailFilename
            }
        } else if let diaryPhotoFilename {
            imageName = diaryPhotoFilename
        }

        let snapshot = PhotoFoodNutritionCalculator.makeSnapshot(
            draft: draft,
            libraryMealId: libraryMealId
        )
        let snapshotJSON = PhotoFoodNutritionCalculator.encodeSnapshot(snapshot)

        // Use the exact clock time of the log, on the selected calendar day
        // (not a fixed breakfast/lunch/dinner hour like 13:00).
        let activityDate = activityDate(forSelectedDay: draft.logDate, loggedAt: Date())
        let activityType = draft.mealSlot == .snack ? "snack" : "meal"
        let method: FoodLoggingMethod = draft.captureMethod == .barcode ? .barcode : .photo

        let activity = PlannedActivity(
            id: UUID().uuidString,
            date: activityDate,
            type: activityType,
            title: snapshot.mealName,
            durationMinutes: 10,
            icon: draft.mealSlot.icon,
            imageName: imageName,
            colorRed: 0.898,
            colorGreen: 0.553,
            colorBlue: 0.196,
            calories: totals.calories,
            protein: totals.protein,
            carbs: totals.carbs,
            fats: totals.fats,
            fiber: totals.fiber,
            isCompleted: true,
            isSkipped: false,
            source: "today",
            nutritionSnapshotJSON: snapshotJSON,
            nutritionEstimateKind: estimateKind.rawValue,
            mealSlotRaw: draft.mealSlot.rawValue,
            libraryMealId: libraryMealId,
            diaryPhotoFilename: diaryPhotoFilename
        )

        AppReviewDemoPlannedActivityTagger.tagIfNeeded(activity)
        modelContext.insert(activity)
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(activity)
            throw LogError.saveFailed
        }

        ReviewEngagement.record(.foodLogged)
        ProductAnalytics.foodLoggingCompleted(method: method, source: analyticsSource, operation: .diary)
        PhotoFoodAnalytics.logged(
            method: method,
            savedToLibrary: libraryMealId != nil,
            estimateKind: estimateKind
        )

        return LogResult(
            activityId: activity.id,
            libraryMealId: libraryMealId,
            savedToLibrary: libraryMealId != nil
        )
    }

    // MARK: - Library

    /// Promote a diary-only photo/quick log into the Meals library (Save to Meals).
    @MainActor
    static func promoteToLibrary(
        activity: PlannedActivity,
        existingMeals: [Meals]
    ) throws -> Meals {
        if let existingId = activity.libraryMealId,
           let existing = existingMeals.first(where: { $0.id == existingId }) {
            return existing
        }

        guard let snapshot = PhotoFoodNutritionCalculator.decodeSnapshot(activity.nutritionSnapshotJSON) else {
            throw LogError.invalidDraft
        }

        let photoFilename = firstNonEmpty(
            activity.diaryPhotoFilename,
            activity.imageName
        )
        let meal = makeLibraryMeal(
            title: snapshot.mealName.isEmpty ? activity.title : snapshot.mealName,
            components: snapshot.components,
            totals: snapshot.totals.asTotals,
            estimateKind: snapshot.estimateKind,
            barcode: nil,
            barcodeDataSource: nil,
            localPhotoFilename: photoFilename,
            localPhotoThumbnailFilename: photoFilename,
            suggestedTime: clockTimeString(from: activity.date),
            existingMeals: existingMeals
        )

        activity.libraryMealId = meal.id
        if activity.imageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let photoFilename {
            activity.imageName = photoFilename
        }
        if activity.diaryPhotoFilename == nil {
            activity.diaryPhotoFilename = photoFilename
        }

        var updatedSnapshot = snapshot
        updatedSnapshot.libraryMealId = meal.id
        activity.nutritionSnapshotJSON = PhotoFoodNutritionCalculator.encodeSnapshot(updatedSnapshot)

        return meal
    }

    @MainActor
    private static func makeLibraryMeal(
        from draft: PhotoFoodLogDraft,
        existingMeals: [Meals]
    ) throws -> Meals {
        var localPhotoFilename: String?
        var localPhotoThumbnailFilename: String?
        if let preview = draft.previewImage,
           let photoSet = try? MealPhotoStore.savePhotoSet(preview) {
            localPhotoFilename = photoSet.originalFilename
            localPhotoThumbnailFilename = photoSet.thumbnailFilename
        }

        return makeLibraryMeal(
            title: draft.mealName,
            components: draft.scaledComponents,
            totals: draft.totals,
            estimateKind: draft.estimateKind,
            barcode: draft.barcode,
            barcodeDataSource: draft.barcodeDataSource,
            localPhotoFilename: localPhotoFilename,
            localPhotoThumbnailFilename: localPhotoThumbnailFilename,
            suggestedTime: clockTimeString(from: activityDate(forSelectedDay: draft.logDate)),
            existingMeals: existingMeals
        )
    }

    @MainActor
    private static func makeLibraryMeal(
        title: String,
        components: [PhotoFoodComponent],
        totals: PhotoFoodNutritionTotals,
        estimateKind: PhotoFoodEstimateKind,
        barcode: String?,
        barcodeDataSource: NutritionDataSource?,
        localPhotoFilename: String?,
        localPhotoThumbnailFilename: String?,
        suggestedTime: String,
        existingMeals: [Meals]
    ) -> Meals {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let uniqueTitle = uniquedTitle(trimmed.isEmpty ? WeekFitLocalizedString("planner.loggedMeal") : trimmed, existing: existingMeals)
        let servingGrams = max(
            Int(components.reduce(0) { $0 + $1.grams }.rounded()),
            1
        )

        let ingredients: [MealsIngredient] = components.map { component in
            let roundedGrams = max(Int(component.grams.rounded()), 0)
            let preparation = component.preparation?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return MealsIngredient(
                name: component.displayName,
                amount: "\(roundedGrams) g",
                grams: component.grams,
                preparation: preparation?.isEmpty == false ? preparation : nil,
                calories: component.calories,
                protein: component.protein,
                carbs: component.carbs,
                fats: component.fats,
                fiber: component.fiber
            )
        }

        let imageName = localPhotoThumbnailFilename ?? localPhotoFilename ?? ""

        return Meals(
            id: "photo_meal_\(UUID().uuidString)",
            title: uniqueTitle,
            subtitle: WeekFitLocalizedString("today.photoLog.librarySubtitle"),
            imageName: imageName,
            type: .balanced,
            calories: totals.calories,
            protein: totals.protein,
            carbs: totals.carbs,
            fats: totals.fats,
            fiber: totals.fiber,
            benefits: [],
            ingredients: ingredients,
            suggestedTime: suggestedTime,
            libraryKind: .meal,
            creationMode: .manual,
            servingGrams: servingGrams,
            localPhotoFilename: localPhotoFilename,
            localPhotoThumbnailFilename: localPhotoThumbnailFilename,
            barcode: barcode,
            nutritionDataSource: estimateKind == .database
                ? (barcodeDataSource ?? .photoCatalog)
                : .photoAIEstimate,
            libraryPeriodRaw: MealLibraryPeriod.period(
                at: Calendar.current.component(.hour, from: Date())
            ).rawValue
        )
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    private static func uniquedTitle(_ title: String, existing: [Meals]) -> String {
        let lowered = title.lowercased()
        guard existing.contains(where: { $0.title.lowercased() == lowered }) else {
            return title
        }
        var index = 2
        while existing.contains(where: { $0.title.lowercased() == "\(title) \(index)".lowercased() }) {
            index += 1
        }
        return "\(title) \(index)"
    }

    /// Selected Today day + clock time when the user confirmed the log.
    static func activityDate(
        forSelectedDay day: Date,
        loggedAt now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let start = calendar.startOfDay(for: day)
        let parts = calendar.dateComponents([.hour, .minute, .second], from: now)
        return calendar.date(
            bySettingHour: parts.hour ?? 0,
            minute: parts.minute ?? 0,
            second: parts.second ?? 0,
            of: start
        ) ?? now
    }

    static func clockTimeString(from date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func submitKey(for draft: PhotoFoodLogDraft) -> String {
        let name = draft.mealName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let grams = Int(draft.scaledComponents.reduce(0) { $0 + $1.grams }.rounded())
        let day = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: draft.logDate))
        return "\(name)|\(draft.mealSlot.rawValue)|\(grams)|\(day)|\(draft.captureMethod.rawValue)"
    }
}
