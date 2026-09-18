////
//  StashOptionsUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// What each of the Stash sheet's options takes, driven through the checkboxes themselves.
///
/// Kept apart from StashUITests, which saves with the options left alone: a checkbox bound to the
/// wrong option would pass every one of those, and only a Stash saved with the box checked shows
/// which work the command was actually asked to take.
final class StashOptionsUITests: XCTestCase {
    private let repositoryPath = "/tmp/Colofa Stash Options UI"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Keep Staged Changes saves the work beside the index and leaves the index itself alone.
    @MainActor
    func testEnglishKeepStagedChangesLeavesTheIndexAndTakesTheRest() {
        let any = savedStash(checking: ["repository.stash.keepStaged"])
            .descendants(matching: .any)

        XCTAssertTrue(
            waitUntil(NSPredicate(format: "exists == false"), on: any["repository.unstaged.diff.txt"]),
            "The tracked change the Stash took is still listed"
        )
        XCTAssertTrue(
            any["repository.staged.staged.swift"].exists,
            "Keep Staged Changes let the Stash take the index"
        )
        XCTAssertTrue(
            any["repository.unstaged.notes.txt"].exists,
            "The untracked file nobody asked to save was taken anyway"
        )
    }

    /// Include Untracked Files takes the untracked file along with everything the default takes.
    @MainActor
    func testEnglishIncludeUntrackedFilesTakesTheUntrackedFileToo() {
        let any = savedStash(checking: ["repository.stash.includeUntracked"])
            .descendants(matching: .any)

        XCTAssertTrue(
            waitUntil(NSPredicate(format: "exists == false"), on: any["repository.staged.staged.swift"]),
            "The Staged Change the Stash took is still listed"
        )
        XCTAssertFalse(
            any["repository.unstaged.diff.txt"].exists,
            "The tracked change the Stash took is still listed"
        )
        XCTAssertFalse(
            any["repository.unstaged.notes.txt"].exists,
            "Include Untracked Files left the untracked file behind"
        )
    }

    /// Both options together keep the index and still take the untracked file, because each
    /// answers a different question.
    @MainActor
    func testEnglishBothOptionsKeepTheIndexAndTakeTheUntrackedFile() {
        let any = savedStash(
            checking: ["repository.stash.keepStaged", "repository.stash.includeUntracked"]
        )
        .descendants(matching: .any)

        XCTAssertTrue(
            waitUntil(NSPredicate(format: "exists == false"), on: any["repository.unstaged.notes.txt"]),
            "Include Untracked Files left the untracked file behind"
        )
        XCTAssertFalse(
            any["repository.unstaged.diff.txt"].exists,
            "The tracked change the Stash took is still listed"
        )
        XCTAssertTrue(
            any["repository.staged.staged.swift"].exists,
            "Keep Staged Changes let the Stash take the index"
        )
    }

    /// Saves a Stash from the fixture with the named options turned on, and returns the app once
    /// the sheet has closed.
    ///
    /// Each option is checked to be on before Stash is pressed, so a click that missed its
    /// checkbox fails here rather than as a Stash that took the wrong work.
    @MainActor
    private func savedStash(checking options: [String]) -> XCUIApplication {
        let application = XCUIApplication.configuredForStashState(path: repositoryPath)
        application.launch()
        application.activate()

        let any = application.descendants(matching: .any)
        let stash = any["repository.toolbar.stash"]
        assertEventuallyExists(stash, "The toolbar has no Stash")
        clickWhenReady(stash)
        assertEventuallyExists(any["repository.stash.confirm"], "The Stash sheet did not open")
        // The pointer is still resting where the toolbar's Stash was, and that button's tooltip
        // opens over the top of the sheet and takes the first checkbox's click. Moving it onto
        // the sheet's own Stash, well below where the tooltip is drawn, puts it away.
        any["repository.stash.confirm"].hover()

        for option in options {
            clickWhenReady(any[option])
            XCTAssertTrue(
                waitUntil(NSPredicate(format: "value == 1"), on: any[option]),
                "\(option) did not turn on"
            )
        }
        clickWhenReady(any["repository.stash.confirm"])
        XCTAssertTrue(
            waitUntil(NSPredicate(format: "exists == false"), on: any["repository.stash.confirm"]),
            "The Stash sheet is still on screen"
        )
        return application
    }
}
