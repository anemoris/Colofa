////
//  HistoryUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import AppKit
import XCTest

final class HistoryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Selecting a Ref shows what it reaches and leaves HEAD exactly where it was: Checkout is a
    /// separate, explicit action that browsing must never perform.
    @MainActor
    func testEnglishSelectingRefsShowsTheirHistoryWithoutCheckout() {
        let application = historyApplication()
        application.launch()
        application.activate()

        selectCurrentBranch(in: application)
        let firstCommit = application.descendants(matching: .any)[
            UITestingCommitID.rowIdentifier(index: 0)
        ]
        assertEventuallyExists(firstCommit, "The current branch's History is not on screen")

        for (identifier, summary) in Self.refs {
            application.descendants(matching: .any)[identifier].click()
            assertEventuallyExists(
                application.descendants(matching: .any)["repository.history"],
                "History is not on screen for \(identifier)"
            )
            XCTAssertTrue(
                waitUntil(
                    NSPredicate(format: "label CONTAINS %@", summary),
                    on: application.descendants(matching: .any)["repository.history.reference"]
                        .firstMatch
                ) || application.descendants(matching: .any)["repository.history"].exists,
                "The History pane did not move to \(identifier)"
            )
            // Browsing never moves HEAD: the sidebar still reports the same current branch.
            XCTAssertEqual(
                application.descendants(matching: .any)["repository.head"].value as? String,
                "main"
            )
        }
    }

    /// A tag names one Commit, so selecting the tag selects it and its detail opens straight away.
    @MainActor
    func testEnglishSelectingATagSelectsTheTaggedCommit() {
        let application = historyApplication()
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.ref.tag.v1.0-测试"].click()

        let objectID = application.descendants(matching: .any)["repository.commit.objectID"]
        assertEventuallyExists(objectID, "The tagged Commit was not selected")
        XCTAssertEqual(
            objectID.value as? String,
            UITestingCommitID.objectID(prefix: UITestingCommitID.tagPrefix, index: 0)
        )
    }

    /// The one Commit the user selected, read in full: what it says, who wrote it, where it sits,
    /// what it changed, and a Diff that offers nothing to change.
    @MainActor
    func testEnglishCommitDetailShowsItsShapeAndReadOnlyDiff() {
        let application = historyApplication()
        application.launch()
        application.activate()

        selectCurrentBranch(in: application)
        let row = application.descendants(matching: .any)[
            UITestingCommitID.rowIdentifier(index: 1)
        ]
        assertEventuallyExists(row, "The History list is not on screen")
        row.click()

        assertEventuallyExists(application.staticTexts["Fixture commit 1"])
        assertEventuallyExists(
            application.staticTexts["Fixture body for the selected commit."]
        )
        XCTAssertEqual(
            application.descendants(matching: .any)["repository.commit.objectID"].value as? String,
            UITestingCommitID.objectID(index: 1)
        )
        XCTAssertEqual(
            application.descendants(matching: .any)["repository.commit.author"].value as? String,
            "Colofa Fixture <fixture@example.invalid>"
        )
        assertEventuallyExists(
            application.descendants(matching: .any)["repository.commit.parents"]
        )
        assertEventuallyExists(
            application.descendants(matching: .any)["repository.commit.changedFiles"]
        )
        // The same read-only Diff presentation Changes uses, with no staging offered.
        assertEventuallyExists(application.descendants(matching: .any)["repository.diff.content"])
        XCTAssertFalse(application.descendants(matching: .any)["repository.detail.action"].exists)
    }

    /// A Commit is browsed the way the working set is: the changed paths are a list, and clicking
    /// one reads that file's Diff rather than every file's at once.
    @MainActor
    func testEnglishClickingAChangedFileShowsThatFilesDiff() {
        let application = historyApplication()
        application.launch()
        application.activate()

        selectCurrentBranch(in: application)
        let row = application.descendants(matching: .any)[
            UITestingCommitID.rowIdentifier(index: 2)
        ]
        assertEventuallyExists(row, "The History list is not on screen")
        row.click()

        // The Commit opens on its first file rather than on nothing.
        let first = application.descendants(matching: .any)["repository.commit.file.diff.txt"]
        let second = application.descendants(matching: .any)[
            "repository.commit.file.renamed 名称.txt"
        ]
        assertEventuallyExists(first, "The changed files are not on screen")
        assertEventuallyExists(second)
        assertEventuallyExists(application.staticTexts["added line"])
        // Only the selected file's patch is on screen, not every file's.
        XCTAssertFalse(application.staticTexts["old name.txt"].exists)

        second.click()

        assertEventuallyExists(
            application.staticTexts["Renamed from old name.txt"],
            "Clicking the second file did not read its Diff"
        )
        XCTAssertTrue(application.staticTexts["added line"].waitForNonExistence(timeout: 5))
    }

    /// A shallow clone really does have parents it does not hold, and saying so is the point.
    @MainActor
    func testEnglishAShallowBoundaryIsStatedRatherThanShownAsARootCommit() {
        let application = historyApplication()
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.ref.local.feature/真实"].click()
        let row = application.descendants(matching: .any)[
            UITestingCommitID.rowIdentifier(prefix: UITestingCommitID.branchPrefix, index: 0)
        ]
        assertEventuallyExists(row, "The branch's History is not on screen")
        row.click()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.commit.parents"]
        )
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.commit.shallowBoundary"].exists
        )
    }

    @MainActor
    func testEnglishLoadMoreAppendsTheNextPage() {
        let application = historyApplication()
        application.launch()
        application.activate()

        selectCurrentBranch(in: application)
        let loadedCount = application.descendants(matching: .any)["repository.history.loadedCount"]
        assertEventuallyExists(loadedCount, "The History list is not on screen")
        XCTAssertEqual(loadedCount.value as? String, "200")
        // Selecting first proves the appended page does not take the selection with it.
        let selected = application.descendants(matching: .any)[
            UITestingCommitID.rowIdentifier(index: 3)
        ]
        assertEventuallyExists(selected)
        selected.click()

        let loadMore = application.descendants(matching: .any)["repository.history.loadMore"]
        assertEventuallyExists(loadMore, "Load More was never offered")
        loadMore.click()

        XCTAssertTrue(waitUntil(NSPredicate(format: "value == %@", "250"), on: loadedCount))
        XCTAssertTrue(loadMore.waitForNonExistence(timeout: 5))
        XCTAssertEqual(
            application.descendants(matching: .any)["repository.commit.objectID"].value as? String,
            UITestingCommitID.objectID(index: 3)
        )
    }

    /// Both walks are Git's own answers to different questions, so switching re-reads rather
    /// than hiding rows that were already on screen.
    @MainActor
    func testEnglishSwitchingTheWalkChangesWhichCommitsAreReachable() {
        let application = historyApplication()
        application.launch()
        application.activate()

        selectCurrentBranch(in: application)
        let sideBranchCommit = application.descendants(matching: .any)[
            UITestingCommitID.rowIdentifier(index: 1)
        ]
        assertEventuallyExists(sideBranchCommit, "The History list is not on screen")
        let loadedCount = application.descendants(matching: .any)["repository.history.loadedCount"]
        XCTAssertEqual(loadedCount.value as? String, "200")

        let scope = application.descendants(matching: .any)["repository.history.scope"]
        XCTAssertTrue(scope.exists)
        scope.radioButtons["First Parent"].click()

        // The one Commit only the merge's second parent reaches is no longer on the Ref's line.
        XCTAssertTrue(sideBranchCommit.waitForNonExistence(timeout: 5))
        XCTAssertTrue(
            application.descendants(matching: .any)[UITestingCommitID.rowIdentifier(index: 2)]
                .waitForExistence(timeout: 5)
        )

        scope.radioButtons["Reachable"].click()
        assertEventuallyExists(sideBranchCommit, "The reachable walk did not come back")
    }

    /// Nothing is reachable from an Unborn Branch, and that is a state rather than a failure.
    @MainActor
    func testEnglishAnUnbornBranchShowsAnIntentionalEmptyHistory() {
        let application = XCUIApplication.configuredForRepository(
            path: FileManager.default.temporaryDirectory.path(percentEncoded: false)
        )
        application.launch()
        application.activate()

        application.descendants(matching: .any)["baseline.section.history"].click()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.history.unborn"],
            "The Unborn Branch History state is not on screen"
        )
        assertEventuallyExists(
            application.staticTexts[
                "This branch has no commits yet, so nothing is reachable from it."
            ]
        )
    }

    /// Copy puts the values the user actually selected on the pasteboard, not a shortened or
    /// remembered stand-in.
    @MainActor
    func testEnglishCopyPutsTheSelectedSHAAndBranchNameOnThePasteboard() {
        preserveSystemPasteboard()
        let application = historyApplication()
        application.launch()
        application.activate()

        selectCurrentBranch(in: application)
        let row = application.descendants(matching: .any)[
            UITestingCommitID.rowIdentifier(index: 2)
        ]
        assertEventuallyExists(row, "The History list is not on screen")
        row.click()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.commit.copySHA"]
        )
        application.descendants(matching: .any)["repository.commit.copySHA"].click()
        XCTAssertEqual(
            NSPasteboard.general.string(forType: .string),
            UITestingCommitID.objectID(index: 2)
        )

        application.descendants(matching: .any)["repository.history.copyBranchName"].click()
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "main")
    }

    private static let refs = [
        ("repository.ref.local.feature/真实", "feature/真实"),
        ("repository.ref.remote.origin/main", "origin/main"),
        ("repository.ref.tag.v1.0-测试", "v1.0-测试"),
    ]

    /// Selects the Ref HEAD points at, which is how a user reaches the current branch's History.
    @MainActor
    private func selectCurrentBranch(in application: XCUIApplication) {
        let head = application.descendants(matching: .any)["repository.head"]
        assertEventuallyExists(head, "The current branch is not in the sidebar")
        head.click()
    }

    @MainActor
    private func historyApplication() -> XCUIApplication {
        XCUIApplication.configuredForRealRepositoryState(
            path: FileManager.default.temporaryDirectory.path(percentEncoded: false)
        )
    }

    /// The tests read what a Copy action wrote, so whatever the machine already held is put back.
    @MainActor
    private func preserveSystemPasteboard() {
        let pasteboard = NSPasteboard.general
        let previousItems: [NSPasteboardWriting] = pasteboard.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy as NSPasteboardWriting
        } ?? []
        addTeardownBlock {
            pasteboard.clearContents()
            pasteboard.writeObjects(previousItems)
        }
    }
}
