import XCTest

final class SwipeUITests: XCTestCase {
    let steak = Seed(name: "Ribeye Steak", category: "meat_raw")

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFreezeMovesItemToFreezer() throws {
        let app = try launch(modes: "freezer", items: [steak])
        let row = app.row("Ribeye Steak")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("3 days left"))

        row.swipeToActions()
        app.buttons["Freeze"].tap()
        XCTAssertTrue(app.row("120 days left").waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Frozen"))
        XCTAssertTrue(row.label.contains("Freezer"))
    }

    @MainActor
    func testThawMovesItemBackWithThawedDays() throws {
        var frozen = steak
        frozen.location = "freezer"
        let app = try launch(modes: "freezer", items: [frozen])
        let row = app.row("Ribeye Steak")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("120 days left"))

        row.swipeToActions()
        app.buttons["Thaw"].tap()
        XCTAssertTrue(app.row("Thawed").waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("3 days left"))
        XCTAssertFalse(row.label.contains("Freezer"))
    }

    @MainActor
    func testFreezingAnExpiredItemAsksFirst() throws {
        let app = try launch(modes: "freezer", items: [
            Seed(name: "Chicken Thighs", category: "poultry_raw", addedDaysAgo: 5, expiresInDays: -1),
        ])
        let row = app.row("Chicken Thighs")
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        row.swipeToActions()
        app.buttons["Freeze"].tap()
        XCTAssertTrue(app.staticTexts["Freeze anyway?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.text(containing: "Freezing won't make it safe").exists)
        /* iOS 26 shows the dialog as a popover with no Cancel button. Tapping outside it cancels. */
        app.otherElements["PopoverDismissRegion"].tap()
        XCTAssertTrue(app.staticTexts["Freeze anyway?"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Expired yesterday"))

        row.swipeToActions()
        app.buttons["Freeze"].tap()
        XCTAssertTrue(app.staticTexts["Freeze anyway?"].waitForExistence(timeout: 5))
        app.buttons["Freeze"].tap()
        XCTAssertTrue(app.row("270 days left").waitForExistence(timeout: 5))
    }

    @MainActor
    func testFreezingAPoorFreezerAsksFirst() throws {
        let app = try launch(modes: "freezer", items: [Seed(name: "Romaine Hearts", category: "produce_leafy")])
        let row = app.row("Romaine Hearts")
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        row.swipeToActions()
        app.buttons["Freeze"].tap()
        XCTAssertTrue(app.staticTexts["Freeze anyway?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.text(containing: "doesn't freeze well").exists)
    }

    @MainActor
    func testNoFreezeButtonWhenFreezerIsOff() throws {
        let app = try launch(items: [steak])
        let row = app.row("Ribeye Steak")
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        row.swipeToActions()
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Freeze"].exists)
    }

    @MainActor
    func testDeleteRemovesTheItem() throws {
        let app = try launch(items: [steak])
        let row = app.row("Ribeye Steak")
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        row.swipeToActions()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Your fridge is empty"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFullSwipeDeletes() throws {
        let app = try launch(modes: "freezer", items: [steak])
        let row = app.row("Ribeye Steak")
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: -0.5, dy: 0.5)))
        XCTAssertTrue(app.staticTexts["Your fridge is empty"].waitForExistence(timeout: 5))
    }
}
