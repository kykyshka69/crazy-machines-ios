import XCTest

final class CrazyMachinesLaunchUITests: XCTestCase {
    private func launchHome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["cm.menu.play"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["cm.menu.files"].exists)
        return app
    }

    func testHomeMenuAndCapture() {
        let app = launchHome()
        attachScreenshot(app, named: "01-game-home")
    }

    func testPlayOpensOriginalLevelBrowser() {
        let app = launchHome()
        app.buttons["cm.menu.play"].tap()
        XCTAssertTrue(app.buttons["Import original levels"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Import entire exported levels folder"].exists)
        attachScreenshot(app, named: "02-original-levels")
    }

    func testGameFilesOpensOriginalResources() {
        let app = launchHome()
        app.buttons["cm.menu.files"].tap()
        XCTAssertTrue(app.buttons["Import original game files"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Import entire extracted models folder"].exists)
        attachScreenshot(app, named: "03-original-files")
    }

    func testOriginalLevelFileImporterOpens() {
        let app = launchHome()
        app.buttons["cm.menu.play"].tap()
        let importButton = app.buttons["Import original levels"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 15))
        importButton.tap()
        let picker = app.navigationBars["Browse"]
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(
            picker.waitForExistence(timeout: 15) || cancel.waitForExistence(timeout: 5),
            "Original level import did not present the iOS document picker"
        )
        attachScreenshot(app, named: "04-original-level-document-picker")
    }

    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
