////
//  FileActionsUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

final class FileActionsUITests: XCTestCase {
    /// An item every one of these menus carries, whichever path opened it. It is how the open
    /// menu is found, and how a right-click knows whether a menu opened at all.
    private static let menuAnchor = "repository.change.copyPath"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The whole point of this issue in one pass: which destructive action a path is offered,
    /// that neither runs without confirmation, and that Cancel changes nothing.
    @MainActor
    func testEnglishEachKindOfPathOffersOnlyItsOwnDestructiveAction() {
        let application = fileActionsApplication()
        prepare(application)

        let deleted = row(application, "repository.unstaged.deleted.swift")
        XCTAssertTrue(deleted.waitForExistence(timeout: 5))
        let addedStagedRow = row(application, "repository.staged.added.swift")
        XCTAssertTrue(addedStagedRow.exists)

        // A tracked, unstaged path: Discard Changes, never Move to Trash.
        openContextMenu(application, on: deleted)
        XCTAssertTrue(discardItem(application).exists)
        XCTAssertEqual(discardItem(application).title, "Discard Changes")
        XCTAssertFalse(trashItem(application).exists)
        XCTAssertTrue(menuItem(application, "repository.change.revealInFinder").exists)
        clickWhenReady(discardItem(application))

        // Cancelling leaves the row, and the Staged Changes, exactly where they were.
        let dialog = application.sheets.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 2))
        XCTAssertTrue(
            application.staticTexts["Discard changes to “deleted.swift”?"].exists
        )
        clickWhenReady(dialog.buttons["Cancel"])
        XCTAssertTrue(dialog.waitForNonExistence(timeout: 2))
        assertEventuallyExists(deleted)
        XCTAssertTrue(addedStagedRow.exists)

        // Confirming restores only the unstaged content, so the Staged Changes survive it.
        openContextMenu(application, on: deleted)
        clickWhenReady(discardItem(application))
        XCTAssertTrue(dialog.waitForExistence(timeout: 2))
        clickWhenReady(dialog.buttons["Discard Changes"])
        XCTAssertTrue(deleted.waitForNonExistence(timeout: 5))
        assertEventuallyExists(addedStagedRow)

        // An untracked path: Move to Trash, never Discard Changes and never Delete.
        let notes = row(application, "repository.unstaged.notes.txt")
        assertEventuallyExists(notes)
        openContextMenu(application, on: notes)
        XCTAssertTrue(trashItem(application).exists)
        XCTAssertEqual(trashItem(application).title, "Move to Trash")
        XCTAssertFalse(discardItem(application).exists)
        // Scoped to this menu on purpose: Delete is an ordinary Edit-menu item, so asking the
        // application for one would find the menu bar's rather than this menu's.
        XCTAssertFalse(openMenuTitles(application).contains("Delete"))
        clickWhenReady(trashItem(application))
        XCTAssertTrue(dialog.waitForExistence(timeout: 2))
        XCTAssertTrue(application.staticTexts["Move “notes.txt” to the Trash?"].exists)
        clickWhenReady(dialog.buttons["Cancel"])
        XCTAssertTrue(dialog.waitForNonExistence(timeout: 2))
        assertEventuallyExists(notes)

        openContextMenu(application, on: notes)
        clickWhenReady(trashItem(application))
        XCTAssertTrue(dialog.waitForExistence(timeout: 2))
        clickWhenReady(dialog.buttons["Move to Trash"])
        XCTAssertTrue(notes.waitForNonExistence(timeout: 5))
    }

    /// A Conflict and a Staged Change offer neither destructive action, and still offer the two
    /// that only locate the file.
    @MainActor
    func testEnglishConflictedAndStagedPathsOfferNoDestructiveAction() {
        let application = fileActionsApplication()
        prepare(application)

        let conflict = row(application, "repository.unstaged.conflict.txt")
        XCTAssertTrue(conflict.waitForExistence(timeout: 5))
        openContextMenu(application, on: conflict)
        XCTAssertTrue(menuItem(application, "repository.change.revealInFinder").exists)
        XCTAssertFalse(discardItem(application).exists)
        XCTAssertFalse(trashItem(application).exists)
        dismissOpenMenu(application)

        let staged = row(application, "repository.staged.added.swift")
        assertEventuallyExists(staged)
        openContextMenu(application, on: staged)
        XCTAssertTrue(openMenuTitles(application).contains("Unstage File"))
        XCTAssertFalse(discardItem(application).exists)
        XCTAssertFalse(trashItem(application).exists)
        XCTAssertTrue(menuItem(application, Self.menuAnchor).exists)
        dismissOpenMenu(application)
    }

    /// The same actions reachable without a right-click, and Copy Path working on the selection.
    @MainActor
    func testEnglishTheDiffPaneMenuOffersTheSameActions() {
        let application = fileActionsApplication()
        prepare(application)

        let notes = row(application, "repository.unstaged.notes.txt")
        XCTAssertTrue(notes.waitForExistence(timeout: 5))
        notes.click()

        // The Diff arriving rebuilds this pane, and with it the menu's contents. Waiting for it
        // first is what keeps the menu still under the click below: once a menu is open there is
        // nothing left to wait on, because a menu item being rebuilt still reports that it exists.
        assertEventuallyExists(row(application, "repository.diff.content"))

        let menu = row(application, "repository.detail.fileActions")
        assertEventuallyExists(menu)
        clickWhenReady(menu)
        XCTAssertTrue(menuItem(application, Self.menuAnchor).waitForExistence(timeout: 2))
        XCTAssertTrue(trashItem(application).exists)
        XCTAssertTrue(menuItem(application, "repository.change.revealInFinder").exists)
        clickWhenReady(menuItem(application, Self.menuAnchor))

        // Copying is not a mutation: nothing is confirmed, and nothing fails.
        assertEventuallyExists(notes)
        XCTAssertFalse(application.sheets.firstMatch.exists)
    }

    /// A Move to Trash the file system refused says so, and the path is still listed afterwards.
    @MainActor
    func testEnglishARefusedMoveToTrashExplainsItselfAndKeepsThePath() {
        let application = fileActionsApplication(
            additionalArguments: [UITestingArgument.trashFailure]
        )
        prepare(application)

        let notes = row(application, "repository.unstaged.notes.txt")
        XCTAssertTrue(notes.waitForExistence(timeout: 5))
        openContextMenu(application, on: notes)
        clickWhenReady(trashItem(application))

        let dialog = application.sheets.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 2))
        clickWhenReady(dialog.buttons["Move to Trash"])

        XCTAssertTrue(
            application.staticTexts["File Could Not Be Moved to the Trash"]
                .waitForExistence(timeout: 5)
        )
        let alert = application.sheets.firstMatch
        // No Git command ran, so there is no Git output offered behind it.
        XCTAssertFalse(alert.buttons["View Details"].exists)
        clickWhenReady(alert.buttons["OK"])

        XCTAssertTrue(alert.waitForNonExistence(timeout: 2))
        assertEventuallyExists(notes)
    }

    /// A Discard the Git command refused says so, keeps the path, and — unlike the Trash failure
    /// above — has Git output to offer, because a Git command is what refused it.
    ///
    /// The fixture's mutation failure is named for staging only because staging is where it was
    /// first needed; it refuses every mutating command the stub is asked to run, which is what a
    /// Discard has to be tested against here.
    @MainActor
    func testEnglishARefusedDiscardExplainsItselfAndKeepsThePath() {
        let application = fileActionsApplication(
            additionalArguments: [UITestingArgument.stageFailure]
        )
        prepare(application)

        let deleted = row(application, "repository.unstaged.deleted.swift")
        XCTAssertTrue(deleted.waitForExistence(timeout: 5))
        openContextMenu(application, on: deleted)
        clickWhenReady(discardItem(application))

        let dialog = application.sheets.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 2))
        clickWhenReady(dialog.buttons["Discard Changes"])

        XCTAssertTrue(
            application.staticTexts["Changes Could Not Be Discarded"]
                .waitForExistence(timeout: 5)
        )
        let alert = application.sheets.firstMatch
        XCTAssertTrue(alert.buttons["View Details"].exists)
        clickWhenReady(alert.buttons["OK"])

        XCTAssertTrue(alert.waitForNonExistence(timeout: 2))
        // Nothing was discarded, so the row the confirmation named is still listed.
        assertEventuallyExists(deleted)
    }

    /// Reveal in Finder on a path that is no longer on disk explains itself instead of opening
    /// Finder on nothing, and says the Repository was read again.
    @MainActor
    func testEnglishMissingPathCannotBeRevealed() {
        let application = fileActionsApplication(
            additionalArguments: [UITestingArgument.missingFile]
        )
        prepare(application)

        let notes = row(application, "repository.unstaged.notes.txt")
        XCTAssertTrue(notes.waitForExistence(timeout: 5))
        openContextMenu(application, on: notes)
        clickWhenReady(menuItem(application, "repository.change.revealInFinder"))

        XCTAssertTrue(
            application.staticTexts["File Could Not Be Revealed"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            application.staticTexts[
                "“notes.txt” is no longer on disk. Colofa reloaded the Repository."
            ].exists
        )
        let alert = application.sheets.firstMatch
        // Finder was asked rather than Git, so there is no Git output behind it.
        XCTAssertFalse(alert.buttons["View Details"].exists)
        clickWhenReady(alert.buttons["OK"])
        XCTAssertTrue(alert.waitForNonExistence(timeout: 2))
    }

    @MainActor
    private func row(_ application: XCUIApplication, _ identifier: String) -> XCUIElement {
        application.descendants(matching: .any)[identifier]
    }

    /// Right-clicks `element` and waits for its menu, asking again when none opened.
    ///
    /// The rows are replaced whenever the Repository is re-read after a mutation, and a
    /// right-click that lands during one of those rebuilds opens nothing at all. The row itself
    /// reports no state that distinguishes the moment, so asking again is what makes the menu
    /// deterministic.
    @MainActor
    private func openContextMenu(
        _ application: XCUIApplication,
        on element: XCUIElement,
        line: UInt = #line
    ) {
        for _ in 1...3 {
            rightClickWhenReady(element, line: line)
            if menuItem(application, Self.menuAnchor).waitForExistence(timeout: 2) {
                return
            }
        }
        XCTFail("Right-clicking opened no menu", file: #filePath, line: line)
    }

    /// Closes the open menu and waits for it to go, so the next right-click is not racing a menu
    /// that is still dismissing.
    @MainActor
    private func dismissOpenMenu(_ application: XCUIApplication, line: UInt = #line) {
        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(
            menuItem(application, Self.menuAnchor).waitForNonExistence(timeout: 2),
            "The menu was still open",
            file: #filePath,
            line: line
        )
    }

    /// The menu currently open, found through the one item every one of these menus carries.
    ///
    /// Every menu query below is scoped to it rather than run against the application. An
    /// application-wide query reaches the Apple, app, and Edit menus too, where Delete, Copy, and
    /// Cut all already exist, so only a scoped query makes a negative assertion mean what it says.
    @MainActor
    private func openMenu(_ application: XCUIApplication) -> XCUIElement {
        application.menus
            .containing(.menuItem, identifier: Self.menuAnchor)
            .firstMatch
    }

    @MainActor
    private func menuItem(
        _ application: XCUIApplication,
        _ identifier: String
    ) -> XCUIElement {
        openMenu(application).menuItems[identifier]
    }

    @MainActor
    private func discardItem(_ application: XCUIApplication) -> XCUIElement {
        menuItem(application, "repository.change.discardChanges")
    }

    @MainActor
    private func trashItem(_ application: XCUIApplication) -> XCUIElement {
        menuItem(application, "repository.change.moveToTrash")
    }

    /// The titles of the menu currently open.
    @MainActor
    private func openMenuTitles(_ application: XCUIApplication) -> [String] {
        openMenu(application).menuItems.allElementsBoundByIndex.map(\.title)
    }

    @MainActor
    private func prepare(_ application: XCUIApplication) {
        application.launch()
        application.activate()
        zoomWindow(application)
    }

    /// Zooms the window, addressing Zoom inside the Window menu rather than through the
    /// application, for the reason `openMenu(_:)` gives.
    @MainActor
    private func zoomWindow(_ application: XCUIApplication) {
        let windowMenu = application.menuBars.menuBarItems["Window"]
        XCTAssertTrue(windowMenu.waitForExistence(timeout: 10))
        windowMenu.click()
        let zoom = windowMenu.menuItems["Zoom"]
        XCTAssertTrue(zoom.waitForExistence(timeout: 2))
        clickWhenReady(zoom)
    }

    @MainActor
    private func fileActionsApplication(
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        XCUIApplication.configuredForRealRepositoryState(
            path: "/tmp/Colofa File Actions UI",
            additionalArguments: additionalArguments
        )
    }
}
