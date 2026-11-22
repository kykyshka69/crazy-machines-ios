import XCTest
import UIKit

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
        // A successful app launch does NOT prove SceneKit drew the UCM mesh.
        // Guard against the all-black 3D viewport captured in run #850.
        let viewport = app.otherElements["cm.original.assembled-scene"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 10),
                      "Imported SceneKit viewport is missing")
        let centerCamera = app.buttons["cm.original.quickplay-center-camera"]
        XCTAssertTrue(centerCamera.waitForExistence(timeout: 10),
                      "Original puzzle has no way to restore camera framing")
        centerCamera.tap()
        var orangePixels = 0
        var calibrationPixels = 0
        for _ in 0..<5 {
            let colors = renderedPixelCounts(viewport.screenshot().image)
            orangePixels = max(orangePixels, colors.orange)
            calibrationPixels = max(calibrationPixels, colors.cyan)
            if orangePixels >= 8 && calibrationPixels >= 8 { break }
            Thread.sleep(forTimeInterval: 0.4)
        }
        // If the native SceneKit probe has not finished yet, give its
        // independent offscreen snapshot a brief opportunity to render.
        // Its pixel counts distinguish GPU/compositing failure from geometry
        // which fails to appear in the live simulator screenshot.
        var sceneStatus = (viewport.value as? String) ?? "no scene diagnostics"
        for _ in 0..<6 where !sceneStatus.contains("nativeSCNSnapshot=") {
            Thread.sleep(forTimeInterval: 0.5)
            sceneStatus = (viewport.value as? String) ?? "no scene diagnostics"
        }
        XCTAssertTrue(calibrationPixels >= 8,
                      "SceneKit calibration is invisible (cyan=\(calibrationPixels), " +
                      "orange=\(orangePixels)); \(sceneStatus)")
        XCTAssertTrue(orangePixels >= 8,
                      "Imported UCM triangle is invisible (orange=\(orangePixels), " +
                      "cyan=\(calibrationPixels)); \(sceneStatus)")
        attachScreenshot(app, named: "05-imported-original-3D-SceneKit-fixture")

        // XCUI reports both a wrapper Switch and its native UISwitch.
        // Tapping the wrapper's center can hit only its label and leave the
        // native control OFF. Tap the real right-hand control instead.
        physics.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.5)).tap()
        let isRunning = (physics.value as? String) == "1"
        XCTAssertTrue(isRunning,
                      "Tapping the visible switch must enable experimental physics")
        guard isRunning else { return }
        XCTAssertTrue(pause.waitForExistence(timeout: 10),
                      "Pause must appear after enabling physics")
        guard pause.exists else { return }
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

    func testLinkedZoneContactActuallyAdvancesFirstLevelPrototype() {
        // This is fully synthetic and contains no proprietary PC art.
        // Crucially it tests an ACTUAL falling SceneKit body contacting an
        // original-style tmo_zone with an exact CONNECTED_TO link. A physics
        // toggle alone cannot make this test pass.
        let app = XCUIApplication()
        app.launchArguments = ["--cm-ci-install-linked-zone-fixture"]
        app.launch()
        let play = app.buttons["cm.menu.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 25))
        play.tap()
        XCTAssertTrue(
            app.staticTexts["Original level 1: CM synthetic CI 3D contacts"]
                .waitForExistence(timeout: 20),
            "The linked-zone scene did not enter the real 3D player"
        )
        let progress = app.staticTexts["cm.original.first-level-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 15),
                      "The evidence-based four-object challenge was not detected")
        XCTAssertEqual(progress.label, "0 / 4",
                       "No synthetic source has been delivered before physics runs")
        let physics = app.switches["cm.original.quickplay-physics"]
        XCTAssertTrue(physics.waitForExistence(timeout: 10))
        physics.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(physics.value as? String, "1",
                       "SceneKit did not start the experimental physics step")
        let delivery = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label MATCHES %@", "[1-4] / 4"),
            object: progress
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [delivery], timeout: 20), .completed,
            "A real SceneKit ball/zone collision never reached the linked " +
            "source/target callback; last progress: \(progress.label)"
        )
        // Multiple genuine SceneKit collisions must be credited once
        // each. Removing the collected prototype-only source body keeps
        // already-delivered objects from clogging the same target zone.
        let allDelivered = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "4 / 4"),
            object: progress
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [allDelivered], timeout: 40), .completed,
            "Four distinct original-style linked objects did not reach " +
            "the shared capture zone; last progress: \(progress.label)"
        )
        let continueToLevel2 = app.buttons["cm.original.first-level-next"]
        XCTAssertTrue(continueToLevel2.waitForExistence(timeout: 10),
                      "Continue must remain accessible over the 3D viewport at 4/4")
        XCTAssertTrue(continueToLevel2.isEnabled,
                      "Level 2 was imported but Continue is disabled")
        attachScreenshot(app, named: "07-synthetic-four-linked-deliveries-complete")
        continueToLevel2.tap()
        XCTAssertTrue(
            app.staticTexts["Original level 2: CM synthetic CI level 2"]
                .waitForExistence(timeout: 20),
            "Completing four real 3D contacts did not navigate to level 2"
        )
        attachScreenshot(app, named: "08-synthetic-original-level-two-navigation")
    }

    func testSecondLevelBasketHitsItsOriginalLinkedCrate() {
        // The real PC level 2 links one basketball to a crate, NOT to
        // its separate tmo_zone. Synthetic 3D bodies exercise the production
        // originalConnection callback and evidence-based prototype tracker.
        let app = XCUIApplication()
        app.launchArguments = ["--cm-ci-install-linked-zone-fixture"]
        app.launch()
        let play = app.buttons["cm.menu.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 25))
        play.tap()
        let next = app.buttons["cm.original.quickplay-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        XCTAssertTrue(next.isEnabled)
        next.tap()
        XCTAssertTrue(
            app.staticTexts["Original level 2: CM synthetic CI level 2"]
                .waitForExistence(timeout: 20),
            "Original-style second puzzle could not be opened"
        )
        let progress = app.staticTexts["cm.original.second-level-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 15),
                      "Second level basket-to-crate link not detected")
        XCTAssertEqual(progress.label, "0 / 1")
        let physics = app.switches["cm.original.quickplay-physics"]
        XCTAssertTrue(physics.waitForExistence(timeout: 10))
        physics.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(physics.value as? String, "1")
        let hit = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "1 / 1"),
            object: progress
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [hit], timeout: 35), .completed,
            "Basket and its own crate did not produce the real SceneKit " +
            "CONNECTED_TO contact; last progress: \(progress.label)"
        )
        let continueToLevel3 = app.buttons["cm.original.second-level-next"]
        XCTAssertTrue(continueToLevel3.waitForExistence(timeout: 10))
        XCTAssertTrue(continueToLevel3.isEnabled)
        attachScreenshot(app, named: "09-synthetic-level-2-basket-crate-contact")
        continueToLevel3.tap()
        XCTAssertTrue(
            app.staticTexts["Original level 3: CM synthetic CI level 3"]
                .waitForExistence(timeout: 20),
            "Basket-to-crate prototype did not continue to level 3"
        )
    }

    func testPrivateOriginalLevelOneWhenOptedIn() throws {
        // This test is opt-in because the user's original game files are
        // copyrighted and MUST NOT enter public GitHub Actions artifacts.
        // Copy the privately owned .cmassets to ios/ in a LOCAL checkout;
        // run CM_PRIVATE_ORIGINAL_PACK_TEST=1 xcodebuild test on a Mac.
        guard ProcessInfo.processInfo.environment["CM_PRIVATE_ORIGINAL_PACK_TEST"] == "1" else {
            throw XCTSkip("Private original game resources are intentionally absent from public CI")
        }
        let app = XCUIApplication()
        // Do not clear or replace the player's original level with a
        // synthetic CI scene: the app imports the bundled private pack.
        app.launch()
        let play = app.buttons["cm.menu.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 35))
        // The private original .cmassets pack is verified and installed on a
        // background thread. Never tap Play before the original UCM files
        // have passed validation and the app has enabled the button.
        let installed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"), object: play
        )
        XCTAssertEqual(XCTWaiter.wait(for: [installed], timeout: 120), .completed,
                       "Private original resource pack did not finish installation")
        play.tap()

        let title = app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@", "Original level 1:")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 30),
                      "Private level 1 did not open from the bundled game pack")
        let viewport = app.otherElements["cm.original.assembled-scene"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 15))
        let firstLevelProgress = app.staticTexts["cm.original.first-level-progress"]
        XCTAssertTrue(firstLevelProgress.waitForExistence(timeout: 15),
                      "Authentic first level did not expose the four linked targets")
        XCTAssertEqual(firstLevelProgress.label, "0 / 4",
                       "Original first-level prototype must start with zero deliveries")
        // The normal level is built exclusively from user-owned UCM files.
        // A count of at least 25 visible original 3DO nodes makes a fallback
        // test triangle or a missing-asset blank frame impossible to pass.
        var modelCount = 0
        var status = ""
        for _ in 0..<15 {
            status = (viewport.value as? String) ?? ""
            if let expression = try? NSRegularExpression(
                pattern: "originalUCM=(\\d+)"),
               let match = expression.firstMatch(
                in: status, range: NSRange(status.startIndex..., in: status)),
               let range = Range(match.range(at: 1), in: status),
               let value = Int(status[range]) {
                modelCount = value
            }
            if modelCount >= 25 { break }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertGreaterThanOrEqual(modelCount, 25,
            "Authentic first level did not load expected UCM meshes; \(status)")
        attachScreenshot(app, named: "07-PRIVATE-original-professor-level-001")

        let physics = app.switches["cm.original.quickplay-physics"]
        XCTAssertTrue(physics.waitForExistence(timeout: 10))
        physics.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.5)).tap()
        XCTAssertEqual(physics.value as? String, "1",
                       "Original scene physics failed to start")
        attachScreenshot(app, named: "08-PRIVATE-original-professor-level-001-physics")

        // Private follow-on: verify authentic Professor level 2 can actually
        // open with the owner's original meshes and the basket->crate rule.
        // This is deliberately excluded from public CI because proprietary
        // artwork must not be uploaded as a GitHub artifact.
        let next = app.buttons["cm.original.quickplay-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        XCTAssertTrue(next.isEnabled,
                      "Bundled private pack is missing original level 2")
        next.tap()
        let secondTitle = app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@", "Original level 2:")).firstMatch
        XCTAssertTrue(secondTitle.waitForExistence(timeout: 35),
                      "Authentic Professor level 2 failed to open")
        let secondProgress = app.staticTexts["cm.original.second-level-progress"]
        XCTAssertTrue(secondProgress.waitForExistence(timeout: 20),
                      "Original level 2 basketball-to-crate relationship was not loaded")
        XCTAssertEqual(secondProgress.label, "0 / 1")
        var secondCount = 0
        var secondStatus = ""
        for _ in 0..<20 {
            secondStatus = (viewport.value as? String) ?? ""
            if let expression = try? NSRegularExpression(
                pattern: "originalUCM=(\\d+)"),
               let match = expression.firstMatch(
                in: secondStatus, range: NSRange(secondStatus.startIndex..., in: secondStatus)),
               let range = Range(match.range(at: 1), in: secondStatus),
               let value = Int(secondStatus[range]) {
                secondCount = value
            }
            if secondCount >= 60 { break }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertGreaterThanOrEqual(secondCount, 60,
            "Authentic original level 2 has 66 UCM instances; \(secondStatus)")
        attachScreenshot(app, named: "09-PRIVATE-original-professor-level-002")
    }

    /// Inspect only the SceneKit pixels, not the bright SwiftUI controls.
    /// The fixture's actual imported UCM mesh is ORANGE; the simulator-only
    /// reference SCNSphere is CYAN. A successful test must see BOTH: one
    /// proves SceneKit draws, the other proves authentic UCM geometry draws.
    private func renderedPixelCounts(_ image: UIImage) -> (orange: Int, cyan: Int) {
        guard let original = image.cgImage else { return (0, 0) }
        let side = 72
        var rgba = [UInt8](repeating: 0, count: side * side * 4)
        let decoded = rgba.withUnsafeMutableBytes { bytes -> Bool in
            guard let base = bytes.baseAddress,
                  let context = CGContext(
                    data: base, width: side, height: side,
                    bitsPerComponent: 8, bytesPerRow: side * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return false }
            context.draw(original, in: CGRect(
                x: 0, y: 0, width: side, height: side))
            return true
        }
        guard decoded else { return (0, 0) }
        var orange = 0
        var cyan = 0
        for offset in stride(from: 0, to: rgba.count, by: 4) {
            let r = Int(rgba[offset])
            let g = Int(rgba[offset + 1])
            let b = Int(rgba[offset + 2])
            if r >= 140 && g >= 40 && r >= g + 35 && g >= b + 25 {
                orange += 1
            }
            if g >= 120 && b >= 120 && r + 45 <= g && r + 45 <= b {
                cyan += 1
            }
        }
        return (orange, cyan)
    }

    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
