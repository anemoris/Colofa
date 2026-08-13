////
//  BaselineNavigationUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

final class BaselineNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEnglishLaunchAndNavigation() {
        let application = XCUIApplication.configuredForUITesting()
        // macOS UI automation can leave the test runner frontmost, so reactivate before click sequences.
        application.launch()
        application.activate()

        assertElement("baseline.repositoryPicker", label: "Open Repository", in: application)
        assertElement("baseline.section.changes", label: "Changes", in: application)
        assertElement("baseline.section.history", label: "History", in: application)
        assertElement("baseline.section.stashes", label: "Stashes", in: application)

        application.activate()
        application.descendants(matching: .any)["baseline.section.history"].click()
        assertElementExists("repository.empty", in: application)

        application.descendants(matching: .any)["baseline.section.stashes"].click()
        assertElementExists("repository.empty", in: application)

        assertElement("baseline.inspector.toggle", label: "Repository Info", in: application)
        let inspectorButton = application.descendants(matching: .any)["baseline.inspector.toggle"]
        application.activate()
        inspectorButton.click()
        assertElement("baseline.repositoryInspector", label: "Repository Info", in: application)
    }

    @MainActor
    private func assertElement(
        _ identifier: String,
        label: String,
        in application: XCUIApplication
    ) {
        let element = application.descendants(matching: .any)[identifier]
        guard element.exists || element.waitForExistence(timeout: 2) else {
            XCTFail("Missing accessibility identifier \(identifier)")
            return
        }

        XCTAssertTrue(
            element.label == label || element.value as? String == label,
            "Element \(identifier) has incorrect accessible text; expected \(label)"
        )
    }

    @MainActor
    private func assertElementExists(
        _ identifier: String,
        in application: XCUIApplication
    ) {
        let element = application.descendants(matching: .any)[identifier]
        XCTAssertTrue(
            element.exists || element.waitForExistence(timeout: 2),
            "Missing accessibility identifier \(identifier)"
        )
    }
}
