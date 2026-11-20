import XCTest

final class CrazyMachinesLaunchUITests: XCTestCase {
    func testOriginalLevelsImportControlsWithoutBundledAssets() {
        let app = XCUIApplication()
        app.launch()
        let originalLevels = app.tabBars.buttons["Original levels"]
        XCTAssertTrue(originalLevels.waitForExistence(timeout: 20))
        XCTAssertTrue(originalLevels.isSelected)
        XCTAssertTrue(app.buttons["Import original levels"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Import entire exported levels folder"].exists)
    }

    func testOriginalResourcesImportControlsWithoutBundledAssets() {
        let app = XCUIApplication()
        app.launch()
        let originalFiles = app.tabBars.buttons["Original files"]
        XCTAssertTrue(originalFiles.waitForExistence(timeout: 20))
        originalFiles.tap()
        XCTAssertTrue(app.staticTexts["Original Crazy Machines resources"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Import original game files"].exists)
        XCTAssertTrue(app.buttons["Import entire extracted models folder"].exists)
        XCTAssertTrue(app.staticTexts["Imported files (0)"].exists)
    }

    func testOnlyOriginalGameTabsAreExposed() {
        let app = XCUIApplication()
        app.launch()
        let originalLevels = app.tabBars.buttons["Original levels"]
        let originalFiles = app.tabBars.buttons["Original files"]
        XCTAssertTrue(originalLevels.waitForExistence(timeout: 20))
        XCTAssertTrue(originalFiles.exists)
        XCTAssertFalse(app.tabBars.buttons["Playground"].exists)
        XCTAssertFalse(app.tabBars.buttons["3D Preview"].exists)
        originalFiles.tap()
        XCTAssertTrue(originalFiles.isSelected)
        originalLevels.tap()
        XCTAssertTrue(originalLevels.isSelected)
    }
}
