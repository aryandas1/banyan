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

    // Regression guard for the re-accept flash: a viewer who re-opens an invite
    // they already accepted (a re-tap, or iOS redelivering onOpenURL) must land on
    // success via the token memo, NOT flash the failure screen the non-idempotent
    // accept RPC would produce. -uiTestReaccept stands the app up as a viewer who
    // has already accepted the token, backed by an invite service that FAILS on
    // every call — so any output other than success means the memo didn't fire.
    func testReopeningAnAlreadyAcceptedInviteDoesNotFlashFailure() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestReaccept"]
        app.launch()

        // The memo short-circuits straight to success…
        XCTAssertTrue(app.staticTexts["You're in!"].waitForExistence(timeout: 15),
                      "re-opening an accepted invite should resolve to success")
        // …and the failure screen the failing service would produce never appears.
        XCTAssertFalse(app.staticTexts["Invite not valid"].exists,
                       "re-accepting a memoized token must not flash the failure screen")

        // Dismissing returns the viewer to the tree they could already see.
        app.buttons["View tree"].tap()
        XCTAssertTrue(app.staticTexts["Ravi"].waitForExistence(timeout: 15),
                      "the viewer's tree should render after dismissing the sheet")
        XCTAssertTrue(app.staticTexts["View only"].exists,
                      "the re-accepting viewer stays a read-only viewer")
    }

    // The tree switcher: an owner who also views a second tree can switch between
    // them from the Tree tab's menu, and read-only-ness follows the active tree —
    // their own tree stays editable (Share present), the viewed one is read-only
    // (View only banner, no Share). -uiTestTreeSwitcher seeds exactly that state.
    func testTreeSwitcherTogglesBetweenOwnedAndViewedTrees() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestTreeSwitcher"]
        app.launch()

        // Starts on the owned, editable tree.
        XCTAssertTrue(app.staticTexts["Ravi"].waitForExistence(timeout: 15),
                      "should open on the owned tree's focal person")
        XCTAssertTrue(app.buttons["Share"].exists, "the owned tree is editable (Share present)")
        XCTAssertFalse(app.staticTexts["View only"].exists, "no view-only banner on the owned tree")

        // Switch to the viewed tree.
        app.buttons["treeSwitcher"].tap()
        app.buttons["Priya's family"].tap()

        // Now read-only: the viewed tree's focal renders, banner shown, Share gone.
        XCTAssertTrue(app.staticTexts["Priya"].waitForExistence(timeout: 15),
                      "switching should centre the viewed tree's focal person")
        XCTAssertTrue(app.staticTexts["View only"].waitForExistence(timeout: 5),
                      "the viewed tree must be read-only")
        XCTAssertFalse(app.buttons["Share"].exists, "a viewer must not see Share")

        // Switch back to the owned tree → editable again.
        app.buttons["treeSwitcher"].tap()
        app.buttons["Ravi's family"].tap()
        XCTAssertTrue(app.staticTexts["Ravi"].waitForExistence(timeout: 15),
                      "switching back should restore the owned tree")
        XCTAssertTrue(app.buttons["Share"].exists, "the owned tree is editable again")
        XCTAssertFalse(app.staticTexts["View only"].exists, "no banner back on the owned tree")
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
