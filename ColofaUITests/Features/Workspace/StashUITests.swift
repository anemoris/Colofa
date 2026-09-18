////
//  StashUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// Saving a Stash, driven the way a user reaches it: from the toolbar's own Stash.
final class StashUITests: XCTestCase {
    private let repositoryPath = "/tmp/Colofa Stash UI"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - The sheet

    /// The sheet opens on a message nobody has to write and both exceptions turned off.
    @MainActor
    func testEnglishTheSheetOpensWithBothOptionsUnchecked() {
        let application = stashApplication()
        application.launch()
        application.activate()

        openStashSheet(in: application)

        let any = application.descendants(matching: .any)
        XCTAssertEqual(any["repository.stash.message"].value as? String, "")
        XCTAssertEqual(
            any["repository.stash.keepStaged"].value as? Int,
            0,
            "Keep Staged Changes started checked"
        )
        XCTAssertEqual(
            any["repository.stash.includeUntracked"].value as? Int,
            0,
            "Include Untracked Files started checked"
        )
        XCTAssertTrue(
            application.sheets.checkBoxes["Keep Staged Changes"].exists,
            "Keep Staged Changes is not offered"
        )
        XCTAssertTrue(
            application.sheets.checkBoxes["Include Untracked Files"].exists,
            "Include Untracked Files is not offered"
        )
    }

    /// Ignored files are never included, and the sheet says so rather than leaving it to be
    /// discovered afterwards.
    @MainActor
    func testEnglishTheSheetSaysIgnoredFilesAreNeverIncluded() {
        let application = stashApplication()
        application.launch()
        application.activate()

        openStashSheet(in: application)

        let note = application.descendants(matching: .any)["repository.stash.ignoredNote"]
        assertEventuallyExists(note, "The sheet does not mention ignored files")
        XCTAssertTrue(
            (note.value as? String)?.contains("Ignored files are never included") == true,
            "The note does not say ignored files stay out"
        )
    }

    /// Saving with the default options closes the sheet and leaves a working tree the Repository
    /// was read back for, rather than one the app assumed.
    @MainActor
    func testEnglishSavingAstashClosesTheSheetAndEmptiesTheChanges() {
        let application = stashApplication()
        application.launch()
        application.activate()

        openStashSheet(in: application)
        replaceText(
            of: application.descendants(matching: .any)["repository.stash.message"],
            with: "parser rewrite"
        )
        clickWhenReady(application.descendants(matching: .any)["repository.stash.confirm"])

        XCTAssertTrue(
            waitUntil(
                NSPredicate(format: "exists == false"),
                on: application.descendants(matching: .any)["repository.stash.confirm"]
            ),
            "The Stash sheet is still on screen"
        )
        // The default options take the tracked work and leave the untracked file where it was,
        // and the list is what the Repository reported afterwards rather than what the app
        // assumed.
        let any = application.descendants(matching: .any)
        XCTAssertTrue(
            waitUntil(
                NSPredicate(format: "exists == false"),
                on: any["repository.staged.staged.swift"]
            ),
            "The Staged Change the Stash took is still listed"
        )
        XCTAssertFalse(
            any["repository.unstaged.diff.txt"].exists,
            "The tracked change the Stash took is still listed"
        )
        assertEventuallyExists(
            any["repository.unstaged.notes.txt"],
            "The untracked file nobody asked to save was taken anyway"
        )
    }

    /// The entry the Stashes section then lists is the one Git described, at the address Git
    /// holds it at.
    @MainActor
    func testEnglishAsavedStashIsListedWithGitsOwnIdentity() {
        let application = stashApplication()
        application.launch()
        application.activate()

        openStashSheet(in: application)
        replaceText(
            of: application.descendants(matching: .any)["repository.stash.message"],
            with: "parser rewrite"
        )
        clickWhenReady(application.descendants(matching: .any)["repository.stash.confirm"])

        clickWhenReady(application.descendants(matching: .any)["baseline.section.stashes"])
        let row = application.descendants(matching: .any)["repository.stash.stash@{0}"]
        assertEventuallyExists(row, "The saved Stash is not listed")
        XCTAssertTrue(
            (row.value as? String)?.contains("On main: parser rewrite") == true
                || row.label.contains("On main: parser rewrite"),
            "The row does not carry Git's own description"
        )
    }

