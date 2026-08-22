////
//  BranchUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// The New Branch dialog and explicit Checkout, driven the way a user reaches them.
final class BranchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The toolbar's New Branch starts at HEAD, offers Checkout New Branch already enabled, and
    /// moves HEAD to the branch it creates.
    @MainActor
    func testEnglishNewBranchFromTheToolbarStartsAtHeadAndChecksOutByDefault() {
        let application = branchApplication()
        application.launch()
        application.activate()

        openNewBranchDialog(in: application)
        XCTAssertEqual(
            application.descendants(matching: .any)["repository.newBranch.startPoint"]
                .value as? String,
            "main"
        )
        let checkout = application.descendants(matching: .any)["repository.newBranch.checkout"]
        XCTAssertEqual("\(checkout.value ?? "")", "1")

        create(named: "feature/from-toolbar", in: application)

        XCTAssertTrue(
            waitUntil(
                NSPredicate(format: "value == %@", "feature/from-toolbar"),
                on: application.descendants(matching: .any)["repository.head"]
            ),
            "HEAD did not move to the created branch"
        )
    }

    /// Creating without Checkout writes the ref and leaves HEAD exactly where it was.
    @MainActor
    func testEnglishCreatingWithoutCheckoutLeavesHeadWhereItWas() {
        let application = branchApplication()
        application.launch()
        application.activate()

        openNewBranchDialog(in: application)
        application.descendants(matching: .any)["repository.newBranch.checkout"].click()
        create(named: "ref-only", in: application)

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.ref.local.ref-only"],
            "The created branch is not in the sidebar"
        )
        XCTAssertEqual(
            application.descendants(matching: .any)["repository.head"].value as? String,
            "main"
        )
    }

    /// A name Git will not accept is refused before anything runs, and says why.
    @MainActor
    func testEnglishAnUnacceptableBranchNameIsRefusedWithGuidance() {
        let application = branchApplication()
        application.launch()
        application.activate()

        openNewBranchDialog(in: application)
        replaceText(
            of: application.descendants(matching: .any)["repository.newBranch.name"],
            with: "bad name"
        )

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.newBranch.validation"],
            "The name was not refused"
        )
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.newBranch.create"].isEnabled
        )

        // The same dialog accepts the name once it is one Git accepts.
        replaceText(
            of: application.descendants(matching: .any)["repository.newBranch.name"],
            with: "good-name"
        )
        XCTAssertTrue(
            waitUntil(
                NSPredicate(format: "isEnabled == true"),
                on: application.descendants(matching: .any)["repository.newBranch.create"]
            ),
            "An acceptable name was not accepted"
        )
    }

    /// Create Branch Here opens the same dialog on the Commit the user selected in History.
    @MainActor
    func testEnglishCreateBranchHereStartsAtTheSelectedCommit() {
        let application = branchApplication()
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.head"].click()
        let row = application.descendants(matching: .any)[
            UITestingCommitID.rowIdentifier(index: 2)
        ]
        assertEventuallyExists(row, "The History list is not on screen")
        row.click()

        let createBranch = application.descendants(matching: .any)[
            "repository.commit.createBranch"
        ]
        assertEventuallyExists(createBranch, "Create Branch Here is not on screen")
        createBranch.click()

        let startPoint = application.descendants(matching: .any)[
            "repository.newBranch.startPoint"
        ]
        assertEventuallyExists(startPoint, "The New Branch dialog did not open")
        XCTAssertEqual(
            startPoint.value as? String,
            String(UITestingCommitID.objectID(index: 2).prefix(7))
        )
    }

    /// Checking out a remote branch creates and switches to a same-name local branch; checking
    /// out a tag enters Detached HEAD instead.
    @MainActor
    func testEnglishCheckingOutARemoteBranchAndThenATag() {
        let application = branchApplication()
        application.launch()
        application.activate()

        checkOut(reference: "repository.ref.remote.origin/feature", in: application)
        XCTAssertTrue(
            waitUntil(
                NSPredicate(format: "value == %@", "feature"),
                on: application.descendants(matching: .any)["repository.head"]
            ),
            "A local tracking branch was not checked out"
        )

        checkOut(reference: "repository.ref.tag.v1.0-测试", in: application)
        assertEventuallyExists(
            application.staticTexts["Detached HEAD"],
            "Checking out a tag did not enter Detached HEAD"
        )
    }

    /// A Checkout Git refuses is reported with the paths it protected, and HEAD does not move.
    @MainActor
    func testEnglishABlockedCheckoutNamesTheWorkItProtected() {
        let application = branchApplication(
            additionalArguments: [UITestingArgument.checkoutBlocked]
        )
        application.launch()
        application.activate()

        checkOut(reference: "repository.ref.local.feature/真实", in: application)

        // Read from the alert's own text, whose string macOS carries as the element's value
        // rather than its label, and matched rather than contained: each is one leaf StaticText,
        // and `containing` asks for a matching descendant a leaf never has.
        assertEventuallyExists(
            application.sheets.staticTexts.matching(
                NSPredicate(format: "value CONTAINS %@", "partial 文件.txt")
            ).firstMatch,
            "The refusal did not name the tracked change it protected"
        )
        XCTAssertTrue(
            application.sheets.staticTexts.matching(
                NSPredicate(format: "value CONTAINS %@", "notes.txt")
            ).firstMatch.exists,
            "The refusal did not name the untracked file in the way"
        )
        // Git's own words stay one click away.
        XCTAssertTrue(application.sheets.buttons["View Details"].exists)

        application.sheets.buttons["OK"].click()
        XCTAssertEqual(
            application.descendants(matching: .any)["repository.head"].value as? String,
            "main"
        )
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

    @MainActor
    private func openNewBranchDialog(in application: XCUIApplication) {
        let newBranch = application.descendants(matching: .any)["repository.toolbar.newBranch"]
        assertEventuallyExists(newBranch, "New Branch is not in the toolbar")
        newBranch.click()
        assertEventuallyExists(
            application.descendants(matching: .any)["repository.newBranch.name"],
            "The New Branch dialog did not open"
        )
    }

    @MainActor
    private func create(named name: String, in application: XCUIApplication) {
        replaceText(
            of: application.descendants(matching: .any)["repository.newBranch.name"],
            with: name
        )
        let createButton = application.descendants(matching: .any)["repository.newBranch.create"]
        XCTAssertTrue(
            waitUntil(NSPredicate(format: "isEnabled == true"), on: createButton),
            "Create Branch never became available for “\(name)”"
        )
        createButton.click()
    }

    /// Checkout is an explicit menu action: browsing a Ref never performs it.
    ///
    /// Reached by its identifier rather than its title, because the Branch menu offers Checkout
    /// under the same title and a title query matches both.
    @MainActor
    private func checkOut(reference identifier: String, in application: XCUIApplication) {
        let reference = application.descendants(matching: .any)[identifier]
        assertEventuallyExists(reference, "\(identifier) is not in the sidebar")
        reference.rightClick()
        let checkout = application
            .descendants(matching: .menuItem)["repository.ref.checkout"]
        XCTAssertTrue(checkout.waitForExistence(timeout: 5), "Checkout is not in the Ref's menu")
        checkout.click()
    }
}
