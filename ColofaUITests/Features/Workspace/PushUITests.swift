////
//  PushUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// Publish and Push, driven the way a user reaches them: the toolbar, the Repository menu, the
/// confirmation, and the alerts a refused Push puts on screen.
final class PushUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Publish

    /// A Branch nobody has pushed yet offers Publish rather than Push, and publishing it gives it
    /// an upstream.
    @MainActor
    func testEnglishAbranchWithoutAnupstreamIsPublishedRatherThanPushed() {
        let application = pushApplication(
            additionalArguments: [UITestingArgument.pushNoUpstream]
        )
        application.launch()
        application.activate()

        let publish = application.descendants(matching: .any)["repository.toolbar.publish"]
        assertEventuallyExists(publish, "The toolbar offered no way to publish the Branch")
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.toolbar.push"].exists,
            "A Branch with no upstream still offered Push"
        )
        publish.click()

        let upstream = application.descendants(matching: .any)["repository.upstream"]
        assertEventuallyExists(upstream, "The Publish never established an upstream")
        XCTAssertEqual(upstream.value as? String, "origin/main, Ahead 0, Behind 0")
    }

    /// Several remotes and nothing configured is the one ambiguous case, so Colofa asks — with
    /// `origin` preselected and nothing published until the dialog's own button is pressed.
    @MainActor
    func testEnglishPublishingWithSeveralRemotesAsksWhichOne() {
        let application = pushApplication(
            additionalArguments: [
                UITestingArgument.pushNoUpstream,
                UITestingArgument.pushManyRemotes,
            ]
        )
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.toolbar.publish"].click()

        let remote = application.descendants(matching: .any)["repository.publish.remote"]
        assertEventuallyExists(remote, "Several remotes were not asked about")
        XCTAssertEqual(remote.value as? String, "origin")

        application.sheets.buttons["repository.publish.cancel"].click()
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.upstream"].exists,
            "Cancelling the dialog published the Branch anyway"
        )
    }

    /// A configured push remote is the user's answer already given, so Colofa never asks it back.
    @MainActor
    func testEnglishAconfiguredPushRemoteIsUsedWithoutAsking() {
        let application = pushApplication(
            additionalArguments: [
                UITestingArgument.pushNoUpstream,
                UITestingArgument.pushManyRemotes,
                UITestingArgument.pushConfiguredRemote,
            ]
        )
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.toolbar.publish"].click()

        let upstream = application.descendants(matching: .any)["repository.upstream"]
        assertEventuallyExists(upstream, "The configured remote was never published to")
        XCTAssertEqual(upstream.value as? String, "mirror/main, Ahead 0, Behind 0")
    }

    // MARK: - Destinations no confirmation can describe

    /// A remote with several push addresses is refused before the confirmation opens, because one
    /// Push writes to all of them and no confirmation could say where it went.
    @MainActor
    func testEnglishAremoteWithSeveralPushAddressesIsRefusedWithAnexplanation() {
        let application = pushApplication(
            additionalArguments: [UITestingArgument.pushSeveralDestinations]
        )
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.toolbar.push"].click()

        assertEventuallyExists(
            application.sheets.staticTexts.matching(
                NSPredicate(format: "value CONTAINS %@", "every address below in turn")
            ).firstMatch,
            "The several push addresses were not explained"
        )
        XCTAssertFalse(
            application.sheets.buttons["repository.push.confirm"].exists,
            "A destination Colofa cannot describe was offered for confirmation"
        )
        application.sheets.buttons["OK"].click()
    }

    // MARK: - Push

    /// Pressing Push shows where it is about to go before anything leaves, with the dangerous
    /// option off.
    @MainActor
    func testEnglishPushConfirmsTheBranchAndItsUpstreamBeforeSending() {
        let application = pushApplication()
        application.launch()
        application.activate()

        let upstream = application.descendants(matching: .any)["repository.upstream"]
        assertEventuallyExists(upstream, "The status bar does not report the upstream")
        XCTAssertEqual(upstream.value as? String, "origin/main, Ahead 2, Behind 0")

        application.descendants(matching: .any)["repository.toolbar.push"].click()

        let branch = application.descendants(matching: .any)["repository.push.branch"]
        assertEventuallyExists(branch, "The Push never confirmed anything")
        XCTAssertEqual(branch.value as? String, "main")
        XCTAssertEqual(
            application.descendants(matching: .any)["repository.push.target"].value as? String,
            "origin/main"
        )
        // The upstream names a remote; this is the address that name resolves to. It is the one
        // fact a confirmation about writing to somebody else's copy has to establish.
        XCTAssertEqual(
            application.descendants(matching: .any)["repository.push.destination"].value as? String,
            "ssh://example.invalid/Colofa.git"
        )
        let force = application.checkBoxes["repository.push.forceWithLease"]
        XCTAssertTrue(force.exists, "The confirmation offered no Force Push with Lease")
        XCTAssertEqual(force.value as? Int, 0, "Force Push with Lease was not off by default")

        application.sheets.buttons["repository.push.confirm"].click()

        XCTAssertTrue(
            waitUntil(
                NSPredicate(format: "value == %@", "origin/main, Ahead 0, Behind 0"),
                on: upstream
            ),
            "The Push did not leave the Branch at its upstream"
        )
    }

    /// An upstream that moved on says so in its own words, and never suggests forcing over it.
    @MainActor
    func testEnglishArejectedPushExplainsItselfWithoutRecommendingForce() {
        let application = pushApplication(additionalArguments: [UITestingArgument.pushRejected])
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.toolbar.push"].click()
        assertEventuallyExists(
            application.sheets.buttons["repository.push.confirm"],
            "The Push never confirmed anything"
        )
        application.sheets.buttons["repository.push.confirm"].click()

        let message = application.sheets.staticTexts.matching(
            NSPredicate(format: "value CONTAINS %@", "Merge or Rebase")
        ).firstMatch
        assertEventuallyExists(message, "The refusal did not direct the user to integrate first")
        XCTAssertTrue(application.sheets.buttons["View Details"].exists)
        application.sheets.buttons["OK"].click()
    }

    /// The lease is what protects work nobody had seen, and refusing it is its own answer.
    @MainActor
    func testEnglishAforcePushWhoseLeaseNoLongerMatchesIsRefused() {
        let application = pushApplication(additionalArguments: [UITestingArgument.pushStaleLease])
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.toolbar.push"].click()
        let force = application.checkBoxes["repository.push.forceWithLease"]
        assertEventuallyExists(force, "The confirmation offered no Force Push with Lease")
        force.click()
        application.sheets.buttons["repository.push.confirm"].click()

        assertEventuallyExists(
            application.sheets.staticTexts.matching(
                NSPredicate(format: "value CONTAINS %@", "lease")
            ).firstMatch,
            "The refused lease was not explained as one"
        )
        application.sheets.buttons["OK"].click()
    }

    /// Ticking the box changes what the button does, so it changes what the button says. The
    /// destructive role is what makes the system render and announce it as destructive, which is
    /// the one thing that cannot be checked without running the real control.
    @MainActor
    func testEnglishTheConfirmButtonBecomesAforcePushWhenTheBoxIsTicked() {
        let application = pushApplication()
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.toolbar.push"].click()

        let confirm = application.sheets.buttons["repository.push.confirm"]
        assertEventuallyExists(confirm, "The Push never confirmed anything")
        XCTAssertEqual(confirm.label, "Push")

        let force = application.checkBoxes["repository.push.forceWithLease"]
        XCTAssertTrue(force.exists, "The confirmation offered no Force Push with Lease")
        force.click()

        XCTAssertTrue(
            waitUntil(NSPredicate(format: "label == %@", "Force Push"), on: confirm),
            "The button still offered an ordinary Push after the box was ticked"
        )
    }

    /// An upstream Colofa has never seen offers no object to lease against, so the option cannot
    /// be ticked at all rather than turning into a naked force.
    @MainActor
    func testEnglishAnupstreamWithNoObservedObjectOffersNoForce() {
        let application = pushApplication(
            additionalArguments: [UITestingArgument.pushWithoutLease]
        )
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.toolbar.push"].click()

        let force = application.checkBoxes["repository.push.forceWithLease"]
        assertEventuallyExists(force, "The confirmation offered no Force Push with Lease")
        XCTAssertFalse(force.isEnabled)
        XCTAssertTrue(
            application.descendants(matching: .any)["repository.push.forceNote"].exists,
            "Nothing explained why the option could not be used"
        )
    }

    // MARK: - Disabled states

    /// Detached HEAD is on no Branch, so there is nothing to publish and nowhere to push.
    @MainActor
    func testEnglishPushIsDisabledInDetachedHead() {
        let application = pushApplication(additionalArguments: [UITestingArgument.detachedHead])
        application.launch()
        application.activate()

        let push = application.descendants(matching: .any)["repository.toolbar.push"]
        assertEventuallyExists(push, "The toolbar has no Push")
        XCTAssertFalse(push.isEnabled)
    }

    // MARK: - Cancelling

    /// A running Push offers the way out in the place the user pressed Push.
    @MainActor
    func testEnglishArunningPushCanBeCancelled() {
        let application = pushApplication(additionalArguments: [UITestingArgument.slowFetch])
        application.launch()
        application.activate()

        application.descendants(matching: .any)["repository.toolbar.push"].click()
        assertEventuallyExists(
            application.sheets.buttons["repository.push.confirm"],
            "The Push never confirmed anything"
        )
        application.sheets.buttons["repository.push.confirm"].click()

        let cancel = application.descendants(matching: .any)["repository.toolbar.cancelPush"]
        assertEventuallyExists(cancel, "A running Push offered no way to stop it")
        cancel.click()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.toolbar.push"],
            "Cancelling did not return the toolbar to Push"
        )
    }

    /// The toolbar is where a Push is normally started and stopped, but macOS lets the user hide
    /// it — so the Repository menu carries both.
    @MainActor
    func testEnglishArunningPushCanBeCancelledFromTheRepositoryMenu() {
        let application = pushApplication(additionalArguments: [UITestingArgument.slowFetch])
        application.launch()
        application.activate()

        application.menuBars.menuBarItems["Repository"].click()
        application.menuItems["Push"].click()
        assertEventuallyExists(
            application.sheets.buttons["repository.push.confirm"],
            "The Push never confirmed anything"
        )
        application.sheets.buttons["repository.push.confirm"].click()

        application.menuBars.menuBarItems["Repository"].click()
        let cancel = application.menuItems["Cancel Push"]
        assertEventuallyExists(cancel, "The Repository menu offered no way to stop a Push")
        cancel.click()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.toolbar.push"],
            "Cancelling from the menu did not end the Push"
        )
    }

    private func pushApplication(additionalArguments: [String] = []) -> XCUIApplication {
        XCUIApplication.configuredForPushState(
            path: FileManager.default.temporaryDirectory.path(percentEncoded: false),
            additionalArguments: additionalArguments
        )
    }
}
