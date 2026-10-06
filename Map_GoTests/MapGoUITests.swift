import XCTest

final class MapGoUITests: XCTestCase {
    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [scenario]
        app.launch()
        return app
    }

    func testNoDeviceState() {
        let app = launch("-UITestNoDevice")
        XCTAssertTrue(app.staticTexts["沒有裝置"].waitForExistence(timeout: 5))
    }

    func testSearchNoResultShowsError() {
        let app = launch("-UITestSearchNoResult")
        let addressField = app.textFields["輸入地址"]
        XCTAssertTrue(addressField.waitForExistence(timeout: 5))
        addressField.click()
        addressField.typeText("不存在的測試地址")
        app.buttons["搜尋"].click()
        XCTAssertTrue(app.staticTexts["找不到地址。"].waitForExistence(timeout: 5))
    }

    func testRouteFailureShowsError() {
        let app = launch("-UITestRouteFailure")
        XCTAssertTrue(app.buttons["規劃路徑"].waitForExistence(timeout: 5))
    }

    func testRouteAndJoystickControlsCannotConflict() {
        let app = launch("-UITestConflict")
        XCTAssertTrue(app.staticTexts["路徑移動中"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["joystick-control"].isEnabled)
    }
}
