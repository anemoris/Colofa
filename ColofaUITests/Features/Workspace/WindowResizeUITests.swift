////
//  WindowResizeUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// Resizing the window by hand, which is the one layout change no fixture launch performs.
final class WindowResizeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// A window shorter than the height its content insists on is the state this guards. The
    /// Commit composer used to set that floor: the Changes column could not be shorter than the
    /// composer, the window's own minimum let the window be shorter than that, and dragging an
    /// edge in that state made AppKit re-solve the split view's constraints indefinitely. It ends
    /// with `NSGenericException: The window has been marked as needing another Update Constraints
    /// in Window pass, but it has already had more Update Constraints in Window passes than there
    /// are views in the window`, which terminates the app — from Xcode, a window that has stopped
    /// responding.
    @MainActor
    func testEnglishResizingAwindowSmallerThanItsContentKeepsTheAppRunning() {
        // The window's size is saved for the app, not for a Repository, so a window left small by
        // a Repository with little in it is the window the next Repository opens in — even when
        // that one's Changes column asks for more height than the window has.
        let small = XCUIApplication.configuredForUITesting()
        small.launch()
        small.activate()
        let smallWindow = small.windows.firstMatch
        XCTAssertTrue(smallWindow.waitForExistence(timeout: 10))
        normalize(smallWindow)
        small.terminate()

        let application = XCUIApplication.configuredForRepository(
            path: "/tmp/Colofa Window Resize UI",
            additionalArguments: [UITestingArgument.committableState]
        )
        application.launch()
        application.activate()

        // The reason Commit is unavailable is the composer's own content, and the reason this
        // Repository's Changes column is taller than the window it opens in.
        let reason = application.descendants(matching: .any)["repository.commit.unavailableReason"]
        assertEventuallyExists(reason, "The composer did not explain why Commit is unavailable")

        let window = application.windows.firstMatch
        for (step, resize) in Self.resizes.enumerated() {
            drag(window, resize)
            XCTAssertEqual(
                application.state,
                .runningForeground,
                "Colofa stopped running after resize \(step + 1)"
            )
        }
        XCTAssertTrue(reason.exists, "The composer lost its explanation while resizing")
    }

    /// Puts the window in the state the second launch starts from: as short as this Repository's
    /// content allows, and a known width.
    @MainActor
    private func normalize(_ window: XCUIElement) {
        drag(window, (.bottom, -600))
        for _ in 0..<8 {
            let difference = Self.startingWidth - window.frame.width
            if abs(difference) <= 2 {
                break
            }
            drag(window, (.trailing, difference))
        }
        XCTAssertEqual(window.frame.width, Self.startingWidth, accuracy: 2)
    }

    private enum Edge {
        case trailing
        case bottom
    }

    private static let startingWidth = 1160.0

    /// Narrower then wider, and shorter then taller, twice over: the defect needs the column's
    /// width to change in both directions while its height is in play.
    private static let resizes: [(edge: Edge, distance: Double)] = [
        (.trailing, -220), (.bottom, -220), (.trailing, 220), (.bottom, 220),
        (.trailing, -220), (.bottom, -220), (.trailing, 220), (.bottom, 220),
    ]

    @MainActor
    private func drag(_ window: XCUIElement, _ resize: (edge: Edge, distance: Double)) {
        // Grabbed just inside the frame: the resize area straddles the window's edge, and an
        // edge flush with the screen's own has nothing outside it left to click.
        let start: XCUICoordinate
        let offset: CGVector
        switch resize.edge {
        case .trailing:
            start = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
                .withOffset(CGVector(dx: -2, dy: 0))
            offset = CGVector(dx: resize.distance, dy: 0)
        case .bottom:
            start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1))
                .withOffset(CGVector(dx: 0, dy: -2))
            offset = CGVector(dx: 0, dy: resize.distance)
        }
        start.click(
            forDuration: 0.3,
            thenDragTo: start.withOffset(offset),
            withVelocity: .fast,
            thenHoldForDuration: 0
        )
    }
}
