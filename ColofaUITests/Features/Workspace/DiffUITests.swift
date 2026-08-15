////
//  DiffUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

final class DiffUITests: XCTestCase {
    /// The stubbed Repository reports this location, and the beyond-limit case needs a file that
    /// is really there before Open in Default Editor can be offered.
    private var repositoryURL = FileManager.default.temporaryDirectory

    private var repositoryPath: String { repositoryURL.path(percentEncoded: false) }

    override func setUpWithError() throws {
        continueAfterFailure = false
        repositoryURL = FileManager.default.temporaryDirectory
            .appending(path: "Colofa Diff UI \(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: repositoryURL,
            withIntermediateDirectories: true
        )
        try Data([0x00, 0x01]).write(to: repositoryURL.appending(path: "huge.bin"))
    }

    override func tearDownWithError() throws {
        // A fixture directory left behind is a failure of this test, not a detail to swallow:
        // the next run would inherit it.
        try FileManager.default.removeItem(at: repositoryURL)
    }

    @MainActor
    func testEnglishTextDiffRendersInBothLayouts() {
        let application = diffApplication()
        application.launch()
        application.activate()

        select("repository.unstaged.diff.txt", in: application)
        let content = application.descendants(matching: .any)["repository.diff.content"]
        assertEventuallyExists(content, "Diff content is not on screen")
        // The rows are lazy, so the container being on screen does not mean every row inside it
        // has reached the accessibility tree yet. Each one is waited for rather than sampled.
        assertEventuallyExists(application.staticTexts["added line"])
        assertEventuallyExists(application.staticTexts["removed line"])
        // The ranges Git states stay verbatim, so a reviewer can match them against a patch.
        assertEventuallyExists(application.staticTexts["@@ -1,4 +1,5 @@"])
        assertEventuallyExists(application.staticTexts["No newline at end of file"])

        // Switching has to keep working, not only the first time.
        let layout = application.descendants(matching: .any)["repository.diff.layout"]
        XCTAssertTrue(layout.exists)
        assertEventuallyExists(
            hunk("unified", in: application),
            "Unified is not the initial layout"
        )

        assertPanes(in: application, areSideBySide: false)

        for expected in ["Split", "Unified", "Split", "Unified"] {
            layout.radioButtons[expected].click()
            assertEventuallyExists(
                hunk(expected.lowercased(), in: application),
                "The Diff still is not laid out as \(expected)"
            )
            XCTAssertTrue(content.exists)
            assertPanes(in: application, areSideBySide: expected == "Split")
        }
    }

    /// Where the two halves of one replacement sit, which is the whole difference between the
    /// layouts and the only part of it the accessibility tree cannot state on its own.
    ///
    /// Split puts what a change removed beside what it added; Unified stacks them in one column.
    @MainActor
    private func assertPanes(
        in application: XCUIApplication,
        areSideBySide: Bool,
        line: UInt = #line
    ) {
        let content = application.descendants(matching: .any)["repository.diff.content"]
        let removed = application.staticTexts["removed line"]
        let added = application.staticTexts["added line"]
        assertEventuallyExists(removed, "The removed half of the replacement is not there", line: line)
        assertEventuallyExists(added, "The added half of the replacement is not there", line: line)

        let midX = content.frame.midX
        XCTAssertLessThan(
            removed.frame.minX, midX,
            "What the change removed belongs in the leading half",
            file: #filePath, line: line
        )
        if areSideBySide {
            XCTAssertGreaterThan(
                added.frame.minX, midX,
                "Split has to put what the change added beside what it removed",
                file: #filePath, line: line
            )
            XCTAssertEqual(
                added.frame.midY, removed.frame.midY, accuracy: 1,
                "Both halves of one replacement belong on the same row",
                file: #filePath, line: line
            )
        } else {
            XCTAssertLessThan(
                added.frame.minX, midX,
                "Unified stacks both halves in one column",
                file: #filePath, line: line
            )
        }
    }

    @MainActor
    private func hunk(_ layout: String, in application: XCUIApplication) -> XCUIElement {
        application.descendants(matching: .any)["repository.diff.hunk.\(layout)"]
    }

    @MainActor
    func testEnglishRenameBinaryAndSubmoduleDiffsStateTheirOwnFacts() {
        let application = diffApplication()
        application.launch()
        application.activate()

        select("repository.staged.renamed 名称.txt", in: application)
        assertEventuallyExists(application.staticTexts["Renamed from old name.txt"])

        select("repository.unstaged.image.bin", in: application)
        assertEventuallyExists(application.staticTexts["Binary File"])
        assertEventuallyExists(application.staticTexts["Binary content has no lines to compare."])

        select("repository.unstaged.vendor/module", in: application)
        assertEventuallyExists(application.staticTexts["Submodule"])
        assertEventuallyExists(application.staticTexts["Old Commit"])
        assertEventuallyExists(application.staticTexts["New Commit"])
        assertEventuallyExists(application.staticTexts[String(repeating: "a", count: 40)])
        assertEventuallyExists(application.staticTexts[String(repeating: "b", count: 40)])
    }

