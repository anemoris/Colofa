////
//  PullOutcomeTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What one Pull's answer says about the two very different halves it is made of.
struct PullOutcomeTests {
    private static let failure = RepositoryOpenError.commandFailed(
        GitFailureDetails(command: "git merge", output: "refused", exitStatus: 128)
    )

    /// A Pull that fetched and then could not fast-forward still fetched, so the app-owned time
    /// is Colofa's to record: the counts on screen are as fresh as a Fetch would have left them.
    @Test
    @MainActor
    func countsARefusedFastForwardAsHavingReachedTheRemote() {
        #expect(PullOutcome.fastForwarded.reachedRemote)
        #expect(PullOutcome.integrationRefused(Self.failure).reachedRemote)
    }

    /// A Pull that never got past the network reached nothing, and one the user stopped is
    /// deliberately treated the same way a stopped Fetch is.
    @Test
    @MainActor
    func countsAFailedOrStoppedNetworkHalfAsHavingReachedNothing() {
        #expect(!PullOutcome.fetchFailed(Self.failure).reachedRemote)
        #expect(!PullOutcome.cancelled.reachedRemote)
    }

    @Test
    @MainActor
    func raisesNoAlertForAPullThatWorkedOrOneTheUserStopped() {
        #expect(!PullOutcome.fastForwarded.needsReporting)
        #expect(!PullOutcome.cancelled.needsReporting)
        #expect(PullOutcome.fetchFailed(Self.failure).needsReporting)
        #expect(PullOutcome.integrationRefused(Self.failure).needsReporting)
    }

    @Test
    @MainActor
    func carriesGitsOwnFailureForBothHalves() {
        #expect(PullOutcome.fetchFailed(Self.failure).error == Self.failure)
        #expect(PullOutcome.integrationRefused(Self.failure).error == Self.failure)
        #expect(PullOutcome.fastForwarded.error == nil)
        #expect(PullOutcome.cancelled.error == nil)
    }
}
