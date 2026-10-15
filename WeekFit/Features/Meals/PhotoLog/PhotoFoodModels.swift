import Foundation
import UIKit

/// How a logged diary entry's macros were derived.
enum PhotoFoodEstimateKind: String, Codable, Sendable, Equatable {
    case database
    case estimated
    case mixed
}

enum PhotoFoodCaptureMethod: String, Sendable, Equatable {
    case camera
    case library
    case barcode
}

/// One recognized / editable food component on the confirmation sheet.
struct PhotoFoodComponent: Identifiable, Codable, Sendable, Equatable {
    var id: String
    var displayName: String
    var grams: Double
    /// Catalog ingredient id when matched; nil when AI-only estimate.
    var catalogIngredientId: String?
    var preparation: String?
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatsPer100g: Double
    var fiberPer100g: Double
    var nutritionSource: NutritionDataSource
    /// True when macros came from the vision model rather than catalog/DB.
    var isAIEstimated: Bool

    var calories: Int {
        Int((caloriesPer100g * grams / 100.0).rounded())
    }

    var protein: Int {
        Int((proteinPer100g * grams / 100.0).rounded())
    }

    var carbs: Int {
        Int((carbsPer100g * grams / 100.0).rounded())
    }

    var fats: Int {
        Int((fatsPer100g * grams / 100.0).rounded())
    }

    var fiber: Int {
        Int((fiberPer100g * grams / 100.0).rounded())
    }
}

struct PhotoFoodNutritionTotals: Equatable, Sendable {
    var calories: Int
    var protein: Int
    var carbs: Int
    var fats: Int
    var fiber: Int

    static let zero = PhotoFoodNutritionTotals(
        calories: 0,
        protein: 0,
        carbs: 0,
        fats: 0,
        fiber: 0
    )

    static func + (lhs: PhotoFoodNutritionTotals, rhs: PhotoFoodNutritionTotals) -> PhotoFoodNutritionTotals {
        PhotoFoodNutritionTotals(
            calories: lhs.calories + rhs.calories,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            fats: lhs.fats + rhs.fats,
            fiber: lhs.fiber + rhs.fiber
        )
    }

    func scaled(by factor: Double) -> PhotoFoodNutritionTotals {
        let f = max(factor, 0)
        return PhotoFoodNutritionTotals(
            calories: Int((Double(calories) * f).rounded()),
            protein: Int((Double(protein) * f).rounded()),
            carbs: Int((Double(carbs) * f).rounded()),
            fats: Int((Double(fats) * f).rounded()),
            fiber: Int((Double(fiber) * f).rounded())
        )
    }
}

/// Immutable snapshot persisted on `PlannedActivity.nutritionSnapshotJSON`.
struct PhotoFoodDiarySnapshot: Codable, Sendable, Equatable {
    var mealName: String
    var mealSlotRaw: String
    var components: [PhotoFoodComponent]
    var portionMultiplier: Double
    var totals: PhotoFoodNutritionTotalsCodable
    var estimateKind: PhotoFoodEstimateKind
    var captureMethod: String
    var libraryMealId: String?
    var loggedAt: Date

    struct PhotoFoodNutritionTotalsCodable: Codable, Sendable, Equatable {
        var calories: Int
        var protein: Int
        var carbs: Int
        var fats: Int
        var fiber: Int

        init(_ totals: PhotoFoodNutritionTotals) {
            calories = totals.calories
            protein = totals.protein
            carbs = totals.carbs
            fats = totals.fats
            fiber = totals.fiber
        }

        var asTotals: PhotoFoodNutritionTotals {
            PhotoFoodNutritionTotals(
                calories: calories,
                protein: protein,
                carbs: carbs,
                fats: fats,
                fiber: fiber
            )
        }
    }
}

enum PhotoFoodRecognitionError: Error, Equatable, Sendable {
    case notConfigured
    /// Firebase Authentication missing / Anonymous disabled for this Firebase project.
    case authUnavailable
    case unauthorized
    /// Cloud AI photo analysis requires an active paid WeekFit subscription.
    case subscriptionRequired
    case network
    case rateLimited
    case invalidImage
    case imageTooLarge
    case noFoodDetected
    case invalidResponse
    case providerFailure
    case unavailable
    case timedOut
    case server(String)
    case cancelled

