import XCTest

final class ImportReviewUITests: XCTestCase {
    let imports = [
        ImportSeed(name: "Organic Whole Milk", category: "dairy_milk", storage: "fridge"),
        ImportSeed(name: "Sourdough Bread", category: "bread_bakery", storage: "pantry"),
        ImportSeed(name: "Frozen Waffles", category: "frozen_meals", storage: "freezer"),
        ImportSeed(name: "Paper Towels", category: "other", storage: "notFood"),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTurnedOffLocationsStartHidden() throws {
        let app = try launch(modes: "pantry", imports: imports)
        XCTAssertTrue(app.navigationBars["Review Import"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.row("Organic Whole Milk").exists)
        XCTAssertTrue(app.row("Sourdough Bread").label.contains("Pantry"))
        XCTAssertFalse(app.row("Frozen Waffles").exists)
        XCTAssertFalse(app.row("Paper Towels").exists)

        app.toggle("Show 2 other items").flip()
        XCTAssertTrue(app.row("Frozen Waffles").waitForExistence(timeout: 5))
        XCTAssertTrue(app.row("Frozen Waffles").label.contains("Freezer is off"))
        XCTAssertTrue(app.row("Paper Towels").label.contains("Not food"))

        app.buttons["Add 2 Items"].tap()
        XCTAssertTrue(app.navigationBars["Review Import"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.row("Sourdough Bread").waitForExistence(timeout: 5))
        XCTAssertTrue(app.row("Sourdough Bread").label.contains("Pantry"))
        XCTAssertTrue(app.row("Organic Whole Milk").exists)
        XCTAssertFalse(app.row("Frozen Waffles").exists)
    }

    @MainActor
    func testFrozenImportsGoToTheFreezer() throws {
        let app = try launch(modes: "pantry,freezer", imports: imports)
        XCTAssertTrue(app.navigationBars["Review Import"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.row("Frozen Waffles").label.contains("Freezer"))
        XCTAssertTrue(app.toggle("Show 1 other item").exists)

        app.buttons["Add 3 Items"].tap()
        let waffles = app.row("Frozen Waffles")
        XCTAssertTrue(waffles.waitForExistence(timeout: 5))
        XCTAssertTrue(waffles.label.contains("Freezer"))
        XCTAssertTrue(waffles.label.contains("90 days left"))
    }
}
