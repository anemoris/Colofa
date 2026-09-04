////
//  SyncToolbarUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// The ahead/behind badges on Push and Pull (ticket 42), and the toolbar staying in one piece
/// while a remote command runs (ticket 44).
final class SyncToolbarUITests: XCTestCase {
    private let repositoryPath = "/tmp/Colofa Sync Toolbar"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - 42: the counts

    /// A Branch ahead of its upstream badges Push, and says the count out loud rather than leaving
    /// it as a numeral only a sighted user can read.
    @MainActor
    func testEnglishPushReportsHowFarAheadTheBranchIs() {
        let application = XCUIApplication.configuredForPushState(path: repositoryPath)
        application.launch()
        application.activate()

        let push = application.descendants(matching: .any)["repository.toolbar.push"]
        XCTAssertTrue(push.waitForExistence(timeout: 10))
        let value = push.value as? String
        XCTAssertEqual(
            value,
            "Ahead 2",
            "Push did not report how far ahead the Branch is, got: \(value ?? "nil")"
        )
    }

    /// The Pull side of the same rule.
    @MainActor
    func testEnglishPullReportsHowFarBehindTheBranchIs() {
        let application = XCUIApplication.configuredForPullState(path: repositoryPath)
        application.launch()
        application.activate()

        let pull = application.descendants(matching: .any)["repository.toolbar.pull"]
        XCTAssertTrue(pull.waitForExistence(timeout: 10))
        let value = pull.value as? String
        XCTAssertEqual(
            value,
            "Behind 2",
            "Pull did not report how far behind the Branch is, got: \(value ?? "nil")"
        )
    }

    /// A Branch with no upstream reads Publish, and Publish carries no count: nothing has been
    /// counted against it, which is a different statement from being level.
    @MainActor
    func testEnglishPublishCarriesNoCount() {
        let application = XCUIApplication.configuredForPushState(
            path: repositoryPath,
            additionalArguments: [UITestingArgument.pushNoUpstream]
        )
        application.launch()
        application.activate()

        let publish = application.descendants(matching: .any)["repository.toolbar.publish"]
        XCTAssertTrue(publish.waitForExistence(timeout: 10))
        XCTAssertEqual(publish.value as? String, "", "Publish reported a count it cannot have")
    }

    // MARK: - 44: the group stays whole

    /// The regression test for the split: a running command must not move its neighbours.
    ///
    /// Frames rather than a screenshot, because the symptom is positional — the rebuilt item left
    /// the group and everything after it shifted. New Branch sits after all three remote commands,
    /// so it is the one that moves if any of them rebuilds.
    @MainActor
    func testEnglishARunningFetchLeavesTheToolbarGroupInPlace() {
        let application = XCUIApplication.configuredForFetchState(
            path: repositoryPath,
            additionalArguments: [UITestingArgument.slowFetch]
        )
        application.launch()
        application.activate()

        let any = application.descendants(matching: .any)
        let newBranch = any["repository.toolbar.newBranch"]
        let inspector = any["baseline.inspector.toggle"]
        XCTAssertTrue(newBranch.waitForExistence(timeout: 10))
        XCTAssertTrue(inspector.waitForExistence(timeout: 10))

        let newBranchBefore = newBranch.frame
        let inspectorBefore = inspector.frame

        any["repository.toolbar.fetch"].click()

        let cancel = any["repository.toolbar.cancelFetch"]
        XCTAssertTrue(
            cancel.waitForExistence(timeout: 10),
            "A running Fetch offered no way to stop it"
        )

        XCTAssertEqual(
            newBranch.frame,
            newBranchBefore,
            "New Branch moved while a Fetch was running, so the toolbar group split apart"
        )
        XCTAssertEqual(
            inspector.frame,
            inspectorBefore,
            "The Repository Info toggle moved while a Fetch was running"
        )

        cancel.click()
        XCTAssertTrue(
            any["repository.toolbar.fetch"].waitForExistence(timeout: 10),
            "Cancelling did not return the toolbar to Fetch"
        )
        XCTAssertEqual(
            newBranch.frame,
            newBranchBefore,
            "New Branch did not return to where it started after the Fetch ended"
        )
    }

    /// Push is the button that can change what it offers with no command running at all, when a
    /// reload flips the Branch between published and unpublished. That swap must not move
    /// anything either.
    @MainActor
    func testEnglishARunningPushLeavesTheToolbarGroupInPlace() {
        let application = XCUIApplication.configuredForPushState(
            path: repositoryPath,
            additionalArguments: [UITestingArgument.slowFetch]
        )
        application.launch()
        application.activate()

        let any = application.descendants(matching: .any)
        let newBranch = any["repository.toolbar.newBranch"]
        XCTAssertTrue(newBranch.waitForExistence(timeout: 10))
        let before = newBranch.frame

        any["repository.toolbar.push"].click()

        let confirm = application.sheets.firstMatch
        if confirm.waitForExistence(timeout: 5) {
            confirm.buttons["Push"].firstMatch.click()
        }

        let cancel = any["repository.toolbar.cancelPush"]
        XCTAssertTrue(
            cancel.waitForExistence(timeout: 10),
            "A running Push offered no way to stop it"
        )
        XCTAssertEqual(
            newBranch.frame,
            before,
            "New Branch moved while a Push was running, so the toolbar group split apart"
        )

        cancel.click()
    }
}
