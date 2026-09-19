////
//  StatusBarPlacementUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// Where the status bar ends up, rather than whether it exists.
///
/// Existence is not the question this has to answer: a status bar laid out below the window's
/// bottom edge still reports `exists` and still returns its value, which is how it went missing
/// on a fully populated Repository without a single test noticing.
final class StatusBarPlacementUITests: XCTestCase {
    private let repositoryPath = "/tmp/Colofa Status Bar UI"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The Repository that used to push it out: an operation in progress, changes in both
    /// sections, and the Commit composer below them, all in one column.
    @MainActor
    func testEnglishThePopulatedRepositoryKeepsTheStatusBarInsideTheWindow() {
        let application = XCUIApplication.configuredForRepository(
            path: repositoryPath,
            additionalArguments: [UITestingArgument.realRepositoryState]
        )
        application.launch()
        application.activate()

        let window = application.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        assertStatusBarIsInside(window, of: application, at: "the size it opened at")

        // Again at the window's own minimum, which is where the column has least room to give.
        window.shrinkToMinimum()
        assertStatusBarIsInside(window, of: application, at: "its minimum size")

        // The composer is what the column gives way for, so it has to stay reachable.
        let summary = application.textFields["repository.commit.summary"]
        XCTAssertTrue(summary.exists, "The Commit composer left the window")
        XCTAssertTrue(window.frame.contains(summary.frame), "The Commit composer is out of reach")
    }

    @MainActor
    private func assertStatusBarIsInside(
        _ window: XCUIElement,
        of application: XCUIApplication,
        at description: String,
        line: UInt = #line
    ) {
        let path = application.descendants(matching: .any)["repository.path"]
        XCTAssertTrue(path.waitForExistence(timeout: 5), "The status bar is not there at all")
        XCTAssertTrue(
            window.frame.contains(path.frame),
            "The status bar is outside the window at \(description): "
                + "\(path.frame) against \(window.frame)",
            line: line
        )
    }
}
