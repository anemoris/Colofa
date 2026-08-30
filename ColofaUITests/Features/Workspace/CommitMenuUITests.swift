////
//  CommitMenuUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// Commit reached through the menu bar rather than the middle column, which is a command surface
/// no unit test can see: whether the item exists, whether it is enabled, and whether it runs the
/// same Commit the composer does.
final class CommitMenuUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The menu bar reaches the same Commit the composer does, and reports the same reason it
    /// cannot run yet. A command surface that is permanently dimmed says the feature is missing.
    @MainActor
    func testEnglishTheRepositoryMenuCommitsTheComposersDraft() {
        let application = committableApplication()
        application.launch()
        application.activate()

        let summary = application.textFields["repository.commit.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))

        application.menuBars.menuBarItems["Repository"].click()
        let commit = application.menuItems["Commit"]
        XCTAssertTrue(commit.exists, "The Repository menu offers no Commit")
        XCTAssertFalse(commit.isEnabled, "Commit ran with no Summary written")
        application.typeKey(.escape, modifierFlags: [])

        replaceText(of: summary, with: "Commit from the menu bar")

        application.menuBars.menuBarItems["Repository"].click()
        XCTAssertTrue(waitUntil(NSPredicate(format: "isEnabled == true"), on: commit))
        commit.click()

        XCTAssertTrue(waitUntil(NSPredicate(format: "value == %@", ""), on: summary))
        let upstream = application.staticTexts["repository.upstream"]
        XCTAssertTrue(upstream.waitForExistence(timeout: 2))
        XCTAssertEqual(upstream.value as? String, "origin/main, Ahead 1, Behind 0")
    }

    @MainActor
    private func committableApplication() -> XCUIApplication {
        XCUIApplication.configuredForRepository(
            path: "/tmp/Colofa Commit Menu UI",
            additionalArguments: [UITestingArgument.committableState]
        )
    }
}
