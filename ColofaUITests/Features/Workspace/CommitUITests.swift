////
//  CommitUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

final class CommitUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEnglishComposerCommitsStagedChangesAndClearsItself() {
        let application = committableApplication()
        application.launch()
        application.activate()

        let summary = application.textFields["repository.commit.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        let branch = application.descendants(matching: .any)["repository.commit.branch"]
        XCTAssertEqual(branch.value as? String, "main")
        XCTAssertTrue(application.staticTexts["Staged Files"].exists)
        XCTAssertEqual(
            application.staticTexts["repository.commit.stagedCount"].value as? String,
            "1"
        )

        let action = application.buttons["repository.commit.action"]
        XCTAssertEqual(action.label, "Commit")
        XCTAssertFalse(action.isEnabled)
        XCTAssertTrue(
            application.staticTexts["Enter a Summary before committing."].exists,
            "A disabled Commit has to say why"
        )

        replaceText(of: summary, with: "Add the commit composer")
        replaceText(
            of: application.textFields["repository.commit.description"],
            with: "Why it exists."
        )
        XCTAssertTrue(waitUntil(NSPredicate(format: "isEnabled == true"), on: action))
        action.click()

        XCTAssertTrue(waitUntil(NSPredicate(format: "value == %@", ""), on: summary))
        assertEventuallyExists(
            application.staticTexts["Stage at least one change before committing."]
        )
        XCTAssertFalse(action.isEnabled)
        let upstream = application.staticTexts["repository.upstream"]
        XCTAssertTrue(upstream.waitForExistence(timeout: 2))
        XCTAssertEqual(upstream.value as? String, "origin/main, Ahead 1, Behind 0")
        application.descendants(matching: .any)["baseline.inspector.toggle"].click()
        let commitCount = application.descendants(matching: .any)["repository.commitCount"]
        XCTAssertTrue(commitCount.waitForExistence(timeout: 2))
        XCTAssertEqual(commitCount.value as? String, "13")
    }

