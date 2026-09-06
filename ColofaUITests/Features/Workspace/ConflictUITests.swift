////
//  ConflictUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// Resolving the Conflict a Merge left, and the two ways out of the operation it belongs to.
final class ConflictUITests: XCTestCase {
    private static let branchIdentifier = "repository.ref.local.feature/真实"
    private static let conflictRow = "repository.unstaged.conflict.txt"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// A Merge that stopped at a Conflict raises no alert: it leaves the banner, the two exits,
    /// and the conflicted path at the top of Changes.
    @MainActor
    func testEnglishAconflictedMergeShowsTheBannerAndItsTwoExits() {
        let application = launchConflictedMerge()

        let banner = application.descendants(matching: .any)["repository.operation"]
        assertEventuallyExists(banner, "The unfinished Merge is not on screen")
        XCTAssertTrue(
            (banner.value as? String)?.contains("Merge in Progress") == true,
            "The banner does not say which operation is unfinished"
        )
        XCTAssertTrue(
            application.descendants(matching: .any)["repository.operation.abort"].exists,
            "The unfinished Merge offers no Abort"
        )
        // The only blocking work is immediately visible.
        assertEventuallyExists(
            application.descendants(matching: .any)[Self.conflictRow],
            "The conflicted path is not in Changes"
        )
    }

    /// An operation must not be finished over a Conflict nobody decided.
    @MainActor
    func testEnglishContinueIsUnavailableUntilEveryPathIsResolved() {
        let application = launchConflictedMerge()

        let continueButton = application.descendants(matching: .any)["repository.operation.continue"]
        assertEventuallyExists(continueButton, "Continue is not on the banner")
        XCTAssertFalse(continueButton.isEnabled, "Continue was offered over an unmerged path")

        markResolved(in: application)

        XCTAssertTrue(
            waitUntil(NSPredicate(format: "isEnabled == true"), on: continueButton),
            "Continue stayed unavailable after the last Conflict was resolved"
        )
    }

    /// The complete-version choices are named after real Refs rather than after positions in a
    /// Git command.
    @MainActor
    func testEnglishTheVersionChoicesUseRealBranchNames() {
        let application = launchConflictedMerge()
        openConflictMenu(in: application)

        let current = application.descendants(matching: .menuItem)["repository.conflict.useCurrent"]
        let incoming = application.descendants(matching: .menuItem)[
            "repository.conflict.useIncoming"
        ]
        XCTAssertTrue(current.waitForExistence(timeout: 5), "The current version is not offered")
        XCTAssertTrue(incoming.exists, "The incoming version is not offered")
        XCTAssertEqual(current.title, "Use Version from “main”")
        XCTAssertEqual(incoming.title, "Use Version from “feature/真实”")
        application.typeKey(.escape, modifierFlags: [])
    }

    /// Manual line-level resolution happens outside Colofa, which has no three-way editor.
    @MainActor
    func testEnglishAconflictOffersOpenInDefaultEditor() {
        let application = launchConflictedMerge()
        openConflictMenu(in: application)

        let open = application.descendants(matching: .menuItem)[
            "repository.conflict.openInDefaultEditor"
        ]
        XCTAssertTrue(open.waitForExistence(timeout: 5), "Open in Default Editor is not offered")
        XCTAssertTrue(open.isEnabled)
        application.typeKey(.escape, modifierFlags: [])
    }

    /// Mark as Resolved records what the file holds; it says nothing about having merged it.
    @MainActor
    func testEnglishMarkAsResolvedStagesThePathAndEndsTheConflict() {
        let application = launchConflictedMerge()

        markResolved(in: application)

        XCTAssertTrue(
            waitUntil(
                NSPredicate(format: "exists == false"),
                on: application.descendants(matching: .any)[Self.conflictRow]
            ),
            "The path is still reported as conflicted"
        )
        assertEventuallyExists(
            application.descendants(matching: .any)["repository.staged.conflict.txt"],
            "Mark as Resolved did not stage the path"
        )
    }

    @MainActor
    func testEnglishContinueCompletesTheMerge() {
        let application = launchConflictedMerge()
        markResolved(in: application)

        let continueButton = application.descendants(matching: .any)["repository.operation.continue"]
        XCTAssertTrue(
            waitUntil(NSPredicate(format: "isEnabled == true"), on: continueButton),
            "Continue stayed unavailable after the Conflict was resolved"
        )
        continueButton.click()

        XCTAssertTrue(
            waitUntil(
                NSPredicate(format: "exists == false"),
                on: application.descendants(matching: .any)["repository.operation"]
            ),
            "The unfinished Merge is still on screen"
        )
    }

    /// Abort is Git's own merge rollback, so the Conflict and the operation both go.
    @MainActor
    func testEnglishAbortRollsTheMergeBack() {
        let application = launchConflictedMerge()

        let abort = application.descendants(matching: .any)["repository.operation.abort"]
        assertEventuallyExists(abort, "Abort is not on the banner")
        abort.click()

        XCTAssertTrue(
            waitUntil(
                NSPredicate(format: "exists == false"),
                on: application.descendants(matching: .any)["repository.operation"]
            ),
            "The unfinished Merge is still on screen"
        )
        XCTAssertFalse(
            application.descendants(matching: .any)[Self.conflictRow].exists,
            "Abort left the Conflict behind"
        )
    }

    /// A Rebase has its own recovery commands, so a merge rollback is not offered for it.
    @MainActor
    func testEnglishAnotherUnfinishedOperationOffersNoMergeExits() {
        let application = XCUIApplication.configuredForRealRepositoryState(
            path: FileManager.default.temporaryDirectory.path(percentEncoded: false),
            additionalArguments: [UITestingArgument.rebase]
        )
        application.launch()
        application.activate()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.operation"],
            "The unfinished operation is not on screen"
        )
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.operation.abort"].exists,
            "A Rebase offered a merge rollback"
        )
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.operation.continue"].exists,
            "A Rebase offered a merge Continue"
        )
    }

    /// Runs one Merge that stops at a Conflict, which is where every case above starts.
    @MainActor
    private func launchConflictedMerge() -> XCUIApplication {
        let application = XCUIApplication.configuredForMergeState(
            path: FileManager.default.temporaryDirectory.path(percentEncoded: false),
            additionalArguments: [UITestingArgument.mergeConflict]
        )
        application.launch()
        application.activate()

        let branch = application.descendants(matching: .any)[Self.branchIdentifier]
        assertEventuallyExists(branch, "The branch is not in the sidebar")
        rightClickWhenReady(branch)
        let merge = application.descendants(matching: .menuItem)["repository.ref.merge"]
        XCTAssertTrue(merge.waitForExistence(timeout: 5), "Merge is not in the Ref's menu")
        clickWhenReady(merge)

        let confirm = application.descendants(matching: .any)["repository.merge.confirm"]
        assertEventuallyExists(confirm, "The Merge confirmation did not open")
        confirm.click()
        return application
    }

    @MainActor
    private func openConflictMenu(in application: XCUIApplication) {
        let row = application.descendants(matching: .any)[Self.conflictRow]
        assertEventuallyExists(row, "The conflicted path is not in Changes")
        rightClickWhenReady(row)
    }

    @MainActor
    private func markResolved(in application: XCUIApplication) {
        openConflictMenu(in: application)
        let markResolved = application.descendants(matching: .menuItem)[
            "repository.conflict.markResolved"
        ]
        XCTAssertTrue(
            markResolved.waitForExistence(timeout: 5),
            "Mark as Resolved is not in the Change's menu"
        )
        clickWhenReady(markResolved)
    }
}
