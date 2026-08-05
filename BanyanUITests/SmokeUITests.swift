// SmokeUITests.swift
// De-risking probe: proves XCUITest can actually launch and drive the app under
// `xcodebuild test` in this environment before we invest in real UI tests.
// Asserts only that the app reaches the foreground and renders a control we can
// read from the accessibility tree — "Get started" appears in BOTH reachable
// fresh-install states (SignInView while anon auth is pending/failed, WelcomeView
// once it succeeds), so it's a state-independent anchor on a clean install.

import XCTest

final class SmokeUITests: XCTestCase {
    func testAppLaunchesAndRendersAControl() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15),
                      "app should reach the foreground")
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 30),
                      "expected a 'Get started' button on a fresh launch — proves XCUITest reads the a11y tree")
    }
}
