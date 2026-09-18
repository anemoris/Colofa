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
        shrinkToMinimum(window)
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

    /// Drags the window as small as it will go, from inside both edges: an edge flush with the
    /// screen's own has nothing outside it left to click.
    @MainActor
    private func shrinkToMinimum(_ window: XCUIElement) {
        for _ in 0..<2 {
            let bottom = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1))
                .withOffset(CGVector(dx: 0, dy: -2))
            bottom.click(
                forDuration: 0.3,
                thenDragTo: bottom.withOffset(CGVector(dx: 0, dy: -600)),
                withVelocity: .fast,
                thenHoldForDuration: 0
            )

            let trailing = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
                .withOffset(CGVector(dx: -2, dy: 0))
            trailing.click(
                forDuration: 0.3,
                thenDragTo: trailing.withOffset(CGVector(dx: -600, dy: 0)),
                withVelocity: .fast,
                thenHoldForDuration: 0
            )
        }
    }
}
