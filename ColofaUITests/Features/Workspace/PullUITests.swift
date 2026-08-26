////
//  PullUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// Pull, driven the way a user reaches it: the toolbar, the Repository menu, and the alerts a
/// Pull that could not fast-forward puts on screen.
final class PullUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The toolbar's Pull closes the gap to the upstream and records the time it earned.
    @MainActor
    func testEnglishToolbarPullFastForwardsTheCurrentBranch() {
        let application = pullApplication()
        application.launch()
        application.activate()

        let upstream = application.descendants(matching: .any)["repository.upstream"]
        assertEventuallyExists(upstream, "The status bar does not report the upstream")
        XCTAssertEqual(upstream.value as? String, "origin/main, Ahead 0, Behind 2")

        let lastFetch = application.descendants(matching: .any)["repository.lastFetch"]
        XCTAssertEqual(lastFetch.value as? String, "Never")

        application.descendants(matching: .any)["repository.toolbar.pull"].click()

        XCTAssertTrue(
            waitUntil(
                NSPredicate(format: "value == %@", "origin/main, Ahead 0, Behind 0"),
                on: upstream
            ),
            "The Pull did not leave the Branch at its upstream"
        )
        XCTAssertTrue(
            waitUntil(NSPredicate(format: "value != %@", "Never"), on: lastFetch),
            "The Pull did not record the time it fetched"
        )
        XCTAssertFalse(
            application.sheets.firstMatch.exists,
            "A Pull that worked raised an alert"
        )
    }

    /// A Branch with no upstream explains why Pull is disabled rather than failing afterwards.
    @MainActor
    func testEnglishPullIsDisabledWithoutAnUpstream() {
        let application = pullApplication(
            additionalArguments: [UITestingArgument.pullNoUpstream]
        )
        application.launch()
        application.activate()

        let pull = application.descendants(matching: .any)["repository.toolbar.pull"]
        assertEventuallyExists(pull, "The toolbar has no Pull")
        XCTAssertFalse(pull.isEnabled)
    }

    /// Both sides moved, so the Pull stops and says which two commands can integrate them.
    @MainActor
    func testEnglishAdivergedPullStopsAndDirectsToMergeOrRebase() {
        let application = pullApplication(additionalArguments: [UITestingArgument.pullDiverged])
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.toolbar.pull"].click()

        assertEventuallyExists(
            application.sheets.staticTexts.matching(
                NSPredicate(format: "value CONTAINS %@", "Rebase")
            ).firstMatch,
            "The refusal did not direct the user to Merge or Rebase"
        )
        XCTAssertTrue(application.sheets.buttons["View Details"].exists)
        application.sheets.buttons["OK"].click()

        XCTAssertEqual(
            application.descendants(matching: .any)["repository.upstream"].value as? String,
            "origin/main, Ahead 1, Behind 2",
            "The refused Pull did not leave the fetched counts on screen"
        )
    }

    /// Local work in the way is named, and the alert says what to do with it.
    @MainActor
    func testEnglishApullBlockedByLocalChangesNamesThem() {
        let application = pullApplication(additionalArguments: [UITestingArgument.pullBlocked])
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.toolbar.pull"].click()

        assertEventuallyExists(
            application.sheets.staticTexts.matching(
                NSPredicate(format: "value CONTAINS %@", "本地更改.txt")
            ).firstMatch,
            "The refusal did not name the local work it protected"
        )
        application.sheets.buttons["OK"].click()
    }

    /// A running Pull offers the way out in the place the user pressed Pull.
    @MainActor
    func testEnglishArunningPullCanBeCancelled() {
        let application = pullApplication(additionalArguments: [UITestingArgument.slowFetch])
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.toolbar.pull"].click()

        let cancel = application.descendants(matching: .any)["repository.toolbar.cancelPull"]
        assertEventuallyExists(cancel, "A running Pull offered no way to stop it")
        cancel.click()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.toolbar.pull"],
            "Cancelling did not return the toolbar to Pull"
        )
        XCTAssertEqual(
            application.descendants(matching: .any)["repository.lastFetch"].value as? String,
            "Never",
            "A cancelled Pull recorded a time"
        )
    }

    /// The toolbar is where a Pull is normally started and stopped, but macOS lets the user hide
    /// it — so the Repository menu carries both.
    @MainActor
    func testEnglishArunningPullCanBeCancelledFromTheRepositoryMenu() {
        let application = pullApplication(additionalArguments: [UITestingArgument.slowFetch])
        application.launch()
        application.activate()

        application.menuBars.menuBarItems["Repository"].click()
        application.menuItems["Pull"].click()

        application.menuBars.menuBarItems["Repository"].click()
        let cancel = application.menuItems["Cancel Pull"]
        assertEventuallyExists(cancel, "The Repository menu offered no way to stop a Pull")
        cancel.click()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.toolbar.pull"],
            "Cancelling from the menu did not end the Pull"
        )
    }

    private func pullApplication(
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        XCUIApplication.configuredForPullState(
            path: FileManager.default.temporaryDirectory.path(percentEncoded: false),
            additionalArguments: additionalArguments
        )
    }
}
