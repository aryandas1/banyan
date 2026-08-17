// SmokeUITests.swift
// De-risking probe: proves XCUITest can actually launch and drive the app under
// `xcodebuild test` in this environment before we invest in real UI tests.
// Asserts only that the app reaches the foreground and renders something we can
// read from the accessibility tree. On a clean install there is no Supabase
// session, so restoreSession() throws → the app lands deterministically on
// SignInView; the "Banyan" title is a stable, styling-independent anchor there
// (the real Sign in with Apple button can't complete headlessly).

import XCTest

final class SmokeUITests: XCTestCase {
    func testAppLaunchesAndRendersAControl() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15),
                      "app should reach the foreground")
        XCTAssertTrue(app.staticTexts["Banyan"].waitForExistence(timeout: 30),
                      "expected the 'Banyan' title on a fresh launch — proves XCUITest reads the a11y tree")
    }
}
