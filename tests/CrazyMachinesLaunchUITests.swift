import XCTest

final class CrazyMachinesLaunchUITests: XCTestCase {
    func testOriginalLevelFileImporterOpens() {
        let app = XCUIApplication()
        app.launch()
        let importButton = app.buttons["Import original levels"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 20))
        importButton.tap()
        // A real iOS document picker must appear, not just an inert import button.
        let picker = app.navigationBars["Browse"]
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(
            picker.waitForExistence(timeout: 15) || cancel.waitForExistence(timeout: 5),
            "Original level import did not present the iOS document picker"
        )
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "03-original-level-document-picker"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureBothOriginalGameScreens() {
        let app = XCUIApplication()
        app.launch()
        let levels = app.tabBars.buttons["Original levels"]
        let files = app.tabBars.buttons["Original files"]
        XCTAssertTrue(levels.waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Import original levels"].waitForExistence(timeout: 10))
        attachScreenshot(app, named: "01-original-levels")
        XCTAssertTrue(files.exists)
        files.tap()
        XCTAssertTrue(app.buttons["Import original game files"].waitForExistence(timeout: 10))
        attachScreenshot(app, named: "02-original-files")
    }

    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testOriginalLevelsImportControlsWithoutBundledAssets() {
        let app = XCUIApplication()
        app.launch()
        let originalLevels = app.tabBars.buttons["Original levels"]
        XCTAssertTrue(originalLevels.waitForExistence(timeout: 20))
        XCTAssertTrue(originalLevels.isSelected)
        XCTAssertTrue(app.buttons["Import original levels"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Import entire exported levels folder"].exists)
    }

    func testOriginalLevelsEmptyOrImportedCountIsVisible() {
        let app = XCUIApplication()
        app.launch()
        let originalLevels = app.tabBars.buttons["Original levels"]
        XCTAssertTrue(originalLevels.waitForExistence(timeout: 20))
        let countLabel = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "[0-9]+ original levels loaded")
        ).firstMatch
        XCTAssertTrue(countLabel.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Original puzzles"].exists)
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
        // Simulator data can survive between runs: do not assume the
        // original-resource library is empty on every launch.
        let importedSection = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Imported files (")
        ).firstMatch
        XCTAssertTrue(importedSection.exists)
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