    @MainActor
    func testEnglishSummaryLengthGuidanceIsSoft() {
        let application = committableApplication()
        application.launch()
        application.activate()

        let summary = application.textFields["repository.commit.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        replaceText(of: summary, with: String(repeating: "a", count: 51))

        assertEventuallyExists(
            application.staticTexts[
                "Summaries longer than 50 characters are shortened by most Git tools."
            ]
        )
        // Guidance only: the Commit itself stays available.
        XCTAssertTrue(application.buttons["repository.commit.action"].isEnabled)
    }

    @MainActor
    func testEnglishAmendPrefillsHeadAndWarnsBeforeRewritingPublishedHistory() {
        let application = committableApplication()
        application.launch()
        application.activate()

        let amend = application.checkBoxes["repository.commit.amend"]
        XCTAssertTrue(amend.waitForExistence(timeout: 5))
        amend.click()

        let summary = application.textFields["repository.commit.summary"]
        XCTAssertTrue(waitUntil(NSPredicate(format: "value == %@", "Published summary"), on: summary))
        XCTAssertEqual(
            application.textFields["repository.commit.description"].value as? String,
            "Published body"
        )

        let action = application.buttons["repository.commit.action"]
        XCTAssertEqual(action.label, "Amend Commit")
        action.click()

        assertEventuallyExists(application.staticTexts["Amend a Published Commit?"])
        let dialog = application.sheets.firstMatch
        XCTAssertTrue(
            application.staticTexts[
                "This Commit already exists on a remote. Amending rewrites History, so publishing"
                    + " it again will require an explicit Force Push."
            ].exists
        )
        XCTAssertTrue(dialog.buttons["Cancel"].exists)
        dialog.buttons["Amend Anyway"].click()

        XCTAssertTrue(waitUntil(NSPredicate(format: "value == %@", ""), on: summary))
        XCTAssertEqual(action.label, "Commit")
        XCTAssertFalse(
            application.staticTexts["Amend Canceled"].exists,
            "The Amend Colofa just ran is not an external HEAD change"
        )
    }

    @MainActor
    func testEnglishCleanRepositoryKeepsCommitCollapsedUntilAmendIsChosen() {
        let application = committableApplication(
            additionalArguments: [UITestingArgument.cleanCommitState]
        )
        application.launch()
        application.activate()

        XCTAssertFalse(application.textFields["repository.commit.summary"].exists)
        let expandAmend = application.buttons["Amend Commit"]
        XCTAssertTrue(expandAmend.waitForExistence(timeout: 5))
        expandAmend.click()

        let summary = application.textFields["repository.commit.summary"]
        XCTAssertTrue(waitUntil(NSPredicate(format: "value == %@", "Published summary"), on: summary))
        let action = application.buttons["repository.commit.action"]
        XCTAssertEqual(action.label, "Amend Commit")
        action.click()
        application.sheets.firstMatch.buttons["Amend Anyway"].click()

        XCTAssertTrue(waitUntil(NSPredicate(format: "exists == false"), on: summary))
        XCTAssertTrue(expandAmend.exists)
    }

    @MainActor
    func testEnglishCleanRepositoryHidesUnavailableAmendEntry() {
        assertCleanRepositoryHidesAmend(argument: UITestingArgument.detachedHead)
        assertCleanRepositoryHidesAmend(argument: UITestingArgument.rebase)
    }

    @MainActor
    func testEnglishFirstCommitWorksOnAnUnbornBranch() {
        let application = committableApplication(
            additionalArguments: [UITestingArgument.unbornCommitState]
        )
        application.launch()
        application.activate()

        let summary = application.textFields["repository.commit.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertFalse(application.checkBoxes["repository.commit.amend"].isEnabled)
        replaceText(of: summary, with: "Create the first commit")
        application.buttons["repository.commit.action"].click()

        XCTAssertTrue(waitUntil(NSPredicate(format: "exists == false"), on: summary))
        XCTAssertTrue(application.buttons["Amend Commit"].exists)
        application.descendants(matching: .any)["baseline.inspector.toggle"].click()
        let commitCount = application.descendants(matching: .any)["repository.commitCount"]
        XCTAssertTrue(commitCount.waitForExistence(timeout: 2))
        XCTAssertEqual(commitCount.value as? String, "1")
    }

    @MainActor
    func testEnglishCommitExplainsAnUnfinishedOperationAndDetachedHead() {
        let application = XCUIApplication.configuredForRealRepositoryState(
            path: "/tmp/Colofa Commit Unavailable"
        )
        application.launch()
        application.activate()

        let action = application.buttons["repository.commit.action"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        XCTAssertFalse(action.isEnabled)
        XCTAssertTrue(
            application.staticTexts[
                "Finish or abort the Git operation in progress before committing."
            ].exists
        )
        application.terminate()

        let detached = XCUIApplication.configuredForRealRepositoryState(
            path: "/tmp/Colofa Commit Detached",
            additionalArguments: [UITestingArgument.detachedHead]
        )
        detached.launch()
        detached.activate()

        XCTAssertTrue(
            detached.staticTexts[
                "HEAD is detached. Create a Branch first so the Commit stays reachable."
            ].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(detached.buttons["repository.commit.action"].isEnabled)
    }

    @MainActor
    func testEnglishCommitExplainsConflictsAndMissingIdentity() {
        let conflict = committableApplication(
            additionalArguments: [UITestingArgument.commitConflict]
        )
        conflict.launch()
        conflict.activate()

        XCTAssertTrue(
            conflict.staticTexts[
                "Resolve every Conflict before committing."
            ].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(conflict.buttons["repository.commit.action"].isEnabled)
        conflict.terminate()

        let missingIdentity = committableApplication(
            additionalArguments: [UITestingArgument.missingCommitIdentity]
        )
        missingIdentity.launch()
        missingIdentity.activate()

        XCTAssertTrue(
            missingIdentity.staticTexts[
                "Set user.name and user.email in Repository Info before committing."
            ].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(missingIdentity.buttons["repository.commit.action"].isEnabled)
    }

    @MainActor
    func testEnglishHookAndSigningFailuresKeepTheWrittenMessage() {
        assertFailureKeepsMessage(
            argument: UITestingArgument.commitHookFailure,
            summary: "Rejected by a hook"
        )
        assertFailureKeepsMessage(
            argument: UITestingArgument.commitSigningFailure,
            summary: "Signing failed"
        )
    }

    @MainActor
    private func assertFailureKeepsMessage(argument: String, summary text: String) {
        let application = committableApplication(additionalArguments: [argument])
        application.launch()
        application.activate()

        let summary = application.textFields["repository.commit.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        replaceText(of: summary, with: text)
        application.buttons["repository.commit.action"].click()

        XCTAssertTrue(
            application.staticTexts["Commit Could Not Be Created"].waitForExistence(timeout: 2)
        )
        application.sheets.firstMatch.buttons["OK"].click()

        XCTAssertEqual(summary.value as? String, text)
        application.terminate()
    }

    @MainActor
    private func assertCleanRepositoryHidesAmend(argument: String) {
        let application = committableApplication(
            additionalArguments: [UITestingArgument.cleanCommitState, argument]
        )
        application.launch()
        application.activate()

        let emptyState = application.descendants(matching: .any)["baseline.empty.changes"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5))
        XCTAssertFalse(application.buttons["Amend Commit"].exists)
        application.terminate()
    }

    @MainActor
    private func committableApplication(
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        XCUIApplication.configuredForRepository(
            path: "/tmp/Colofa Commit UI",
            additionalArguments: [UITestingArgument.committableState] + additionalArguments
        )
    }
}
