////
//  RepositoryOpeningUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

final class RepositoryOpeningUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEnglishRestoresRepositoryIdentityPathAndUnbornBranch() {
        let repositoryPath = "/tmp/Colofa UI 测试"
        let repositoryURL = URL(filePath: repositoryPath)
        let application = XCUIApplication.configuredForRepository(path: repositoryPath)
        application.launch()
        application.activate()

        let picker = application.descendants(matching: .any)["baseline.repositoryPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertEqual(picker.value as? String, repositoryURL.lastPathComponent)

        let path = application.descendants(matching: .any)["repository.path"]
        XCTAssertTrue(path.waitForExistence(timeout: 5))
        XCTAssertEqual(path.value as? String, repositoryPath)

        let head = application.staticTexts.matching(identifier: "repository.head")
        XCTAssertTrue(head.firstMatch.waitForExistence(timeout: 5))
        let headValues = head.allElementsBoundByIndex.compactMap { $0.value as? String }
        XCTAssertTrue(headValues.contains("main"))
        XCTAssertTrue(headValues.contains("Unborn Branch"))
    }

    @MainActor
    func testEnglishShowsRealRepositoryState() {
        let repositoryPath = "/tmp/Colofa Real State"
        let application = XCUIApplication.configuredForRealRepositoryState(path: repositoryPath)
        application.launch()
        application.activate()

        let picker = application.descendants(matching: .any)["baseline.repositoryPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))

        let head = application.descendants(matching: .any)["repository.head"]
        XCTAssertTrue(head.waitForExistence(timeout: 5))
        XCTAssertEqual(head.label, "Current Branch")
        XCTAssertEqual(head.value as? String, "main")

        let operationBanner = application.descendants(matching: .any)["repository.operation"]
        XCTAssertTrue(operationBanner.waitForExistence(timeout: 5))
        XCTAssertTrue(
            (operationBanner.value as? String)?.contains("Merge in Progress") == true
        )

        application.descendants(matching: .any)["baseline.section.history"].click()
        // History shows what HEAD reaches, which this Repository has.
        XCTAssertTrue(
            application.descendants(matching: .any)["repository.history"]
                .waitForExistence(timeout: 5)
        )
        application.descendants(matching: .any)["baseline.section.stashes"].click()
        XCTAssertTrue(
            application.descendants(matching: .any)["baseline.empty.stashes"]
                .waitForExistence(timeout: 2)
        )
        application.descendants(matching: .any)["baseline.section.changes"].click()

        XCTAssertTrue(application.staticTexts["Staged Changes"].exists)
        XCTAssertTrue(application.staticTexts["Changes"].exists)

        let addedChange = application.descendants(matching: .any)[
            "repository.staged.added.swift"
        ]
        XCTAssertTrue(addedChange.exists)
        XCTAssertEqual(addedChange.label, "Added")

        let staged = application.descendants(matching: .any)[
            "repository.staged.partial 文件.txt"
        ]
        XCTAssertTrue(staged.exists)
        XCTAssertEqual(staged.label, "Modified")
        XCTAssertEqual(staged.value as? String, "partial 文件.txt")

        let unstagedPartial = application.descendants(matching: .any)[
            "repository.unstaged.partial 文件.txt"
        ]
        XCTAssertTrue(unstagedPartial.exists)
        XCTAssertEqual(unstagedPartial.label, "Modified")

        let conflicted = application.descendants(matching: .any)[
            "repository.unstaged.conflict.txt"
        ]
        XCTAssertTrue(conflicted.exists)
        XCTAssertEqual(conflicted.label, "Conflict")

        let deletedChange = application.descendants(matching: .any)[
            "repository.unstaged.deleted.swift"
        ]
        XCTAssertTrue(deletedChange.exists)
        XCTAssertEqual(deletedChange.label, "Deleted")

        let typeChangedChange = application.descendants(matching: .any)[
            "repository.unstaged.Link"
        ]
        XCTAssertTrue(typeChangedChange.exists)
        XCTAssertEqual(typeChangedChange.label, "Type Changed")

        let untrackedChange = application.descendants(matching: .any)[
            "repository.unstaged.notes.txt"
        ]
        XCTAssertTrue(untrackedChange.exists)
        XCTAssertEqual(untrackedChange.label, "Untracked")

        let renamedChange = application.descendants(matching: .any)[
            "repository.staged.renamed 名称.txt"
        ]
        XCTAssertTrue(renamedChange.exists)
        XCTAssertEqual(renamedChange.label, "Renamed")
        XCTAssertEqual(
            renamedChange.value as? String,
            "From old name.txt, To renamed 名称.txt"
        )

        XCTAssertTrue(application.staticTexts["feature/真实"].exists)
        XCTAssertTrue(application.staticTexts["origin"].exists)
        XCTAssertTrue(application.staticTexts["origin/main"].exists)
        XCTAssertTrue(application.staticTexts["v1.0-测试"].exists)

        application.descendants(matching: .any)["baseline.inspector.toggle"].click()
        XCTAssertTrue(application.staticTexts["Git Object Size"].waitForExistence(timeout: 2))
        XCTAssertTrue(application.staticTexts["Commits"].exists)
    }

    @MainActor
    func testEnglishShowsAdditionalHeadAndOperationStates() {
        let repositoryPath = "/tmp/Colofa Operation State"
        let rebasing = XCUIApplication.configuredForRealRepositoryState(
            path: repositoryPath,
            additionalArguments: [
                UITestingArgument.detachedHead,
                UITestingArgument.rebase,
            ]
        )
        rebasing.launch()
        rebasing.activate()

        let rebaseBanner = rebasing.descendants(matching: .any)["repository.operation"]
        XCTAssertTrue(rebaseBanner.waitForExistence(timeout: 5))
        XCTAssertTrue((rebaseBanner.value as? String)?.contains("Rebase in Progress") == true)
        XCTAssertTrue(rebasing.staticTexts["Detached HEAD"].exists)
        rebasing.terminate()

        let applyingMailbox = XCUIApplication.configuredForRealRepositoryState(
            path: repositoryPath,
            additionalArguments: [
                UITestingArgument.am,
            ]
        )
        applyingMailbox.launch()
        applyingMailbox.activate()

        let amBanner = applyingMailbox.descendants(matching: .any)["repository.operation"]
        XCTAssertTrue(amBanner.waitForExistence(timeout: 5))
        XCTAssertTrue((amBanner.value as? String)?.contains("git am in Progress") == true)
        applyingMailbox.terminate()

        let cherryPicking = XCUIApplication.configuredForRealRepositoryState(
            path: repositoryPath,
            additionalArguments: [
                UITestingArgument.cherryPick,
            ]
        )
        cherryPicking.launch()
        cherryPicking.activate()

        let cherryPickBanner = cherryPicking.descendants(matching: .any)["repository.operation"]
        XCTAssertTrue(cherryPickBanner.waitForExistence(timeout: 5))
        XCTAssertTrue(
            (cherryPickBanner.value as? String)?.contains("Cherry-pick in Progress") == true
        )
        cherryPicking.terminate()

        let reverting = XCUIApplication.configuredForRealRepositoryState(
            path: repositoryPath,
            additionalArguments: [
                UITestingArgument.revert,
                UITestingArgument.remoteBranchesOnly,
            ]
        )
        reverting.launch()
        reverting.activate()

        let revertBanner = reverting.descendants(matching: .any)["repository.operation"]
        XCTAssertTrue(revertBanner.waitForExistence(timeout: 5))
        XCTAssertTrue((revertBanner.value as? String)?.contains("Revert in Progress") == true)
        XCTAssertTrue(reverting.staticTexts["origin/main"].exists)
        XCTAssertFalse(reverting.staticTexts["No Remotes"].exists)
    }

    @MainActor
    func testEnglishExplainsBareRepositoryRefusal() {
        let application = XCUIApplication.configuredForUITesting(
            additionalArguments: [
                UITestingArgument.repositoryService,
                UITestingArgument.bareRepository,
            ]
        )
        application.launch()
        application.activate()

        let picker = application.descendants(matching: .any)["baseline.repositoryPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.click()
        let sheet = application.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 8))
        // Pin the open panel to the home directory. Without this the panel restores whatever
        // location it last used, so both the selection and the Open button's enabled state
        // would depend on machine state rather than on the app under test.
        application.typeKey("h", modifierFlags: [.command, .shift])
        let openButton = sheet.buttons["OKButton"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 2))
        XCTAssertTrue(openButton.isEnabled)
        openButton.click()

