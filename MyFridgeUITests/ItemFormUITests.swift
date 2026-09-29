import XCTest

final class ItemFormUITests: XCTestCase {
    let steak = Seed(name: "Ribeye Steak", category: "meat_raw")

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFrozenCategoryFreezesANewItem() throws {
        let app = try launch(modes: "freezer")
        app.openAddForm()
        app.textFields["Name"].tap()
        app.textFields["Name"].typeText("Cheese Pizza")
        app.pickCategory("Frozen Meals")

        XCTAssertTrue(app.toggle("Frozen").isOn)
        XCTAssertTrue(app.staticTexts["Frozen on"].exists)
        app.buttons["Save"].tap()

        let row = app.row("Cheese Pizza")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("360 days left"))
        XCTAssertTrue(row.label.contains("Freezer"))
    }

    @MainActor
    func testTogglingFrozenBackRestoresTheItem() throws {
        let app = try launch(modes: "freezer", items: [steak])
        app.row("Ribeye Steak").tap()

        app.toggle("Frozen").flip()
        XCTAssertTrue(app.staticTexts["Frozen on"].waitForExistence(timeout: 5))
        app.toggle("Frozen").flip()
        XCTAssertTrue(app.staticTexts["Frozen on"].waitForNonExistence(timeout: 5))
        app.buttons["Save"].tap()

        let row = app.row("Ribeye Steak")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("3 days left"))
        XCTAssertFalse(row.label.contains("Frozen"))
    }

    @MainActor
    func testUnfreezingASavedItemThawsIt() throws {
        var frozen = steak
        frozen.location = "freezer"
        let app = try launch(modes: "freezer", items: [frozen])
        app.row("Ribeye Steak").tap()

        XCTAssertTrue(app.toggle("Frozen").isOn)
        app.toggle("Frozen").flip()
        app.buttons["Save"].tap()

        let row = app.row("Ribeye Steak")
        XCTAssertTrue(app.row("Thawed").waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("3 days left"))
    }

    @MainActor
    func testBreadGoesToThePantry() throws {
        let app = try launch(modes: "pantry")
        app.openAddForm()
        app.textFields["Name"].tap()
        app.textFields["Name"].typeText("Sourdough Bread")
        app.pickCategory("Bread & Bakery")

        XCTAssertTrue(app.buttons["Stored in"].exists)
        app.buttons["Save"].tap()

        let row = app.row("Sourdough Bread")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Pantry"))
        XCTAssertTrue(row.label.contains("14 days left"))
    }

    @MainActor
    func testFreezingAPoorFreezerShowsAWarning() throws {
        let app = try launch(modes: "freezer")
        app.openAddForm()
        app.textFields["Name"].tap()
        app.textFields["Name"].typeText("Romaine Hearts")
        app.pickCategory("Leafy Greens")

        app.toggle("Frozen").flip()
        XCTAssertTrue(app.text(containing: "doesn't freeze well").waitForExistence(timeout: 5))
    }

    @MainActor
    func testFreezingAnExpiredItemShowsAWarning() throws {
        let app = try launch(modes: "freezer", items: [
            Seed(name: "Chicken Thighs", category: "poultry_raw", addedDaysAgo: 5, expiresInDays: -1),
        ])
        app.row("Chicken Thighs").tap()

        app.toggle("Frozen").flip()
        XCTAssertTrue(app.text(containing: "Freezing won't make it safe").waitForExistence(timeout: 5))
    }

    @MainActor
    func testFreezerOffDisablesFrozenAndHidesItsCategories() throws {
        let app = try launch()
        app.openAddForm()

        XCTAssertFalse(app.toggle("Frozen").isEnabled)
        XCTAssertTrue(app.staticTexts["Turn on Freezer in Settings to freeze items."].exists)
        XCTAssertFalse(app.buttons["Stored in"].exists)

        app.buttons["Category"].tap()
        XCTAssertTrue(app.buttons["Leafy Greens"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Frozen Meals"].exists)
        XCTAssertFalse(app.buttons["Bread & Bakery"].exists)
    }

    @MainActor
    func testBothModesShowEveryCategory() throws {
        let app = try launch(modes: "pantry,freezer")
        app.openAddForm()

        XCTAssertTrue(app.toggle("Frozen").isEnabled)
        app.buttons["Category"].tap()
        XCTAssertTrue(app.buttons["Frozen Meals"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Bread & Bakery"].exists)
    }
}
