import XCTest
@testable import WeekFit

final class PlateLayoutEngineTests: XCTestCase {

    func testBreakfastBowl_nestsGarnishAboveBaseAndProtein() throws {
        let items = [
            MealBuilderImageItem(
                id: "base_oatmeal",
                imageName: "ingredient-oatmeal",
                visualSize: 95,
                visualDensity: 1.2,
                supportsStandalonePresentation: true,
                offsetX: -34,
                offsetY: 18,
                rotation: -5,
                zIndex: 1,
                grams: 80
            ),
            MealBuilderImageItem(
                id: "protein_eggs",
                imageName: "ingredient-eggs",
                visualSize: 80,
                visualDensity: 0.2,
                supportsStandalonePresentation: true,
                offsetX: 34,
                offsetY: 10,
                rotation: 7,
                zIndex: 3,
                grams: 120
            ),
            MealBuilderImageItem(
                id: "extra_blueberries",
                imageName: "ingredient-blueberries",
                visualSize: 60,
                visualDensity: 0.55,
                supportsStandalonePresentation: true,
                offsetX: 10,
                offsetY: -54,
                rotation: 0,
                zIndex: 5,
                grams: 60
            ),
        ]

        let layout = PlateLayoutEngine.layout(
            items: items,
            plateSize: 220,
            itemScale: 1,
            offsetScale: 0.82,
            mode: .detail
        )

        XCTAssertEqual(layout.count, 3)

        let base = try XCTUnwrap(layout.first { $0.item.id == "base_oatmeal" })
        let protein = try XCTUnwrap(layout.first { $0.item.id == "protein_eggs" })
        let garnish = try XCTUnwrap(layout.first { $0.item.id == "extra_blueberries" })

        XCTAssertEqual(base.category, .base)
        XCTAssertEqual(protein.category, .protein)
        XCTAssertEqual(garnish.category, .garnish)

        // Breakfast composition: base/protein lower, crown garnish higher.
        XCTAssertGreaterThan(base.offset.height, garnish.offset.height)
        XCTAssertGreaterThan(protein.offset.height, garnish.offset.height)
        XCTAssertLessThan(base.offset.width, protein.offset.width)
    }

    func testPourableExtra_mapsToSauceCategory() {
        let oil = MealBuilderImageItem(
            id: "extra_olive_oil",
            imageName: "ingredient-olive-oil",
            visualSize: 40,
            visualDensity: 0.4,
            supportsStandalonePresentation: false,
            offsetX: 40,
            offsetY: 10,
            rotation: 0,
            zIndex: 4,
            grams: 10
        )
        XCTAssertEqual(PlateLayoutEngine.category(for: oil), .sauce)
    }

    func testProteinBowl_placesVegetablesAboveBase() throws {
        let items = [
            MealBuilderImageItem(
                id: "base_rice",
                imageName: "ingredient-rice",
                visualSize: 100,
                visualDensity: 1.15,
                supportsStandalonePresentation: true,
                offsetX: -34,
                offsetY: 20,
                rotation: -6,
                zIndex: 1,
                grams: 150
            ),
            MealBuilderImageItem(
                id: "protein_chicken",
                imageName: "ingredient-chicken",
                visualSize: 90,
                visualDensity: 0.9,
                supportsStandalonePresentation: true,
                offsetX: 30,
                offsetY: 8,
                rotation: 5,
                zIndex: 3,
                grams: 160
            ),
            MealBuilderImageItem(
                id: "veg_broccoli",
                imageName: "ingredient-broccoli",
                visualSize: 70,
                visualDensity: 0.7,
                supportsStandalonePresentation: true,
                offsetX: -20,
                offsetY: -30,
                rotation: -4,
                zIndex: 2,
                grams: 100
            ),
        ]

        let layout = PlateLayoutEngine.layout(
            items: items,
            plateSize: 220,
            itemScale: 1,
            offsetScale: 0.82,
            mode: .detail
        )

        let base = try XCTUnwrap(layout.first { $0.item.id == "base_rice" })
        let veg = try XCTUnwrap(layout.first { $0.item.id == "veg_broccoli" })
        XCTAssertGreaterThan(base.offset.height, veg.offset.height)
    }
}