    /// What the pane shows while a patch is being read. Every other case answers at once, so this
    /// state only appears against the one Change the stub holds its read open for.
    ///
    /// The read is held until this test releases it, rather than for a fixed delay a loaded
    /// machine could spend entirely between two accessibility queries.
    @MainActor
    func testEnglishDiffReportsThatItIsLoadingUntilThePatchArrives() throws {
        let application = diffApplication()
        application.launch()
        application.activate()

        select("repository.unstaged.slow.txt", in: application)
        let loading = application.descendants(matching: .any)["repository.diff.loading"]
        assertEventuallyExists(loading, "The Diff pane does not report that it is reading")
        XCTAssertTrue(
            loading.label.contains("Loading Diff"),
            "The loading state does not name itself: “\(loading.label)”"
        )

        // The patch below arrives because the test allowed it to, which is what makes the state
        // above one this test observed rather than one it happened to be in time for.
        try UITestingSlowDiff.release(in: repositoryURL)

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.diff.content"],
            "The patch never replaced the loading state"
        )
        XCTAssertFalse(loading.exists)
    }

    @MainActor
    func testEnglishPatchAboveTheAutomaticLimitIsOfferedThenRendered() {
        let application = diffApplication()
        application.launch()
        application.activate()

        select("repository.unstaged.large.txt", in: application)
        let summary = application.descendants(matching: .any)["repository.diff.summary"]
        assertEventuallyExists(summary, "The offer to load a large Diff is not on screen")
        XCTAssertTrue(application.staticTexts["Diff Not Loaded Automatically"].exists)
        XCTAssertTrue(application.staticTexts["Changed Files"].exists)
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.diff.content"].exists
        )

        let loadAnyway = application.descendants(matching: .any)["repository.diff.loadAnyway"]
        XCTAssertTrue(loadAnyway.exists)
        XCTAssertEqual(loadAnyway.label, "Load Anyway")
        loadAnyway.click()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.diff.content"],
            "Confirming did not render the Diff"
        )
    }

    @MainActor
    func testEnglishPatchBeyondTheHardLimitShowsStatsWithoutOfferingToLoadIt() {
        let application = diffApplication()
        application.launch()
        application.activate()

        select("repository.unstaged.huge.bin", in: application)
        assertEventuallyExists(application.staticTexts["Diff Too Large to Render"])
        XCTAssertTrue(application.staticTexts["Size"].exists)
        XCTAssertTrue(application.staticTexts["Lines"].exists)
        // The counts are floors, because reading stopped before the patch ended.
        XCTAssertTrue(application.staticTexts["More than 100,000"].exists)
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.diff.loadAnyway"].exists
        )

        let openInEditor = application.descendants(matching: .any)["repository.diff.openInEditor"]
        XCTAssertTrue(openInEditor.exists)
        XCTAssertEqual(openInEditor.label, "Open in Default Editor")
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.diff.pathAbsent"].exists
        )
    }

    /// A deletion beyond a hard limit has no file left to open, so the state says that rather
    /// than showing counts and offering nothing.
    @MainActor
    func testEnglishDeletedPathBeyondTheHardLimitExplainsWhyItCannotBeOpened() {
        let application = diffApplication()
        application.launch()
        application.activate()

        select("repository.unstaged.deleted-huge.txt", in: application)
        assertEventuallyExists(application.staticTexts["Diff Too Large to Render"])
        XCTAssertTrue(application.staticTexts["Changed Files"].exists)

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.diff.pathAbsent"],
            "A refused Diff with no file to open has to say so"
        )
        XCTAssertTrue(
            application.staticTexts[
                "This path is no longer in the working tree, so there is no file to open."
            ].exists
        )
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.diff.openInEditor"].exists
        )
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.diff.loadAnyway"].exists
        )
    }

    @MainActor
    private func select(_ identifier: String, in application: XCUIApplication) {
        let row = application.descendants(matching: .any)[identifier]
        assertEventuallyExists(row, "Change “\(identifier)” is not in the list")
        scrollIntoView(row, identifiedBy: identifier, in: application)
        row.click()
    }

    /// Brings a row into view before it is clicked.
    ///
    /// The change list is lazy: a row can be in the accessibility tree while sitting outside the
    /// viewport, and clicking it there lands on whatever is actually at that point.
    @MainActor
    private func scrollIntoView(
        _ element: XCUIElement,
        identifiedBy identifier: String,
        in application: XCUIApplication
    ) {
        let list = application.scrollViews.containing(.any, identifier: identifier).firstMatch
        var remainingScrolls = 10
        while !element.isHittable, remainingScrolls > 0, list.exists {
            list.scroll(byDeltaX: 0, deltaY: -30)
            remainingScrolls -= 1
        }
    }

    @MainActor
    private func diffApplication() -> XCUIApplication {
        XCUIApplication.configuredForRepository(
            path: repositoryPath,
            additionalArguments: [UITestingArgument.diffState]
        )
    }
}
