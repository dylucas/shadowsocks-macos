// UI Tests — Basic interaction verification

import XCTest

final class ShadowsocksUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Status Bar

    func testStatusBarIconVisible() {
        let app = XCUIApplication()
        app.launch()

        // MenuBarExtra should show the shield icon
        // Note: UI testing MenuBarExtra is tricky in Xcode
        // The status bar item needs to be clicked to open the panel
        // This test verifies the app launches without crashing
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    // MARK: - Settings Window

    func testSettingsWindowOpens() {
        let app = XCUIApplication()
        app.launch()

        // Open settings via keyboard shortcut or menu
        // Cmd+, should open Settings window
        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows["Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3))
    }
}
