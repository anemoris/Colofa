////
//  MergeUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// Merge, driven the way a user reaches it: from the Branch's own context menu in the sidebar.
final class MergeUITests: XCTestCase {
    private static let branchIdentifier = "repository.ref.local.feature/真实"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The confirmation says which Branch comes in and which it lands on, and opens on ordinary
    /// Git behaviour.
    @MainActor
    func testEnglishTheConfirmationNamesBothBranchesAndDefaultsToDefault() {
        let application = mergeApplication()
        application.launch()
        application.activate()

        openMergeDialog(in: application)

        let source = application.descendants(matching: .any)["repository.merge.source"]
        let target = application.descendants(matching: .any)["repository.merge.target"]
        XCTAssertEqual(source.value as? String, "feature/真实")
        XCTAssertEqual(target.value as? String, "main")

        let strategy = application.descendants(matching: .any)["repository.merge.strategy"]
        assertEventuallyExists(strategy, "The strategy choices are not on the confirmation")
        for title in ["Default", "Fast-forward Only", "Always Create Merge Commit"] {
            XCTAssertTrue(
                application.sheets.radioButtons[title].exists,
                "“\(title)” is not offered"
            )
        }
        // Read from the note beside the choices, whose text follows the selected strategy: what
        // a radio button reports as its value is an encoding, and this is the sentence the user
        // actually sees.
        let description = application.descendants(matching: .any)[
            "repository.merge.strategyDescription"
        ]
        XCTAssertTrue(
            (description.value as? String)?.contains("Fast-forwards when Git can") == true,
            "Default was not the selected strategy"
        )
    }

