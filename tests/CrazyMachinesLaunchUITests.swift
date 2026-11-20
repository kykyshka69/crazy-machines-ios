import XCTest

final class CrazyMachinesLaunchUITests: XCTestCase {
    func testOriginalLevelsImportControlsWithoutBundledAssets() {
        let app = XCUIApplication()
        app.launch()
        let originalLevels = app.tabBars.buttons["Original levels"]
        XCTAssertTrue(originalLevels.waitForExistence(timeout: 20))
        originalLevels.tap()
        // Import controls must be available even when the user has not
        // supplied any copyrighted original-game files.
        XCTAssertTrue(app.buttons["Import original levels"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Import entire exported levels folder"].exists)
    }

    func testLaunchAndSwitchTabs() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Playground"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.tabBars.buttons["Original levels"].exists)
        app.tabBars.buttons["Original levels"].tap()
        XCTAssertTrue(app.tabBars.buttons["Original levels"].isSelected)
        app.tabBars.buttons["3D Preview"].tap()
        XCTAssertTrue(app.tabBars.buttons["3D Preview"].isSelected)
        XCTAssertTrue(app.otherElements["cm.3d-preview.canvas"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Playground"].tap()
        XCTAssertTrue(app.tabBars.buttons["Playground"].isSelected)
    }
}