    /// Cancelling saves nothing, so the work is still there afterwards.
    @MainActor
    func testEnglishCancellingLeavesTheWorkingTreeAlone() {
        let application = stashApplication()
        application.launch()
        application.activate()

        openStashSheet(in: application)
        clickWhenReady(application.descendants(matching: .any)["repository.stash.cancel"])

        XCTAssertTrue(
            waitUntil(
                NSPredicate(format: "exists == false"),
                on: application.descendants(matching: .any)["repository.stash.confirm"]
            ),
            "The Stash sheet is still on screen"
        )
        clickWhenReady(application.descendants(matching: .any)["baseline.section.stashes"])
        assertEventuallyExists(
            application.descendants(matching: .any)["baseline.empty.stashes"],
            "Cancelling saved a Stash anyway"
        )
    }

    // MARK: - States that cannot save one

    /// A clean Repository has nothing to save, and the toolbar says why rather than sitting
    /// disabled in silence.
    @MainActor
    func testEnglishAcleanRepositoryDisablesStashAndExplainsWhy() {
        let application = stashApplication(
            additionalArguments: [UITestingArgument.stashCleanState]
        )
        application.launch()
        application.activate()

        let stash = application.descendants(matching: .any)["repository.toolbar.stash"]
        assertEventuallyExists(stash, "The toolbar has no Stash")
        XCTAssertFalse(stash.isEnabled, "A clean Repository offered a Stash that could run")
        assertShowsTooltip(
            over: stash,
            parkedOn: application.descendants(matching: .any)["repository.path"],
            "The disabled Stash gave no reason"
        )
    }

    /// Untracked work alone is still work, so the sheet opens — and says which option would save
    /// it rather than refusing without a way forward.
    @MainActor
    func testEnglishUntrackedWorkAloneNamesTheOptionThatWouldSaveIt() {
        let application = stashApplication(
            additionalArguments: [UITestingArgument.stashUntrackedOnly]
        )
        application.launch()
        application.activate()

        openStashSheet(in: application)

        let confirm = application.descendants(matching: .any)["repository.stash.confirm"]
        XCTAssertFalse(confirm.isEnabled, "A Stash that would save nothing was offered")
        let refusal = application.descendants(matching: .any)["repository.stash.refusal"]
        assertEventuallyExists(refusal, "The sheet gave no reason")
        XCTAssertTrue(
            (refusal.value as? String)?.contains("Include Untracked Files") == true,
            "The refusal does not name the option that would save the work"
        )

        clickWhenReady(application.descendants(matching: .any)["repository.stash.includeUntracked"])
        XCTAssertTrue(
            waitUntil(NSPredicate(format: "isEnabled == true"), on: confirm),
            "Turning the option on did not make the Stash available"
        )
    }

    /// The message and the options are what the user would change, so a refusal stays beside them
    /// rather than replacing them with an alert.
    @MainActor
    func testEnglishArefusalKeepsTheSheetWithGitsOwnWords() {
        let application = stashApplication(
            additionalArguments: [UITestingArgument.stashFailure]
        )
        application.launch()
        application.activate()

        openStashSheet(in: application)
        replaceText(
            of: application.descendants(matching: .any)["repository.stash.message"],
            with: "parser rewrite"
        )
        clickWhenReady(application.descendants(matching: .any)["repository.stash.confirm"])

        let failure = application.descendants(matching: .any)["repository.stash.failure"]
        assertEventuallyExists(failure, "Git's refusal was not shown inside the sheet")
        XCTAssertEqual(
            application.descendants(matching: .any)["repository.stash.message"].value as? String,
            "parser rewrite",
            "The refusal took the typed message away"
        )
    }

    // MARK: - Reaching it

    @MainActor
    private func stashApplication(additionalArguments: [String] = []) -> XCUIApplication {
        .configuredForStashState(
            path: repositoryPath,
            additionalArguments: additionalArguments
        )
    }

    @MainActor
    private func openStashSheet(in application: XCUIApplication) {
        let stash = application.descendants(matching: .any)["repository.toolbar.stash"]
        assertEventuallyExists(stash, "The toolbar has no Stash")
        clickWhenReady(stash)
        assertEventuallyExists(
            application.descendants(matching: .any)["repository.stash.confirm"],
            "The Stash sheet did not open"
        )
    }
}
