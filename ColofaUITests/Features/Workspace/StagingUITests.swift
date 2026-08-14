////
//  StagingUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

final class StagingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEnglishFileAndBulkStagingSurfaces() {
        let application = stagingApplication()
        prepareStagingApplication(application)

        let notes = application.descendants(matching: .any)["repository.unstaged.notes.txt"]
        XCTAssertTrue(notes.waitForExistence(timeout: 5))
        let rowAction = application.descendants(matching: .any)[
            "repository.unstaged.action.notes.txt"
        ]
        XCTAssertTrue(rowAction.exists)
        XCTAssertEqual(rowAction.label, "Stage File")

        notes.click()
        let detailAction = application.descendants(matching: .any)["repository.detail.action"]
        XCTAssertTrue(detailAction.waitForExistence(timeout: 2))
        XCTAssertEqual(detailAction.label, "Stage File")

        notes.rightClick()
        let contextAction = application.menuItems["Stage File"]
        XCTAssertTrue(contextAction.waitForExistence(timeout: 2))
        contextAction.click()
        let stagedNotes = application.descendants(matching: .any)["repository.staged.notes.txt"]
        XCTAssertTrue(stagedNotes.waitForExistence(timeout: 2))

        stagedNotes.click()
        let unstageDetailAction = application.descendants(matching: .any)["repository.detail.action"]
        XCTAssertTrue(unstageDetailAction.waitForExistence(timeout: 2))
        XCTAssertEqual(unstageDetailAction.label, "Unstage File")
        unstageDetailAction.click()
        XCTAssertTrue(notes.waitForExistence(timeout: 2))

        application.descendants(matching: .any)["repository.unstaged.action.notes.txt"].click()
        XCTAssertTrue(stagedNotes.waitForExistence(timeout: 2))

        let stageAll = application.descendants(matching: .any)["repository.stageAll"]
        XCTAssertTrue(stageAll.exists)
        stageAll.click()
        let conflict = application.descendants(matching: .any)["repository.unstaged.conflict.txt"]
        XCTAssertTrue(conflict.waitForExistence(timeout: 2))
        let conflictAction = application.descendants(matching: .any)[
            "repository.unstaged.action.conflict.txt"
        ]
        XCTAssertFalse(conflictAction.isEnabled)
        conflict.click()
        XCTAssertTrue(
            application.staticTexts["Resolve this Conflict in an editor before continuing."]
                .waitForExistence(timeout: 2)
        )

        let unstageAll = application.descendants(matching: .any)["repository.unstageAll"]
        XCTAssertTrue(unstageAll.exists)
        unstageAll.click()
        XCTAssertTrue(
            application.descendants(matching: .any)["repository.unstaged.added.swift"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertTrue(conflict.exists)
    }

    @MainActor
    func testEnglishStagingFailureUsesMutationErrorPresentation() {
        let application = stagingApplication(
            additionalArguments: [UITestingArgument.stageFailure]
        )
        application.launch()
        application.activate()

        let action = application.descendants(matching: .any)[
            "repository.unstaged.action.notes.txt"
        ]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.click()

        XCTAssertTrue(application.staticTexts["File Could Not Be Staged"].waitForExistence(timeout: 2))
        let alert = application.sheets.firstMatch
        XCTAssertTrue(alert.buttons["View Details"].exists)
        XCTAssertTrue(alert.buttons["OK"].exists)
        XCTAssertFalse(alert.buttons["Choose Another Repository"].exists)
        let failureBanner = application.descendants(matching: .any)["repository.failureBanner"]
        XCTAssertFalse(failureBanner.exists)

        alert.buttons["View Details"].click()
        XCTAssertTrue(failureBanner.waitForExistence(timeout: 2))
    }

    /// The Return-key default action must close the alert without revealing the
    /// failure details banner, which only View Details is allowed to surface.
    @MainActor
    func testEnglishStagingFailureDismissalKeepsDetailsHidden() {
        let application = stagingApplication(
            additionalArguments: [UITestingArgument.stageFailure]
        )
        application.launch()
        application.activate()

        let action = application.descendants(matching: .any)[
            "repository.unstaged.action.notes.txt"
        ]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.click()

        let alert = application.sheets.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        application.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(alert.waitForNonExistence(timeout: 2))
        let failureBanner = application.descendants(matching: .any)["repository.failureBanner"]
        XCTAssertFalse(failureBanner.exists)
    }

    @MainActor
    private func prepareStagingApplication(_ application: XCUIApplication) {
        application.launch()
        application.activate()
        application.menuBars.menuBarItems["Window"].click()
        application.menuItems["Zoom"].click()
        application.menuBars.menuBarItems["View"].click()
        application.menuItems["Repository Info"].click()
    }

    @MainActor
    private func stagingApplication(
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        XCUIApplication.configuredForUITesting(
            additionalArguments: [
                UITestingArgument.repositoryService,
                UITestingArgument.lastRepositoryPath, "/tmp/Colofa Staging UI",
                UITestingArgument.realRepositoryState,
            ] + additionalArguments
        )
    }
}
