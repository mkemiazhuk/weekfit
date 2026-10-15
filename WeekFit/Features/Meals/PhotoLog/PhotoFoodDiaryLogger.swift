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

        let activityDate = dateForSlot(draft.logDate, slot: draft.mealSlot)
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
        ProductAnalytics.foodLoggingCompleted(method: method, source: analyticsSource)
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

    @MainActor
    private static func makeLibraryMeal(
        from draft: PhotoFoodLogDraft,
        existingMeals: [Meals]
    ) throws -> Meals {
        let title = draft.mealName.trimmingCharacters(in: .whitespacesAndNewlines)
        let uniqueTitle = uniquedTitle(title, existing: existingMeals)
        let totals = draft.totals
        let servingGrams = max(
            Int(draft.scaledComponents.reduce(0) { $0 + $1.grams }.rounded()),
            1
        )

        var localPhotoFilename: String?
        var localPhotoThumbnailFilename: String?
        if let preview = draft.previewImage,
           let photoSet = try? MealPhotoStore.savePhotoSet(preview) {
            localPhotoFilename = photoSet.originalFilename
            localPhotoThumbnailFilename = photoSet.thumbnailFilename
        }

        let ingredients: [MealsIngredient] = draft.scaledComponents.map { component in
            MealsIngredient(
                name: component.displayName,
                amount: "\(Int(component.grams.rounded())) g"
            )
        }

        return Meals(
            id: "photo_meal_\(UUID().uuidString)",
            title: uniqueTitle,
            subtitle: WeekFitLocalizedString("today.photoLog.librarySubtitle"),
            imageName: localPhotoThumbnailFilename ?? localPhotoFilename ?? "",
            type: .balanced,
            calories: totals.calories,
            protein: totals.protein,
            carbs: totals.carbs,
            fats: totals.fats,
            fiber: totals.fiber,
            benefits: [],
            ingredients: ingredients,
            suggestedTime: suggestedTime(for: draft.mealSlot),
            libraryKind: .meal,
            creationMode: .manual,
            servingGrams: servingGrams,
            localPhotoFilename: localPhotoFilename,
            localPhotoThumbnailFilename: localPhotoThumbnailFilename,
            barcode: draft.barcode,
            nutritionDataSource: draft.estimateKind == .database
                ? (draft.barcodeDataSource ?? .photoCatalog)
                : .photoAIEstimate,
            libraryPeriodRaw: MealLibraryPeriod.period(
                at: Calendar.current.component(.hour, from: draft.logDate)
            ).rawValue
        )
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

    private static func suggestedTime(for slot: WeekFitMealSlot) -> String {
        switch slot {
        case .breakfast: return "08:30"
        case .lunch: return "13:00"
        case .snack: return "16:00"
        case .dinner: return "19:00"
        }
    }

    private static func dateForSlot(_ day: Date, slot: WeekFitMealSlot) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = .current
        let start = calendar.startOfDay(for: day)
        let hourMinute: (Int, Int) = {
            switch slot {
            case .breakfast: return (8, 30)
            case .lunch: return (13, 0)
            case .snack: return (16, 0)
            case .dinner: return (19, 0)
            }
        }()
        return calendar.date(
            bySettingHour: hourMinute.0,
            minute: hourMinute.1,
            second: 0,
            of: start
        ) ?? day
    }

    private static func submitKey(for draft: PhotoFoodLogDraft) -> String {
        let name = draft.mealName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let grams = Int(draft.scaledComponents.reduce(0) { $0 + $1.grams }.rounded())
        let day = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: draft.logDate))
        return "\(name)|\(draft.mealSlot.rawValue)|\(grams)|\(day)|\(draft.captureMethod.rawValue)"
    }
}
