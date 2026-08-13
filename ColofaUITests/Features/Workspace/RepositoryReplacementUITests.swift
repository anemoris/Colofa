////
//  RepositoryReplacementUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// Covers replacing the open Repository through the sidebar identity control, which is the only
/// workflow that drives the folder picker twice in a row.
final class RepositoryReplacementUITests: XCTestCase {
    private static let restoredName = "Colofa Reopen"
    private static let restoredPath = "/tmp/Colofa Reopen"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Replays the reported failure: open a Repository from the picker, then open the picker
    /// again. Two separate defects hide in that sequence, so both steps are asserted.
    ///
    /// With a Repository open the identity control grows a second line. Without an explicit
    /// content shape only the glyphs are hit-testable, so clicking the row does nothing. And a
    /// completed selection must leave the presentation state reset, otherwise the panel never
    /// comes back even when the click does land.
    @MainActor
    func testEnglishIdentityControlReplacesRepositoryRepeatedly() throws {
        let application = XCUIApplication.configuredForRepository(path: Self.restoredPath)
        application.launch()
        application.activate()

        let picker = application.descendants(matching: .any)["baseline.repositoryPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertEqual(picker.value as? String, Self.restoredName)

        picker.click()
        chooseHomeDirectory(in: application)

        // The chosen directory is the machine's home, so the test asserts that the Repository was
        // replaced and stayed self-consistent rather than pinning a path. Resolving the real home
        // here is not an option: the test runner is sandboxed and would report its container.
        XCTAssertTrue(
            picker.waitForValue(differingFrom: Self.restoredName, timeout: 10),
            "the chosen Repository never replaced the restored one"
        )
        let replacedPath = try XCTUnwrap(
            application.descendants(matching: .any)["repository.path"].value as? String
        )
        XCTAssertNotEqual(replacedPath, Self.restoredPath)
        XCTAssertEqual(
            URL(filePath: replacedPath, directoryHint: .isDirectory).lastPathComponent,
            picker.value as? String
        )

        picker.click()
        XCTAssertTrue(
            application.sheets.firstMatch.waitForExistence(timeout: 8),
            "the picker did not reopen after a completed selection"
        )
        application.typeKey(.escape, modifierFlags: [])
    }

    /// Confirms the open panel on the home directory.
    ///
    /// Pinning the panel to a fixed location matters: it otherwise restores whatever directory it
    /// last used, so both the selection and the Open button's enabled state would depend on
    /// machine state rather than on the app under test.
    @MainActor
    private func chooseHomeDirectory(in application: XCUIApplication) {
        let sheet = application.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 8))
        application.typeKey("h", modifierFlags: [.command, .shift])
        let openButton = sheet.buttons["OKButton"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 2))
        XCTAssertTrue(openButton.isEnabled)
        openButton.click()
    }
}
