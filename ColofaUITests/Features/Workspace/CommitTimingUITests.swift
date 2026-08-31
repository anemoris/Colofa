////
//  CommitTimingUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// What the Commit composer does while a Commit it started is still running.
final class CommitTimingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// A Commit blocked in a Hook or in signing keeps the composer on screen for as long as it
    /// takes. Git already holds the message it was handed, and the composer is cleared once the
    /// Commit lands, so anything typed in the meantime would be dropped twice over. Both fields
    /// stop accepting text until the Commit is done rather than accepting text and discarding it.
    @MainActor
    func testEnglishComposerRefusesTextWhileTheCommitIsStillRunning() {
        let application = committableApplication(
            additionalArguments: [UITestingArgument.slowCommit]
        )
        application.launch()
        application.activate()

        let summary = application.textFields["repository.commit.summary"]
        let description = application.textFields["repository.commit.description"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        replaceText(of: summary, with: "Add the commit composer")
        XCTAssertTrue(summary.isEnabled)
        XCTAssertTrue(description.isEnabled)

        let action = application.buttons["repository.commit.action"]
        XCTAssertTrue(waitUntil(NSPredicate(format: "isEnabled == true"), on: action))
        action.click()

        let closed = NSPredicate(format: "isEnabled == false")
        XCTAssertTrue(waitUntil(closed, on: summary), "The Summary stayed editable mid-Commit")
        XCTAssertTrue(waitUntil(closed, on: description), "The Description stayed editable")
        // The message is still on screen while it is being committed: it is closed, not cleared.
        XCTAssertEqual(summary.value as? String, "Add the commit composer")

        // Nothing stops a Commit, so the fixture's is still out when this ends.
        application.terminate()
    }

    @MainActor
    private func committableApplication(
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        XCUIApplication.configuredForRepository(
            path: "/tmp/Colofa Commit Timing UI",
            additionalArguments: [UITestingArgument.committableState] + additionalArguments
        )
    }
}
