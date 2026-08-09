// ViewerModeUITests.swift
// Drives the app in read-only viewer mode (via the -uiTestViewer launch harness,
// hermetic — no network) and asserts the shared tree renders while every edit
// affordance is hidden. This is the regression-prone surface of step 12: a new
// mutation control that forgets its `isReadOnly` gate would fail here.

import XCTest

final class ViewerModeUITests: XCTestCase {

    private func launchViewerApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestViewer"]
        app.launch()
        return app
    }

    func testViewerSeesReadOnlyTree() {
        let app = launchViewerApp()

        // The seeded tree renders, centred on the root person…
        XCTAssertTrue(app.staticTexts["Ravi"].waitForExistence(timeout: 15),
                      "the shared tree should render the root person")
        // …with the view-only banner…
        XCTAssertTrue(app.staticTexts["View only"].exists, "expected the view-only banner")
        // …and no owner controls.
        XCTAssertFalse(app.buttons["Share"].exists, "a viewer must not see Share")
        // The root has no parents in the seed, so an OWNER would see an
        // 'Add parent' placeholder; a viewer must not.
        XCTAssertFalse(app.buttons["Add parent"].exists,
                       "read-only mode must hide the add-relative placeholders")
    }

    // Regression guard for the empty-acceptance-sheet bug: the onOpenURL → .sheet →
    // InviteAcceptanceView path (bypassed by the viewer-seed harness) must actually
    // render its content, not present a blank sheet. -uiTestAcceptFlow presents the
    // sheet on launch against a stub service that succeeds.
    func testDeepLinkAcceptanceSheetRendersAndCompletes() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestAcceptFlow"]
        app.launch()

        // "You're in!" only appears if the sheet rendered its content AND the accept
        // → import → success flow ran — a blank sheet (the original bug) never would.
        XCTAssertTrue(app.staticTexts["You're in!"].waitForExistence(timeout: 15),
                      "the acceptance sheet must render and complete, not present empty")
        XCTAssertTrue(app.buttons["View tree"].exists, "success screen should offer 'View tree'")
    }

    // Regression guard for the owner-opens-own-invite lock: an owner who taps their
    // OWN invite link must land back on their editable tree, not the read-only
    // viewer shell. -uiTestOwnerOwnInvite stands the app up as the owner of the
    // invited tree and presents the acceptance sheet against a stub that returns
    // that same tree id — so the guard should short-circuit to success.
    func testOwnerOpeningOwnInviteStaysEditable() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestOwnerOwnInvite"]
        app.launch()

        // The guard reaches success without importing/registering as a viewer.
        XCTAssertTrue(app.staticTexts["You're in!"].waitForExistence(timeout: 15),
                      "the acceptance sheet should complete for the owner's own invite")
        app.buttons["View tree"].tap()

        // Back on the owner's own tree: it renders, editable (Share present), with
        // no view-only banner — i.e. the owner was NOT locked into read-only mode.
        XCTAssertTrue(app.staticTexts["Ravi"].waitForExistence(timeout: 15),
                      "the owner's tree should render after dismissing the sheet")
        XCTAssertTrue(app.buttons["Share"].exists, "the owner must still see Share (not read-only)")
        XCTAssertFalse(app.staticTexts["View only"].exists,
                       "opening your own invite must not show the view-only banner")
    }

    func testViewerPersonSheetHasNoEditControls() {
        let app = launchViewerApp()

        // Open the focal person's sheet (PersonNodeView's a11y label is the full name).
        let node = app.buttons["Ravi Sharma"]
        XCTAssertTrue(node.waitForExistence(timeout: 15), "focal node should be tappable")
        node.tap()

        // The sheet is up (Close exists), but every mutation control is gone.
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5), "person sheet should open")
        XCTAssertFalse(app.buttons["Edit"].exists, "a viewer must not see Edit")
        XCTAssertFalse(app.buttons["Add Ravi's parent"].exists, "a viewer must not see add-relative buttons")
        XCTAssertFalse(app.buttons["Delete Ravi"].exists, "a viewer must not see Delete")
        // The photo gallery is read-only for a viewer: no add-photo control, and the
        // avatar can't be tapped to change the profile photo.
        XCTAssertFalse(app.buttons["Add photo"].exists, "a viewer must not see the add-photo control")
        XCTAssertFalse(app.buttons["Change profile photo"].exists, "a viewer must not be able to change the profile photo")
    }
}
