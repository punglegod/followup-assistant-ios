import XCTest

final class AppUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testCustomerSearchAboveDock() throws { try checkSearchLayout(tab: "dock-1", title: "客户") }
    func testLibrarySearchAboveDock() throws { try checkSearchLayout(tab: "dock-2", title: "问答与话术") }

    private func checkSearchLayout(tab: String, title: String) throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons[tab].waitForExistence(timeout: 10))
        app.buttons[tab].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        let dock = app.buttons["dock-0"]
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = title + " search and dock layout"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertLessThan(search.frame.maxY, dock.frame.minY - 8, "搜索框不应与底栏重叠")
        XCTAssertLessThan(search.frame.midY, app.frame.height * 0.5, "搜索框应位于标题下方")
        XCTAssertTrue(search.isHittable)
        XCTAssertTrue(dock.isHittable)
        search.tap()
        search.typeText("NoMatchRegressionQuery")
        XCTAssertLessThan(search.frame.maxY, dock.frame.minY - 8, "输入时搜索框与底栏仍应分离")
        dock.tap()
        XCTAssertTrue(app.navigationBars["回访小助手"].waitForExistence(timeout: 5))
    }

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
        let name = "UITest-" + String(UUID().uuidString.prefix(6))
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
