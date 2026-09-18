////
//  StashInspectionUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// Reading a Stash back: what the section lists, what selecting one shows, and the fact that
/// none of it can change the Repository.
final class StashInspectionUITests: XCTestCase {
    private let repositoryPath = "/tmp/Colofa Stash Inspection UI"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Inspecting one

    /// The list carries what Git knows about each entry, and selecting one reads the paths it
    /// saved and the patch for the first of them.
    @MainActor
    func testEnglishSelectingAstashShowsItsMetadataFilesAndDiff() {
        let application = stashApplication(
            additionalArguments: [UITestingArgument.stashEntries]
        )
        application.launch()
        application.activate()

        clickWhenReady(application.descendants(matching: .any)["baseline.section.stashes"])
        let row = application.descendants(matching: .any)["repository.stash.stash@{0}"]
        assertEventuallyExists(row, "The Stashes section is empty")
        clickWhenReady(row)

        let any = application.descendants(matching: .any)
        assertEventuallyExists(any["repository.stash.selector"], "The entry has no address")
        XCTAssertEqual(any["repository.stash.selector"].value as? String, "stash@{0}")
        XCTAssertEqual(any["repository.stash.author"].value as? String, "Fixture Author <fixture@example.invalid>")
        XCTAssertEqual(any["repository.stash.untracked"].value as? String, "Yes")

        assertEventuallyExists(
            any["repository.stash.file.diff.txt"],
            "The Stash's saved paths are not listed"
        )
        assertEventuallyExists(
            any["repository.stash.file.notes.txt"],
            "The untracked file the Stash saved is not listed"
        )
        assertEventuallyExists(any["repository.diff.content"], "The Stash's Diff was not read")
    }

    /// A Stash Diff is inspection only: nothing beside it stages anything.
    @MainActor
    func testEnglishAstashDiffOffersNoStageAction() {
        let application = stashApplication(
            additionalArguments: [UITestingArgument.stashEntries]
        )
        application.launch()
        application.activate()

        clickWhenReady(application.descendants(matching: .any)["baseline.section.stashes"])
        clickWhenReady(application.descendants(matching: .any)["repository.stash.stash@{0}"])

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.diff.content"],
            "The Stash's Diff was not read"
        )
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.detail.action"].exists,
            "A Stash Diff offered a Stage action"
        )
    }

    /// Nothing is selected until the user chooses, and the pane says so rather than sitting blank.
    @MainActor
    func testEnglishNoStashSelectedIsSaidRatherThanShownBlank() {
        let application = stashApplication(
            additionalArguments: [UITestingArgument.stashEntries]
        )
        application.launch()
        application.activate()

        clickWhenReady(application.descendants(matching: .any)["baseline.section.stashes"])

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.stashes.noStashSelected"],
            "The detail pane said nothing about having no selection"
        )
    }

    /// An empty Stashes section offers the action that would fill it.
    @MainActor
    func testEnglishTheEmptySectionOffersStash() {
        let application = stashApplication()
        application.launch()
        application.activate()

        clickWhenReady(application.descendants(matching: .any)["baseline.section.stashes"])
        assertEventuallyExists(
            application.descendants(matching: .any)["baseline.empty.stashes"],
            "The Stashes section is not empty"
        )
        let create = application.descendants(matching: .any)["repository.stashes.create"]
        assertEventuallyExists(create, "The empty Stashes section offers no way to save one")
        clickWhenReady(create)

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.stash.confirm"],
            "The empty section's Stash did not open the sheet"
        )
    }

    @MainActor
    private func stashApplication(additionalArguments: [String] = []) -> XCUIApplication {
        .configuredForStashState(
            path: repositoryPath,
            additionalArguments: additionalArguments
        )
    }
}
