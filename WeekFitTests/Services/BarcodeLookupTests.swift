import XCTest
@testable import WeekFit

final class OpenFoodFactsBarcodeProviderTests: XCTestCase {

    func testParseCompleteProductUsesPer100gValues() throws {
        let json = """
        {
          "status": 1,
          "product": {
            "product_name": "Nutella",
            "brands": "Ferrero,Nutella",
            "serving_quantity": 20,
            "nutriments": {
              "energy-kcal_100g": 539,
              "energy-kcal_serving": 108,
              "proteins_100g": 6.3,
              "carbohydrates_100g": 57.5,
              "fat_100g": 30.9,
              "fiber_100g": 0
            },
            "image_front_url": "https://images.openfoodfacts.org/images/products/301/762/042/2003/front_en.200.jpg"
          }
        }
        """

        let result = try XCTUnwrap(
            OpenFoodFactsBarcodeProvider.parseResponse(Data(json.utf8), barcode: "3017620422003")
        )

        XCTAssertEqual(result.status, .found)
        XCTAssertEqual(result.provider, .openFoodFacts)
        XCTAssertEqual(result.calories, 539)
        XCTAssertEqual(result.protein, 6)
        XCTAssertEqual(result.servingGrams, 100)
        XCTAssertEqual(result.packageGrams, 20)
        XCTAssertEqual(result.displayName, "Ferrero — Nutella")
    }

    func testParseIgnoresNonPer100gFallbackKeys() {
        let json = """
        {
          "status": 1,
          "product": {
            "product_name": "Snack",
            "nutriments": {
              "energy-kcal": 120,
              "proteins": 3,
              "carbohydrates": 15,
              "fat": 4
            }
          }
        }
        """

        let result = OpenFoodFactsBarcodeProvider.parseResponse(Data(json.utf8), barcode: "123")

        XCTAssertEqual(result?.status, .partial)
        XCTAssertNil(result?.calories)
        XCTAssertNil(result?.protein)
        XCTAssertEqual(result?.name, "Snack")
    }

    func testParseMissingProductReturnsNil() {
        let json = """
        {
          "status": 0,
          "status_verbose": "product not found"
        }
        """

        XCTAssertNil(OpenFoodFactsBarcodeProvider.parseResponse(Data(json.utf8), barcode: "4810268060670"))
    }
}

final class USDABarcodeProviderTests: XCTestCase {

    func testParseBrandedFoodUsesServingGrams() throws {
        let json = """
        {
          "foods": [
            {
              "description": "WHOLE GRAIN CHEERIOS",
              "brandOwner": "General Mills",
              "gtinUpc": "0001600012345",
              "servingSize": 30,
              "servingSizeUnit": "g",
              "foodNutrients": [
                { "nutrientId": 1008, "nutrientName": "Energy", "value": 110 },
                { "nutrientId": 1003, "nutrientName": "Protein", "value": 3 },
                { "nutrientId": 1005, "nutrientName": "Carbohydrate, by difference", "value": 22 },
                { "nutrientId": 1004, "nutrientName": "Total lipid (fat)", "value": 2 }
              ]
            }
          ]
        }
        """

        let result = try XCTUnwrap(
            USDABarcodeProvider.parseResponse(Data(json.utf8), barcode: "0001600012345")
        )

        XCTAssertEqual(result.status, .found)
        XCTAssertEqual(result.provider, .usda)
        XCTAssertEqual(result.servingGrams, 30)
        XCTAssertEqual(result.basis, .perServing)
        XCTAssertEqual(result.calories, 110)
        XCTAssertEqual(result.protein, 3)
    }
}

final class BarcodeNormalizationTests: XCTestCase {

    func testGTIN13PadsEAN8() {
        XCTAssertEqual(BarcodeNormalization.gtin13(from: "12345678"), "0000000123456")
    }

    func testMatchesIgnoresLeadingZeros() {
        XCTAssertTrue(BarcodeNormalization.matches("1600012345", "0001600012345"))
    }
}

final class FoodPhotoNutritionEstimateApplyTests: XCTestCase {

    @MainActor
    func testApplyIfPossibleUsesServingGramsFromEstimate() {
        let estimate = FoodPhotoNutritionEstimate(
            source: .barcode,
            dataSource: .usda,
            barcode: "0001600012345",
            name: "Cheerios",
            calories: 110,
            protein: 3,
            carbs: 22,
            fats: 2,
            fiber: 0,
            servingGrams: 30,
            packageGrams: 30,
            productImageURL: nil
        )

        var name = ""
        var servingGrams = "100"
        var calories = ""
        var protein = ""
        var carbs = ""
        var fats = ""
        var fiber = ""

        XCTAssertTrue(
            estimate.applyIfPossible(
                name: &name,
                servingGrams: &servingGrams,
                calories: &calories,
                protein: &protein,
                carbs: &carbs,
                fats: &fats,
                fiber: &fiber
            )
        )

        XCTAssertEqual(name, "Cheerios")
        XCTAssertEqual(servingGrams, "30")
        XCTAssertEqual(calories, "110")
    }

    @MainActor
    func testApplyIfPossibleDoesNotOverwriteExistingValues() {
        let estimate = FoodPhotoNutritionEstimate(
            source: .barcode,
            dataSource: .openFoodFacts,
            barcode: "3017620422003",
            name: "Nutella",
            calories: 539,
            protein: 6,
            carbs: 57,
            fats: 31,
            fiber: 0,
            servingGrams: 100,
            packageGrams: nil,
            productImageURL: nil
        )

        var name = "Custom"
        var servingGrams = "45"
        var calories = "200"
        var protein = "10"
        var carbs = "20"
        var fats = "8"
        var fiber = "3"

        XCTAssertFalse(
            estimate.applyIfPossible(
                name: &name,
                servingGrams: &servingGrams,
                calories: &calories,
                protein: &protein,
                carbs: &carbs,
                fats: &fats,
                fiber: &fiber
            )
        )

        XCTAssertEqual(name, "Custom")
        XCTAssertEqual(calories, "200")
    }
}

final class QuickLogBarcodeScalingTests: XCTestCase {

    func test45GramPortionScalesFrom100GramServing() {
        let meal = Meals(
            id: "meal_barcode",
            title: "Protein Bar",
            subtitle: "100g serving",
            imageName: "meal-chicken",
            type: .balanced,
            calories: 400,
            protein: 20,
            carbs: 40,
            fats: 10,
            fiber: 5,
            benefits: [],
            ingredients: [],
            servingGrams: 100,
            barcode: "4810268060670",
            nutritionDataSource: .openFoodFacts
        )

        let profile = QuickLogNutritionProfile.from(meal: meal)
        let selection = QuickLogSelection(
            portions: 1,
            mode: .grams,
            alternateAmount: 45
        )

        let nutrition = QuickLogServingMath.nutrition(for: profile, selection: selection)

        XCTAssertEqual(nutrition.calories, 180)
        XCTAssertEqual(nutrition.protein, 9)
        XCTAssertEqual(nutrition.carbs, 18)
        XCTAssertEqual(nutrition.fats, 5)
        XCTAssertEqual(nutrition.fiber, 2)
        XCTAssertEqual(nutrition.grams, 45)
    }
}
