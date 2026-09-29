import XCTest

/** Checks the MyFridge list in the real Reminders app. Each test starts by resetting Reminders access. */
final class RemindersUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMyFridgeListFollowsTheAppUntilTurnedOff() throws {
        XCUIApplication().resetAuthorizationStatus(for: .reminders)
        let app = try launch(modes: "freezer", items: [
            Seed(name: "Ground Beef", category: "meat_raw"),
            Seed(name: "Large Eggs", category: "eggs"),
        ])
        app.openSettings()
        app.toggle("Reminders").flip()
        answerRemindersPrompt(allow: true)
        XCTAssertTrue(app.toggle("Reminders").wait(for: \.isOn, toEqual: true, timeout: 10))
        app.closeSettings()

        app.row("Large Eggs").swipeToActions()
        app.buttons["Delete"].tap()
        app.row("Ground Beef").swipeToActions()
        app.buttons["Freeze"].tap()
        XCTAssertTrue(app.row("Ground Beef").label.contains("Freezer"))

        var reminders = launchReminders()
        reminders.staticTexts["MyFridge"].tap()
        XCTAssertTrue(reminders.reminder("Ground Beef").waitForExistence(timeout: 10))
        XCTAssertTrue(reminders.reminder("Ground Beef").label.hasSuffix("Freezer"))
        XCTAssertFalse(reminders.reminder("Large Eggs").exists)

        app.activate()
        XCTAssertTrue(app.buttons["Settings"].wait(for: \.isHittable, toEqual: true, timeout: 10))
        app.openSettings()
        app.toggle("Reminders").flip()
        XCTAssertTrue(app.alerts["Delete the MyFridge list?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Delete List"].tap()
        XCTAssertFalse(app.toggle("Reminders").isOn)

        reminders = launchReminders()
        XCTAssertFalse(reminders.staticTexts["MyFridge"].exists)
    }

    @MainActor
    func testTurningOffCanBeCancelled() throws {
        XCUIApplication().resetAuthorizationStatus(for: .reminders)
        let app = try launch(items: [Seed(name: "Whole Milk", category: "dairy_milk")])
        app.openSettings()
        app.toggle("Reminders").flip()
        answerRemindersPrompt(allow: true)
        XCTAssertTrue(app.toggle("Reminders").wait(for: \.isOn, toEqual: true, timeout: 10))

        app.toggle("Reminders").flip()
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.toggle("Reminders").isOn)

        app.toggle("Reminders").flip()
        app.alerts.buttons["Delete List"].tap()
        XCTAssertFalse(app.toggle("Reminders").isOn)
    }

    /** Access is reset at the end, so the simulator isn't left denying Reminders. */
    @MainActor
    func testStaysOffWithoutAccess() throws {
        XCUIApplication().resetAuthorizationStatus(for: .reminders)
        addTeardownBlock { @MainActor in
            XCUIApplication().resetAuthorizationStatus(for: .reminders)
        }
        let app = try launch()
        app.openSettings()
        app.toggle("Reminders").flip()
        answerRemindersPrompt(allow: false)
        XCTAssertTrue(app.alerts["Allow Reminders Access"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.buttons["Open Settings"].exists)
        app.alerts.buttons["Cancel"].tap()
        XCTAssertFalse(app.toggle("Reminders").isOn)
    }
}
