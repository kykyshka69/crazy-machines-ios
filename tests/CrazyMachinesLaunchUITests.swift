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
        XCTAssertTrue(app.buttons["Import original CML laboratory"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Decode previously imported CML"].exists)
        XCTAssertTrue(app.buttons["Import original levels"].exists)
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

    func testCaptureFirstRealLevel3DWhenSeeded() throws {
        let app = XCUIApplication()
        app.launch()
        // The normal public CI has no copyrighted game data. Only a
        // privately staged original first-level JSON + UCM files enables
        // this screenshot test. Do not substitute the synthetic playground.
        let originalLevel = app.descendants(matching: .any)["cm.original.level-1"]
        guard originalLevel.waitForExistence(timeout: 10) else {
            throw XCTSkip("No user-owned original first-level scene staged")
        }
        originalLevel.tap()
        let open3D = app.buttons["cm.original.open-3d"]
        XCTAssertTrue(open3D.waitForExistence(timeout: 15),
                      "Original level must expose its authentic 3D preview")
        open3D.tap()

        let sceneView = app.descendants(matching: .any)["cm.original.assembled-scene"]
        XCTAssertTrue(sceneView.waitForExistence(timeout: 20),
                      "Original 3D SceneKit view never appeared")
        // A visible canvas is not proof that the original objects loaded:
        // require at least one actually constructed UCM mesh before capture.
        let hasRealMeshes = NSPredicate(
            format: "value MATCHES %@",
            ".*rendered-original-meshes:[1-9][0-9]*.*"
        )
        let loaded = XCTNSPredicateExpectation(predicate: hasRealMeshes, object: sceneView)
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 15), .completed,
                       "Original 3D scene opened but rendered zero UCM meshes")
        // Allow the GPU a frame after SceneKit has assembled the meshes.
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "04-real-first-original-level-3d"
        screenshot.lifetime = .keepAlways
        add(screenshot)
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