    var userMessageKey: String {
        switch self {
        case .notConfigured:
            return "today.photoLog.error.notConfigured"
        case .authUnavailable:
            return "today.photoLog.error.authUnavailable"
        case .unauthorized:
            return "today.photoLog.error.unauthorized"
        case .subscriptionRequired:
            return "today.photoLog.error.subscriptionRequired"
        case .network:
            return "today.photoLog.error.network"
        case .rateLimited:
            return "today.photoLog.error.rateLimited"
        case .invalidImage:
            return "today.photoLog.error.invalidImage"
        case .imageTooLarge:
            return "today.photoLog.error.imageTooLarge"
        case .noFoodDetected:
            return "today.photoLog.error.noFood"
        case .invalidResponse:
            return "today.photoLog.error.invalidResponse"
        case .providerFailure:
            return "today.photoLog.error.provider"
        case .unavailable:
            return "today.photoLog.error.unavailable"
        case .timedOut:
            return "today.photoLog.error.timedOut"
        case .server:
            return "today.photoLog.error.generic"
        case .cancelled:
            return "today.photoLog.error.cancelled"
        }
    }
}

/// Editable confirmation draft before logging.
@Observable
final class PhotoFoodLogDraft {
    var mealName: String
    var mealSlot: WeekFitMealSlot
    var logDate: Date
    var components: [PhotoFoodComponent]
    /// Quick portion control — 1.0 = recognized amounts.
    var portionMultiplier: Double
    var clarificationQuestion: String?
    var clarificationAnswer: String
    var assumptions: [String]
    var uncertainties: [String]
    var saveToLibrary: Bool
    var captureMethod: PhotoFoodCaptureMethod
    var previewImage: UIImage?
    var diaryPhotoFilename: String?
    var barcode: String?
    var barcodeDataSource: NutritionDataSource?
    /// Always true for photo AI path — macros are estimates, never DB-verified.
    var showsEstimatedNutrition: Bool

    init(
        mealName: String,
        mealSlot: WeekFitMealSlot,
        logDate: Date,
        components: [PhotoFoodComponent],
        portionMultiplier: Double = 1.0,
        clarificationQuestion: String? = nil,
        clarificationAnswer: String = "",
        assumptions: [String] = [],
        uncertainties: [String] = [],
        saveToLibrary: Bool = false,
        captureMethod: PhotoFoodCaptureMethod,
        previewImage: UIImage? = nil,
        diaryPhotoFilename: String? = nil,
        barcode: String? = nil,
        barcodeDataSource: NutritionDataSource? = nil,
        showsEstimatedNutrition: Bool = true
    ) {
        self.mealName = mealName
        self.mealSlot = mealSlot
        self.logDate = logDate
        self.components = components
        self.portionMultiplier = portionMultiplier
        self.clarificationQuestion = clarificationQuestion
        self.clarificationAnswer = clarificationAnswer
        self.assumptions = assumptions
        self.uncertainties = uncertainties
        self.saveToLibrary = saveToLibrary
        self.captureMethod = captureMethod
        self.previewImage = previewImage
        self.diaryPhotoFilename = diaryPhotoFilename
        self.barcode = barcode
        self.barcodeDataSource = barcodeDataSource
        self.showsEstimatedNutrition = showsEstimatedNutrition
    }

    var scaledComponents: [PhotoFoodComponent] {
        components.map { component in
            var copy = component
            copy.grams = max(component.grams * portionMultiplier, 0)
            return copy
        }
    }

    var totals: PhotoFoodNutritionTotals {
        PhotoFoodNutritionCalculator.totals(for: scaledComponents)
    }

    var estimateKind: PhotoFoodEstimateKind {
        PhotoFoodNutritionCalculator.estimateKind(for: scaledComponents)
    }

    var canLog: Bool {
        let name = mealName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        guard !scaledComponents.isEmpty else { return false }
        return totals.calories > 0 || totals.protein > 0 || totals.carbs > 0 || totals.fats > 0
    }
}