    /// A Merge Git accepted closes the dialog and leaves nothing to explain.
    @MainActor
    func testEnglishConfirmingRunsTheMergeAndClosesTheDialog() {
        let application = mergeApplication()
        application.launch()
        application.activate()

        openMergeDialog(in: application)
        application.descendants(matching: .any)["repository.merge.confirm"].click()

        XCTAssertTrue(
            waitUntil(
                NSPredicate(format: "exists == false"),
                on: application.descendants(matching: .any)["repository.merge.confirm"]
            ),
            "The Merge confirmation is still on screen"
        )
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.operation"].exists,
            "A Merge that succeeded left an unfinished operation behind"
        )
    }

    @MainActor
    func testEnglishCancellingLeavesTheRepositoryAlone() {
        let application = mergeApplication()
        application.launch()
        application.activate()

        openMergeDialog(in: application)
        application.descendants(matching: .any)["repository.merge.cancel"].click()

        XCTAssertTrue(
            waitUntil(
                NSPredicate(format: "exists == false"),
                on: application.descendants(matching: .any)["repository.merge.confirm"]
            ),
            "The Merge confirmation is still on screen"
        )
        assertEventuallyExists(
            application.descendants(matching: .any)[Self.branchIdentifier],
            "Cancelling changed the sidebar"
        )
    }

    /// Colofa neither stashes tracked work nor merges around it, so the menu item refuses itself
    /// and says which of the two the user can do instead.
    @MainActor
    func testEnglishTrackedLocalChangesRefuseTheMergeWithCommitOrStashGuidance() {
        let application = mergeApplication(
            additionalArguments: [UITestingArgument.mergeLocalChanges]
        )
        application.launch()
        application.activate()

        let branch = application.descendants(matching: .any)[Self.branchIdentifier]
        assertEventuallyExists(branch, "The branch is not in the sidebar")
        rightClickWhenReady(branch)

        let merge = application.descendants(matching: .menuItem)["repository.ref.merge"]
        XCTAssertTrue(merge.waitForExistence(timeout: 5), "Merge is not in the Ref's menu")
        XCTAssertFalse(merge.isEnabled, "Merge ran over tracked local changes")
        application.typeKey(.escape, modifierFlags: [])
    }

    /// Unrelated untracked work must not block integration.
    @MainActor
    func testEnglishUntrackedWorkAloneStillPermitsTheMerge() {
        let application = mergeApplication(
            additionalArguments: [UITestingArgument.mergeUntrackedOnly]
        )
        application.launch()
        application.activate()

        openMergeDialog(in: application)
        XCTAssertTrue(
            application.descendants(matching: .any)["repository.merge.confirm"].isEnabled
        )
    }

    /// An untracked file where the merge would have written is Git's own refusal, and the alert
    /// names the path it protected.
    @MainActor
    func testEnglishApathCollisionNamesTheAffectedFile() {
        let application = mergeApplication(
            additionalArguments: [UITestingArgument.mergeCollision]
        )
        application.launch()
        application.activate()

        openMergeDialog(in: application)
        application.descendants(matching: .any)["repository.merge.confirm"].click()

        assertEventuallyExists(
            application.sheets.staticTexts.matching(
                NSPredicate(format: "value CONTAINS %@", "notes.txt")
            ).firstMatch,
            "The refusal did not name the untracked file it protected"
        )
        application.sheets.buttons["OK"].click()
    }

    /// Fast-forward Only means exactly what Git means by it.
    @MainActor
    func testEnglishFastForwardOnlyReportsAmergeGitWouldNotFastForward() {
        let application = mergeApplication(
            additionalArguments: [UITestingArgument.mergeNotFastForward]
        )
        application.launch()
        application.activate()

        openMergeDialog(in: application)
        application.sheets.radioButtons["Fast-forward Only"].click()
        application.descendants(matching: .any)["repository.merge.confirm"].click()

        assertEventuallyExists(
            application.sheets.staticTexts.matching(
                NSPredicate(format: "value CONTAINS %@", "Merge Failed")
            ).firstMatch,
            "A refused Fast-forward Only Merge was not reported"
        )
        application.sheets.buttons["OK"].click()
    }

    /// Merging the Branch HEAD is already on has nothing to bring in, and the action says so
    /// rather than disappearing.
    @MainActor
    func testEnglishTheCurrentBranchOffersMergeDisabled() {
        let application = mergeApplication()
        application.launch()
        application.activate()

        let head = application.descendants(matching: .any)["repository.head"]
        assertEventuallyExists(head, "The current Branch is not in the sidebar")
        rightClickWhenReady(head)

        let merge = application.descendants(matching: .menuItem)["repository.ref.merge"]
        XCTAssertTrue(merge.waitForExistence(timeout: 5), "Merge is not in the Ref's menu")
        XCTAssertFalse(merge.isEnabled, "The current Branch offered a Merge that could run")
        application.typeKey(.escape, modifierFlags: [])
    }

    /// Merging a tag is not the workflow this app is about, so the action is absent rather than
    /// present and permanently refused.
    @MainActor
    func testEnglishAtagOffersNoMergeAtAll() {
        let application = mergeApplication()
        application.launch()
        application.activate()

        let tag = application.descendants(matching: .any)["repository.ref.tag.v1.0-测试"]
        assertEventuallyExists(tag, "The tag is not in the sidebar")
        rightClickWhenReady(tag)

        let checkout = application.descendants(matching: .menuItem)["repository.ref.checkout"]
        XCTAssertTrue(checkout.waitForExistence(timeout: 5), "The Ref's menu did not open")
        XCTAssertFalse(
            application.descendants(matching: .menuItem)["repository.ref.merge"].exists,
            "A tag offered a Merge"
        )
        application.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    private func mergeApplication(
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        XCUIApplication.configuredForMergeState(
            path: FileManager.default.temporaryDirectory.path(percentEncoded: false),
            additionalArguments: additionalArguments
        )
    }

    /// Reached by its identifier rather than its title, because the Branch menu offers Merge
    /// under the same title and a title query matches both.
    @MainActor
    private func openMergeDialog(in application: XCUIApplication) {
        let branch = application.descendants(matching: .any)[Self.branchIdentifier]
        assertEventuallyExists(branch, "The branch is not in the sidebar")
        rightClickWhenReady(branch)

        let merge = application.descendants(matching: .menuItem)["repository.ref.merge"]
        XCTAssertTrue(merge.waitForExistence(timeout: 5), "Merge is not in the Ref's menu")
        clickWhenReady(merge)

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.merge.confirm"],
            "The Merge confirmation did not open"
        )
    }
}
