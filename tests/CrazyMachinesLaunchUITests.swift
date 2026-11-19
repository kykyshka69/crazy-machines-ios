import XCTest

final class CrazyMachinesLaunchUITests: XCTestCase {
    func testLaunchAndSwitchTabs() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Playground"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.tabBars.buttons["Original levels"].exists)
        app.tabBars.buttons["Original levels"].tap()
        XCTAssertTrue(app.tabBars.buttons["Original levels"].isSelected)
        app.tabBars.buttons["Playground"].tap()
        XCTAssertTrue(app.tabBars.buttons["Playground"].isSelected)
    }
}
