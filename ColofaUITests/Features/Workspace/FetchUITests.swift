////
//  FetchUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// Fetch and Fetch Tags, driven the way a user reaches them: the toolbar, the Tags section, and
/// the dialog that asks which remote the tags come from.
final class FetchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The toolbar's Fetch refreshes every remote and updates the app-owned last-Fetch time.
    @MainActor
    func testEnglishToolbarFetchRefreshesRemoteRefsAndTheLastFetchTime() {
        let application = fetchApplication()
        application.launch()
        application.activate()

        let lastFetch = application.descendants(matching: .any)["repository.lastFetch"]
        assertEventuallyExists(lastFetch, "The status bar does not report the last Fetch")
        XCTAssertEqual(lastFetch.value as? String, "Never")

        application.descendants(matching: .any)["repository.toolbar.fetch"].click()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.ref.remote.origin/新分支"],
            "The Fetch did not bring in a remote branch"
        )
        XCTAssertTrue(
            waitUntil(NSPredicate(format: "value != %@", "Never"), on: lastFetch),
            "The last Fetch time was not recorded"
        )
    }

    /// Nothing contacts a remote on its own: the time stays “Never” until Fetch is pressed.
    @MainActor
    func testEnglishNothingIsFetchedUntilTheUserAsksForIt() {
        let application = fetchApplication()
        application.launch()
        application.activate()

        let lastFetch = application.descendants(matching: .any)["repository.lastFetch"]
        assertEventuallyExists(lastFetch, "The status bar does not report the last Fetch")
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.ref.remote.origin/新分支"].exists,
            "A remote was contacted without being asked"
        )
        XCTAssertEqual(lastFetch.value as? String, "Never")
    }

    /// A Repository with no remote explains why Fetch is disabled rather than failing afterwards.
    @MainActor
    func testEnglishFetchIsDisabledWithoutARemoteAndSaysWhy() {
        let application = XCUIApplication.configuredForRepository(
            path: FileManager.default.temporaryDirectory.path(percentEncoded: false)
        )
        application.launch()
        application.activate()

        let fetch = application.descendants(matching: .any)["repository.toolbar.fetch"]
        assertEventuallyExists(fetch, "The toolbar has no Fetch")
        XCTAssertFalse(fetch.isEnabled)
    }

    /// A remote that fails is named, and the refresh the other one achieved is kept.
    @MainActor
    func testEnglishAFailingRemoteIsNamedWhileTheOtherStaysRefreshed() {
        let application = fetchApplication(
            additionalArguments: [UITestingArgument.fetchFailure]
        )
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.toolbar.fetch"].click()

        assertEventuallyExists(
            application.sheets.staticTexts.matching(
                NSPredicate(format: "value CONTAINS %@", "mirror")
            ).firstMatch,
            "The failure did not name the remote that failed"
        )
        XCTAssertTrue(application.sheets.buttons["View Details"].exists)
        application.sheets.buttons["OK"].click()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.ref.remote.origin/新分支"],
            "The remote that answered was not kept refreshed"
        )
    }

    /// A running Fetch offers the way out in the place the user pressed Fetch.
    @MainActor
    func testEnglishARunningFetchCanBeCancelled() {
        let application = fetchApplication(additionalArguments: [UITestingArgument.slowFetch])
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.toolbar.fetch"].click()

        let cancel = application.descendants(matching: .any)["repository.toolbar.cancelFetch"]
        assertEventuallyExists(cancel, "A running Fetch offered no way to stop it")
        cancel.click()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.toolbar.fetch"],
            "Cancelling did not return the toolbar to Fetch"
        )
        XCTAssertEqual(
            application.descendants(matching: .any)["repository.lastFetch"].value as? String,
            "Never",
            "A cancelled Fetch recorded a time"
        )
    }

    /// The toolbar is where a Fetch is normally stopped, but macOS lets the user hide it — so a
    /// Fetch reached through the menu bar can be stopped there too.
    @MainActor
    func testEnglishARunningFetchCanBeCancelledFromTheRepositoryMenu() {
        let application = fetchApplication(additionalArguments: [UITestingArgument.slowFetch])
        application.launch()
        application.activate()

        application.menuBars.menuBarItems["Repository"].click()
        application.menuItems["Fetch"].click()

        application.menuBars.menuBarItems["Repository"].click()
        let cancel = application.menuItems["Cancel Fetch"]
        assertEventuallyExists(cancel, "The Repository menu offered no way to stop a Fetch")
        cancel.click()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.toolbar.fetch"],
            "Cancelling from the menu did not end the Fetch"
        )
        XCTAssertEqual(
            application.descendants(matching: .any)["repository.lastFetch"].value as? String,
            "Never",
            "A cancelled Fetch recorded a time"
        )
    }

    /// The Tags section is where Fetch Tags lives, and one remote is answered without asking.
    @MainActor
    func testEnglishFetchTagsUsesASoleRemoteWithoutAsking() {
        let application = fetchApplication(additionalArguments: [UITestingArgument.singleRemote])
        application.launch()
        application.activate()

        let fetchTags = application.descendants(matching: .any)["repository.tags.fetch"]
        assertEventuallyExists(fetchTags, "The Tags section has no Fetch Tags")
        fetchTags.click()

        XCTAssertFalse(
            application.descendants(matching: .any)["repository.fetchTags.confirm"].exists,
            "A single remote was turned into a question"
        )
        assertEventuallyExists(
            application.descendants(matching: .any)["repository.ref.tag.v2.0-新"],
            "Fetch Tags did not bring in a tag"
        )
    }

    /// Several remotes are a question, `origin` is where it starts, and nothing runs until the
    /// dialog's own button is pressed.
    @MainActor
    func testEnglishFetchTagsAsksAmongSeveralRemotesWithOriginPreselected() {
        let application = fetchApplication()
        application.launch()
        application.activate()

        let fetchTags = application.descendants(matching: .any)["repository.tags.fetch"]
        assertEventuallyExists(fetchTags, "The Tags section has no Fetch Tags")
        fetchTags.click()

        let remote = application.descendants(matching: .any)["repository.fetchTags.remote"]
        assertEventuallyExists(remote, "Fetch Tags did not ask which remote to use")
        XCTAssertEqual(remote.value as? String, "origin")
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.ref.tag.v2.0-新"].exists,
            "Opening the dialog fetched something on its own"
        )

        application.descendants(matching: .any)["repository.fetchTags.confirm"].click()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.ref.tag.v2.0-新"],
            "Confirming the dialog did not fetch the tags"
        )
    }

    /// Cancelling the dialog runs nothing at all.
    @MainActor
    func testEnglishCancellingTheFetchTagsDialogFetchesNothing() {
        let application = fetchApplication()
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.tags.fetch"].click()
        let cancel = application.descendants(matching: .any)["repository.fetchTags.cancel"]
        assertEventuallyExists(cancel, "Fetch Tags did not ask which remote to use")
        cancel.click()

        XCTAssertFalse(
            application.descendants(matching: .any)["repository.ref.tag.v2.0-新"].exists,
            "Cancelling the dialog still fetched tags"
        )
    }

    /// Git refuses to replace a local tag of the same name, and the refusal names the tag it
    /// kept while leaving that tag exactly where it was.
    @MainActor
    func testEnglishARefusedFetchTagsNamesTheTagsGitKept() {
        let application = fetchApplication(
            additionalArguments: [UITestingArgument.singleRemote, UITestingArgument.tagConflict]
        )
        application.launch()
        application.activate()

        let fetchTags = application.descendants(matching: .any)["repository.tags.fetch"]
        assertEventuallyExists(fetchTags, "The Tags section has no Fetch Tags")
        fetchTags.click()

        assertEventuallyExists(
            application.sheets.staticTexts.matching(
                NSPredicate(format: "value CONTAINS %@", "v1.0-测试")
            ).firstMatch,
            "The refusal did not name the tag Git kept"
        )
        XCTAssertTrue(application.sheets.buttons["View Details"].exists)
        application.sheets.buttons["OK"].click()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.ref.tag.v1.0-测试"],
            "The local tag Git kept is gone"
        )
    }

    @MainActor
    private func fetchApplication(
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        XCUIApplication.configuredForFetchState(
            path: FileManager.default.temporaryDirectory.path(percentEncoded: false),
            additionalArguments: additionalArguments
        )
    }
}
