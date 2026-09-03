////
//  ToolbarHelpUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// The tooltips of the top-right toolbar, which is where its six items keep their titles.
///
/// `DESIGN.md` §8 removed the text titles so the high-frequency buttons stay visible instead of
/// collapsing into the overflow menu, and moved each title into the tooltip and the VoiceOver
/// label. That trade only holds while the tooltip actually appears, and a disabled item is where
/// it matters most: the reason a Push is unavailable is stated there and nowhere else on screen.
///
/// These assert delivery — that hovering puts a tooltip on the screen — for the three states each
/// item has. What each one says is asserted by the unavailability-reason unit suites.
final class ToolbarHelpUITests: XCTestCase {
    private let repositoryPath = FileManager.default.temporaryDirectory
        .path(percentEncoded: false)

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Every one of the six carries a tooltip when it is available.
    @MainActor
    func testEnglishEveryToolbarItemShowsATooltipWhenItIsAvailable() {
        let application = XCUIApplication.configuredForFetchState(path: repositoryPath)
        application.launch()
        application.activate()

        let any = application.descendants(matching: .any)
        assertEventuallyExists(any["repository.toolbar.fetch"], "The toolbar has no Fetch")

        for identifier in [
            "repository.toolbar.fetch",
            "repository.toolbar.pull",
            "repository.toolbar.push",
            "repository.toolbar.newBranch",
            "repository.toolbar.stash",
            "baseline.inspector.toggle",
        ] {
            assertShowsTooltip(
                over: any[identifier],
                parkedOn: any["repository.path"],
                "\(identifier) showed no tooltip on hover"
            )
        }
    }

    /// A Repository with no remote and no Commit disables four of them, and the tooltip is the
    /// only place each one says why.
    @MainActor
    func testEnglishADisabledToolbarItemStillShowsWhyItIsUnavailable() {
        let application = XCUIApplication.configuredForRepository(path: repositoryPath)
        application.launch()
        application.activate()

        let any = application.descendants(matching: .any)
        assertEventuallyExists(any["repository.toolbar.fetch"], "The toolbar has no Fetch")

        for identifier in [
            "repository.toolbar.fetch",
            "repository.toolbar.pull",
            "repository.toolbar.push",
            "repository.toolbar.newBranch",
        ] {
            XCTAssertFalse(any[identifier].isEnabled, "\(identifier) is not disabled here")
            assertShowsTooltip(
                over: any[identifier],
                parkedOn: any["repository.path"],
                "Disabled \(identifier) never said why"
            )
        }
    }

    /// A running Fetch replaces the button with a spinner, and the tooltip is what reports how far
    /// the command has got.
    @MainActor
    func testEnglishARunningFetchShowsItsProgressAsATooltip() {
        let application = XCUIApplication.configuredForFetchState(
            path: repositoryPath,
            additionalArguments: [UITestingArgument.slowFetch]
        )
        application.launch()
        application.activate()

        let any = application.descendants(matching: .any)
        assertEventuallyExists(any["repository.toolbar.fetch"], "The toolbar has no Fetch")
        any["repository.toolbar.fetch"].click()

        let cancel = any["repository.toolbar.cancelFetch"]
        assertEventuallyExists(cancel, "A running Fetch offered no way to stop it")
        assertShowsTooltip(
            over: cancel,
            parkedOn: any["repository.path"],
            "A running Fetch reported no progress"
        )
    }

    /// Pull runs the same shape from a view struct of its own, so it is asserted separately.
    @MainActor
    func testEnglishARunningPullShowsItsProgressAsATooltip() {
        let application = XCUIApplication.configuredForPullState(
            path: repositoryPath,
            additionalArguments: [UITestingArgument.slowFetch]
        )
        application.launch()
        application.activate()

        let any = application.descendants(matching: .any)
        assertEventuallyExists(any["repository.toolbar.pull"], "The toolbar has no Pull")
        any["repository.toolbar.pull"].click()

        let cancel = any["repository.toolbar.cancelPull"]
        assertEventuallyExists(cancel, "A running Pull offered no way to stop it")
        assertShowsTooltip(
            over: cancel,
            parkedOn: any["repository.path"],
            "A running Pull reported no progress"
        )
    }

    /// Push is the third, and the only one that asks before it runs.
    @MainActor
    func testEnglishARunningPushShowsItsProgressAsATooltip() {
        let application = XCUIApplication.configuredForPushState(
            path: repositoryPath,
            additionalArguments: [UITestingArgument.slowFetch]
        )
        application.launch()
        application.activate()

        let any = application.descendants(matching: .any)
        assertEventuallyExists(any["repository.toolbar.push"], "The toolbar has no Push")
        any["repository.toolbar.push"].click()

        let confirm = application.sheets.buttons["repository.push.confirm"]
        assertEventuallyExists(confirm, "Push did not ask before it ran")
        confirm.click()

        let cancel = any["repository.toolbar.cancelPush"]
        assertEventuallyExists(cancel, "A running Push offered no way to stop it")
        assertShowsTooltip(
            over: cancel,
            parkedOn: any["repository.path"],
            "A running Push reported no progress"
        )
    }

    /// Publish is the name Push takes for a Branch nobody has pushed yet, and it carries a tooltip
    /// of its own rather than inheriting Push's.
    @MainActor
    func testEnglishPublishShowsItsOwnTooltip() {
        let application = XCUIApplication.configuredForPushState(
            path: repositoryPath,
            additionalArguments: [UITestingArgument.pushNoUpstream]
        )
        application.launch()
        application.activate()

        let publish = application.descendants(matching: .any)["repository.toolbar.publish"]
        assertEventuallyExists(publish, "The toolbar has no Publish")
        assertShowsTooltip(
            over: publish,
            parkedOn: application.descendants(matching: .any)["repository.path"],
            "Publish showed no tooltip on hover"
        )
    }
}
