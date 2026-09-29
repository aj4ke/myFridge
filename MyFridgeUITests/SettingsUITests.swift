import XCTest

final class SettingsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDefaultModeHasNoFilterOrBadges() throws {
        let app = try launch(items: [Seed(name: "Whole Milk", category: "dairy_milk")])
        XCTAssertTrue(app.row("Whole Milk").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Filter"].exists)
        XCTAssertFalse(app.row("Whole Milk").label.contains("Fridge"))
    }

    @MainActor
    func testFilterButtonFollowsModes() throws {
        let app = try launch()
        XCTAssertFalse(app.buttons["Filter"].exists)

        app.openSettings()
        app.toggle("Pantry").flip()
        app.closeSettings()
        XCTAssertTrue(app.buttons["Filter"].waitForExistence(timeout: 5))

        app.openSettings()
        app.toggle("Pantry").flip()
        app.closeSettings()
        XCTAssertTrue(app.buttons["Filter"].waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testTogglesPersistAcrossLaunches() throws {
        var app = try launch()
        app.openSettings()
        app.toggle("Freezer").flip()
        XCTAssertTrue(app.toggle("Freezer").isOn)
        app.terminate()

        app = try launch(reset: false)
        app.openSettings()
        XCTAssertTrue(app.toggle("Freezer").isOn)
        XCTAssertFalse(app.toggle("Pantry").isOn)
    }

    @MainActor
    func testTurningOffALocationAsksBeforeHidingItems() throws {
        let app = try launch(modes: "pantry", items: [Seed(name: "Sourdough Bread", category: "bread_bakery", location: "pantry")])
        XCTAssertTrue(app.row("Sourdough Bread").waitForExistence(timeout: 5))
        XCTAssertTrue(app.row("Sourdough Bread").label.contains("Pantry"))

        app.openSettings()
        app.toggle("Pantry").flip()
        XCTAssertTrue(app.alerts["Hide 1 pantry item?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.toggle("Pantry").isOn)

        app.toggle("Pantry").flip()
        app.alerts.buttons["Hide Items"].tap()
        XCTAssertFalse(app.toggle("Pantry").isOn)
        app.closeSettings()
        XCTAssertTrue(app.row("Sourdough Bread").waitForNonExistence(timeout: 5))

        app.openSettings()
        app.toggle("Pantry").flip()
        app.closeSettings()
        XCTAssertTrue(app.row("Sourdough Bread").waitForExistence(timeout: 5))
    }

    @MainActor
    func testClearAllDeletesEveryItem() throws {
        let app = try launch(items: [
            Seed(name: "Whole Milk", category: "dairy_milk"),
            Seed(name: "Large Eggs", category: "eggs"),
        ])
        app.openSettings()
        app.buttons["Clear All Items"].tap()
        XCTAssertTrue(app.alerts["Delete all 2 items?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Delete All"].tap()
        XCTAssertFalse(app.buttons["Clear All Items"].isEnabled)
        app.closeSettings()
        XCTAssertTrue(app.staticTexts["Your fridge is empty"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFilterShowsOneLocationAndResetsWhenItTurnsOff() throws {
        let app = try launch(modes: "pantry,freezer", items: [
            Seed(name: "Whole Milk", category: "dairy_milk"),
            Seed(name: "Sourdough Bread", category: "bread_bakery", location: "pantry"),
        ])
        XCTAssertTrue(app.row("Whole Milk").waitForExistence(timeout: 5))

        app.buttons["Filter"].tap()
        app.buttons["Pantry"].tap()
        XCTAssertTrue(app.row("Sourdough Bread").waitForExistence(timeout: 5))
        XCTAssertFalse(app.row("Whole Milk").exists)

        app.buttons["Filter"].tap()
        app.buttons["Freezer"].tap()
        XCTAssertTrue(app.staticTexts["Nothing here yet"].waitForExistence(timeout: 5))

        app.openSettings()
        app.toggle("Freezer").flip()
        app.closeSettings()
        XCTAssertTrue(app.row("Whole Milk").waitForExistence(timeout: 5))
        XCTAssertTrue(app.row("Sourdough Bread").exists)
    }
}
