////
//  StashTimingUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// What the Stash sheet does while a Stash it started is still running.
final class StashTimingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// A Stash of a large working tree, or on a slow disk, keeps the sheet on screen for as long
    /// as it takes. Git already holds the message and the options it was handed, and the draft is
    /// dropped once the Stash lands, so an edit made in the meantime would never reach the command
    /// — and an option flipped now would show something other than what is being saved. All
    /// three close until the Stash is done rather than accepting edits and discarding them.
    @MainActor
    func testEnglishSheetRefusesEditsWhileTheStashIsStillRunning() {
        let application = XCUIApplication.configuredForStashState(
            path: "/tmp/Colofa Stash Timing UI",
            additionalArguments: [UITestingArgument.slowStash]
        )
        application.launch()
        application.activate()

        let any = application.descendants(matching: .any)
        let stash = any["repository.toolbar.stash"]
        assertEventuallyExists(stash, "The toolbar has no Stash")
        clickWhenReady(stash)
        let confirm = any["repository.stash.confirm"]
        assertEventuallyExists(confirm, "The Stash sheet did not open")
        // The toolbar's tooltip opens over the top of the sheet; moving the pointer puts it away.
        confirm.hover()

        let message = any["repository.stash.message"]
        let keepStaged = any["repository.stash.keepStaged"]
        let includeUntracked = any["repository.stash.includeUntracked"]
        replaceText(of: message, with: "parser rewrite")
        XCTAssertTrue(message.isEnabled)
        XCTAssertTrue(keepStaged.isEnabled)
        XCTAssertTrue(includeUntracked.isEnabled)

        clickWhenReady(confirm)

        let closed = NSPredicate(format: "isEnabled == false")
        XCTAssertTrue(waitUntil(closed, on: message), "The message stayed editable mid-Stash")
        XCTAssertTrue(
            waitUntil(closed, on: keepStaged),
            "Keep Staged Changes stayed editable mid-Stash"
        )
        XCTAssertTrue(
            waitUntil(closed, on: includeUntracked),
            "Include Untracked Files stayed editable mid-Stash"
        )
        // What is being saved is still on screen: the form is closed, not cleared.
        XCTAssertEqual(message.value as? String, "parser rewrite")

        // Nothing stops a Stash, so the fixture's is still out when this ends.
        application.terminate()
    }
}
