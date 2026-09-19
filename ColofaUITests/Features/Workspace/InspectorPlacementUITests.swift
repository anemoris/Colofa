////
//  InspectorPlacementUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import XCTest

/// Where the columns end up once Repository Info is open, rather than whether they exist.
///
/// A column laid out past the window's edge still reports `exists`, which is how opening the
/// inspector used to push the sidebar off the leading edge and most of the inspector off the
/// trailing one without a single test noticing.
final class InspectorPlacementUITests: XCTestCase {
    private let repositoryPath = "/tmp/Colofa Inspector Placement UI"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Opened, then shrunk with it open, then reopened at the window's minimum: the two ways a
    /// window ends up narrower than every column with the inspector in it.
    @MainActor
    func testEnglishRepositoryInfoKeepsEveryColumnInsideTheWindow() {
        let application = XCUIApplication.configuredForRepository(
            path: repositoryPath,
            additionalArguments: [UITestingArgument.realRepositoryState]
        )
        application.launch()
        application.activate()

        let window = application.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let toggle = application.descendants(matching: .any)["baseline.inspector.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "The Repository Info toggle is missing")

        // Opening the inspector must not resize the window: the system inspector widened it by
        // its own width, and presented without animation it took 168pt off a 1180pt one.
        let openedWidth = window.frame.width
        toggle.click()
        assertColumnsAreInside(window, of: application, at: "the size it opened at")
        XCTAssertEqual(window.frame.width, openedWidth, "Opening Repository Info resized the window")

        window.shrinkToMinimum()
        assertColumnsAreInside(window, of: application, at: "its minimum size")

        toggle.click()
        XCTAssertTrue(
            application.descendants(matching: .any)["baseline.repositoryInspector"]
                .waitForNonExistence(timeout: 5),
            "Repository Info did not close"
        )
        toggle.click()
        assertColumnsAreInside(window, of: application, at: "its minimum size, reopened")
    }

    /// Hiding and showing the sidebar at the window's minimum width, with Repository Info open.
    /// The window's minimum is the columns' own, so the sidebar slides back in beside the panel:
    /// the panel stays open, every column stays inside the window, and the window keeps its size.
    @MainActor
    func testEnglishShowingTheSidebarAtTheMinimumWidthKeepsRepositoryInfoOpen() {
        let application = XCUIApplication.configuredForRepository(
            path: repositoryPath,
            additionalArguments: [UITestingArgument.realRepositoryState]
        )
        application.launch()
        application.activate()

        let window = application.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        window.shrinkToMinimum()
        XCTAssertEqual(window.frame.width, 1100, accuracy: 2, "The window's minimum width moved")

        let toggle = application.descendants(matching: .any)["baseline.inspector.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "The Repository Info toggle is missing")
        toggle.click()
        assertColumnsAreInside(window, of: application, at: "its minimum size")
        let minimumWidth = window.frame.width

        // The system's own toggle. Its label is not a reliable sign of the sidebar's state: it
        // can still read Hide Sidebar after the sidebar is gone, so the sidebar's own first row
        // says whether it is shown.
        let sidebarToggle = window.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "sidebar"))
            .firstMatch
        XCTAssertTrue(sidebarToggle.waitForExistence(timeout: 5), "The sidebar toggle is missing")
        let picker = application.descendants(matching: .any)["baseline.repositoryPicker"]
        let sidebarIsHidden = NSPredicate { element, _ in
            guard let element = element as? XCUIElement, element.exists else {
                return true
            }
            return !element.isHittable
        }

        sidebarToggle.click()
        XCTAssertTrue(waitUntil(sidebarIsHidden, on: picker), "The sidebar did not hide")

        sidebarToggle.click()
        XCTAssertTrue(
            waitUntil(NSPredicate(format: "hittable == true"), on: picker),
            "The sidebar did not come back"
        )
        assertColumnsAreInside(window, of: application, at: "its minimum size, sidebar shown again")
        XCTAssertEqual(window.frame.width, minimumWidth, "Showing the sidebar resized the window")
    }

    /// The sidebar's first row, the Changes column's section, and the inspector itself: one
    /// element from each column the overflow used to cut off.
    @MainActor
    private func assertColumnsAreInside(
        _ window: XCUIElement,
        of application: XCUIApplication,
        at description: String,
        line: UInt = #line
    ) {
        let inspector = application.descendants(matching: .any)["baseline.repositoryInspector"]
        XCTAssertTrue(inspector.waitForExistence(timeout: 5), "Repository Info did not open")

        let identifiers = [
            "baseline.repositoryPicker",
            "baseline.section.changes",
            "baseline.repositoryInspector",
        ]
        for identifier in identifiers {
            let element = application.descendants(matching: .any)[identifier]
            XCTAssertTrue(
                window.frame.contains(element.frame),
                "\(identifier) is outside the window at \(description): "
                    + "\(element.frame) against \(window.frame)",
                line: line
            )
        }
    }
}
