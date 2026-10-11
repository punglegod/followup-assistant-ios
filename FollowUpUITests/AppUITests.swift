import XCTest

final class AppUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testDockNavigationAndTransparencyControl() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["dock-3"].waitForExistence(timeout: 10))
        app.buttons["dock-3"].tap()
        let slider = app.sliders["dock-transparency"]
        if !slider.isHittable { app.swipeUp() }
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.85)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Glass dock transparency setting"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["dock-2"].tap()
        XCTAssertTrue(app.navigationBars["问答与话术"].waitForExistence(timeout: 5))
        app.buttons["dock-0"].tap()
        XCTAssertTrue(app.navigationBars["回访小助手"].waitForExistence(timeout: 5))
    }

    func testNewCustomerReceivesThreeDefaultFollowUps() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["dock-1"].tap()
        app.buttons["add-customer"].tap()
        let field = app.textFields["customer-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        let name = "UITest-" + UUID().uuidString.prefix(6)
        field.typeText(name)
        app.buttons["save-customer"].tap()
        let row = app.staticTexts[name]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["咨询后第 3 天"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["咨询后第 7 天"].exists)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["咨询后第 21 天"].waitForExistence(timeout: 5))
    }
}