        XCTAssertTrue(
            application.staticTexts["Bare Repository Is Unsupported"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(application.buttons["Choose Another Repository"].exists)
    }

    @MainActor
    func testEnglishExplainsUnavailableGit() {
        let application = XCUIApplication.configuredForUITesting(
            additionalArguments: [UITestingArgument.gitUnavailable]
        )
        application.launch()
        application.activate()

        XCTAssertTrue(application.staticTexts["Git Is Not Available"].waitForExistence(timeout: 5))
        XCTAssertFalse(
            application.descendants(matching: .any)["baseline.inspector.toggle"].exists
        )
    }

    @MainActor
    func testEnglishFileMenuOpensRepositoryPicker() {
        let application = XCUIApplication.configuredForUITesting()
        application.launch()
        application.activate()

        application.menuBars.menuBarItems["File"].click()
        let menuItem = application.menuItems["Open Repository"]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 2))
        menuItem.click()
        assertNativeFolderPicker(in: application)
    }

    @MainActor
    func testEnglishIdentityControlOpensNativeFolderPicker() {
        let application = XCUIApplication.configuredForUITesting()
        application.launch()
        application.activate()

        let picker = application.descendants(matching: .any)["baseline.repositoryPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 2))
        picker.click()
        assertNativeFolderPicker(in: application)
    }

    @MainActor
    private func assertNativeFolderPicker(in application: XCUIApplication) {
        XCTAssertTrue(application.sheets.firstMatch.waitForExistence(timeout: 8))
        application.typeKey(.escape, modifierFlags: [])
    }
}
