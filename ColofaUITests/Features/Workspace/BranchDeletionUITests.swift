////
//  BranchDeletionUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// Delete Branch, driven the way a user reaches it: from the Ref's own context menu in the
/// sidebar.
final class BranchDeletionUITests: XCTestCase {
    private static let branch = "feature/真实"
    private static let branchIdentifier = "repository.ref.local.feature/真实"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// A Branch every other Ref already holds says so, offers no force, and deletes.
    @MainActor
    func testEnglishAmergedBranchDeletesAfterOneConfirmation() {
        let application = branchApplication()
        application.launch()
        application.activate()

        openDeleteDialog(in: application)
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.deleteBranch.force"].exists,
            "A merged branch was offered Force Delete"
        )
        let confirm = application.descendants(matching: .any)["repository.deleteBranch.confirm"]
        XCTAssertTrue(confirm.isEnabled)
        confirm.click()

        XCTAssertTrue(
            waitUntil(
                NSPredicate(format: "exists == false"),
                on: application.descendants(matching: .any)[Self.branchIdentifier]
            ),
            "The branch is still in the sidebar"
        )
        // A local Delete reaches nothing outside refs/heads/.
        XCTAssertTrue(
            application.descendants(matching: .any)["repository.ref.remote.origin/feature"].exists,
            "The Remote-tracking Branch was removed with the local one"
        )
    }

    /// An unmerged Branch says exactly how many Commits only it holds, and deletes nothing until
    /// Force Delete has been ticked.
    @MainActor
    func testEnglishAnUnmergedBranchCountsItsCommitsAndRequiresForce() {
        let application = branchApplication(
            additionalArguments: [UITestingArgument.unmergedBranch]
        )
        application.launch()
        application.activate()

        openDeleteDialog(in: application)

        // Read from the note's own text, whose string macOS carries as the element's value.
        XCTAssertTrue(
            application.sheets.staticTexts.matching(
                NSPredicate(format: "value CONTAINS %@", "3")
            ).firstMatch.exists,
            "The confirmation did not say how many Commits only this branch holds"
        )
        let confirm = application.descendants(matching: .any)["repository.deleteBranch.confirm"]
        XCTAssertFalse(confirm.isEnabled, "Delete ran without the explicit force")

        let force = application.descendants(matching: .any)["repository.deleteBranch.force"]
        XCTAssertEqual("\(force.value ?? "")", "0", "Force Delete was not off by default")
        force.click()

        XCTAssertTrue(
            waitUntil(NSPredicate(format: "isEnabled == true"), on: confirm),
            "Delete stayed unavailable after Force Delete was ticked"
        )
        confirm.click()

        XCTAssertTrue(
            waitUntil(
                NSPredicate(format: "exists == false"),
                on: application.descendants(matching: .any)[Self.branchIdentifier]
            ),
            "The forced Delete left the branch in the sidebar"
        )
    }

    /// Cancelling leaves the Branch exactly where it was.
    @MainActor
    func testEnglishCancellingTheConfirmationLeavesTheBranchUntouched() {
        let application = branchApplication(
            additionalArguments: [UITestingArgument.unmergedBranch]
        )
        application.launch()
        application.activate()

        openDeleteDialog(in: application)
        application.descendants(matching: .any)["repository.deleteBranch.cancel"].click()

        XCTAssertTrue(
            waitUntil(
                NSPredicate(format: "exists == false"),
                on: application.descendants(matching: .any)["repository.deleteBranch.confirm"]
            ),
            "The confirmation is still on screen"
        )
        XCTAssertTrue(
            application.descendants(matching: .any)[Self.branchIdentifier].exists,
            "Cancelling removed the branch"
        )
    }

    /// The current Branch keeps the action and refuses it, rather than hiding it.
    @MainActor
    func testEnglishTheCurrentBranchOffersDeleteBranchDisabled() {
        let application = branchApplication()
        application.launch()
        application.activate()

        let head = application.descendants(matching: .any)["repository.head"]
        assertEventuallyExists(head, "The current Branch is not in the sidebar")
        head.rightClick()

        let delete = application.descendants(matching: .menuItem)["repository.ref.deleteBranch"]
        XCTAssertTrue(
            delete.waitForExistence(timeout: 5),
            "Delete Branch is not in the current Branch's menu"
        )
        XCTAssertFalse(delete.isEnabled, "The current Branch offered a Delete that could run")
        application.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    private func branchApplication(
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        XCUIApplication.configuredForBranchState(
            path: FileManager.default.temporaryDirectory.path(percentEncoded: false),
            additionalArguments: additionalArguments
        )
    }

    /// Reached by its identifier rather than its title, because the Branch menu offers Delete
    /// Branch under the same title and a title query matches both.
    @MainActor
    private func openDeleteDialog(in application: XCUIApplication) {
        let branch = application.descendants(matching: .any)[Self.branchIdentifier]
        assertEventuallyExists(branch, "\(Self.branch) is not in the sidebar")
        branch.rightClick()

        let delete = application.descendants(matching: .menuItem)["repository.ref.deleteBranch"]
        XCTAssertTrue(
            delete.waitForExistence(timeout: 5),
            "Delete Branch is not in the Ref's menu"
        )
        delete.click()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.deleteBranch.confirm"],
            "The Delete Branch confirmation did not open"
        )
    }
}
