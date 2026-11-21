import XCTest

final class CrazyMachinesLaunchUITests: XCTestCase {
    private func launchHome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--cm-ci-clear-original-scene"]
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

    func testReal3DNavigationWithSyntheticImportedScene() {
        // This is an explicit non-proprietary test fixture. It proves that
        // the production pack parser, original-scene document loader, UCM
        // model resolver and SceneKit screen can be opened in the simulator.
        // It does NOT prove authentic PC puzzle physics is implemented.
        let app = XCUIApplication()
        app.launchArguments = ["--cm-ci-install-original-scene"]
        app.launch()

        let play = app.buttons["cm.menu.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 25), "App never reached its home menu")
        play.tap()

        let actualSceneTitle = app.staticTexts["Original level 1: CM synthetic CI 3D scene"]
        XCTAssertTrue(
            actualSceneTitle.waitForExistence(timeout: 20),
            "Play did not navigate to the 3D scene populated from imported UCM data"
        )
        let physics = app.switches["cm.original.quickplay-physics"]
        XCTAssertTrue(physics.waitForExistence(timeout: 10),
                      "3D physics controls are not accessible")
        // The original puzzle opens in arrangement mode, with physics OFF.
        // The Pause button is deliberately absent until the user starts
        // simulation. Verify both modes instead of assuming an automatic run.
        let pause = app.buttons["cm.original.quickplay-pause"]
        XCTAssertFalse(pause.exists, "Pause must not be shown before physics starts")
        attachScreenshot(app, named: "05-imported-original-3D-SceneKit-fixture")

        physics.tap()
        XCTAssertTrue(pause.waitForExistence(timeout: 10),
                      "Pause must appear after enabling physics")
        attachScreenshot(app, named: "05b-running-3D-SceneKit-fixture")
        pause.tap()
        XCTAssertTrue(pause.label.contains("Resume"),
                      "Pause must change to Resume")
        pause.tap()
        XCTAssertTrue(pause.label.contains("Pause"),
                      "Resume must change back to Pause")
        app.buttons["cm.original.quickplay-reset"].tap()
        XCTAssertTrue(pause.waitForExistence(timeout: 10),
                      "Restart must retain the running physics mode")

        app.buttons["cm.original.quickplay-levels"].tap()
        XCTAssertTrue(
            app.buttons["Import original levels"].waitForExistence(timeout: 15),
            "3D scene did not open the original level browser"
        )
        XCTAssertTrue(app.staticTexts["1 original levels loaded"].exists)
        attachScreenshot(app, named: "06-imported-scene-level-browser")
    }

    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
