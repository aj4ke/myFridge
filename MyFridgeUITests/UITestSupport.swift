import XCTest

/** Mirrors UITestLaunch.Seed in the app. Days are counted from today. */
struct Seed: Encodable {
    var name: String
    var category: String
    var location: String?
    var addedDaysAgo: Int?
    var expiresInDays: Int?
}

/** Mirrors UITestLaunch.ImportSeed. storage is a ParsedStorage case name. */
struct ImportSeed: Encodable {
    var name: String
    var category: String
    var storage: String
}

extension XCTestCase {
    /**
     * Starts the app with a fresh in-memory store holding `items`.
     * reset: false keeps the settings from the last launch.
     */
    @MainActor
    func launch(modes: String = "", items: [Seed] = [], imports: [ImportSeed]? = nil, reset: Bool = true) throws -> XCUIApplication {
        #if !targetEnvironment(simulator)
        throw XCTSkip("UI tests reset the app's settings, so they only run in the simulator.")
        #else
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + (reset ? ["-uiTestingReset"] : [])
        app.launchEnvironment["UITEST_MODES"] = modes
        app.launchEnvironment["UITEST_ITEMS"] = String(decoding: try JSONEncoder().encode(items), as: UTF8.self)
        if let imports {
            app.launchEnvironment["UITEST_IMPORT"] = String(decoding: try JSONEncoder().encode(imports), as: UTF8.self)
        }
        app.launch()
        return app
        #endif
    }
}

/** The Reminders access prompt belongs to SpringBoard, not the app. */
@MainActor
func answerRemindersPrompt(allow: Bool) {
    let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 10))
    alert.buttons[allow ? "Allow" : "Don’t Allow"].tap()
}

/** Opens the Reminders app on its lists. It shows a welcome screen the first time and can reopen the last list. */
@MainActor
func launchReminders() -> XCUIApplication {
    let reminders = XCUIApplication(bundleIdentifier: "com.apple.reminders")
    reminders.launch()
    if reminders.buttons["Continue"].waitForExistence(timeout: 3) {
        reminders.buttons["Continue"].tap()
    }
    if reminders.buttons["BackButton"].exists {
        reminders.buttons["BackButton"].tap()
    }
    XCTAssertTrue(reminders.buttons["Add List"].waitForExistence(timeout: 5))
    return reminders
}

extension XCUIApplication {
    /** A row in a Reminders app list. Its label starts with the title, then the status, date and notes. */
    func reminder(_ title: String) -> XCUIElement {
        cells.matching(NSPredicate(format: "label BEGINSWITH %@", title + ",")).firstMatch
    }

    /** List and review rows are buttons whose label joins every text in the row. */
    func row(_ name: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    func toggle(_ label: String) -> XCUIElement {
        switches.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    func text(containing text: String) -> XCUIElement {
        staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func openSettings() {
        buttons["Settings"].tap()
        XCTAssertTrue(navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    func closeSettings() {
        buttons["Done"].tap()
    }

    func openAddForm() {
        buttons["Add"].tap()
        buttons["Add Manually"].tap()
        XCTAssertTrue(navigationBars["Add Item"].waitForExistence(timeout: 5))
    }

    func pickCategory(_ name: String) {
        buttons["Category"].tap()
        buttons[name].tap()
    }
}

extension XCUIElement {
    var isOn: Bool {
        value as? String == "1"
    }

    /** Taps the switch itself. Tapping the middle of a Form row lands on the label, which doesn't toggle. */
    func flip() {
        coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }

    func swipeToActions() {
        swipeLeft()
    }
}
