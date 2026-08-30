////
//  PushForceIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Force Push with Lease against the real Git CLI and a local bare remote, which is the only
/// thing that can prove the lease actually protects the remote — including in the race it exists
/// for, where somebody else pushes between the confirmation and its button.
struct PushForceIntegrationTests {

    /// A deliberate rewrite is accepted while the remote still holds what the confirmation saw.
    @Test
    @MainActor
    func forcePushWithLeaseReplacesTheUpstreamWhenTheRemoteHasNotMoved() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try fixture.git(["commit", "--amend", "-m", "Rewritten"], in: published.cloneURL)
        let rewritten = try fixture.git(["rev-parse", "HEAD"], in: published.cloneURL)
        let state = await openedWorkspace(fixture, at: published.cloneURL)

        await state.beginPush()
        state.pushDialog?.confirmation?.forcesWithLease = true
        await state.confirmPush()

        #expect(state.repositoryFailure == nil)
        #expect(
            try fixture.git(["rev-parse", "refs/heads/main"], in: published.remoteURL) == rewritten
        )
    }

    /// The race the lease exists for: the remote moves after the confirmation is open, and the
    /// Force Push refuses rather than discarding work nobody had seen.
    @Test
    @MainActor
    func aremoteThatMovesAfterConfirmationRefusesTheLeaseAndKeepsTheNewerWork() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try fixture.git(["commit", "--amend", "-m", "Rewritten"], in: published.cloneURL)
        let state = await openedWorkspace(fixture, at: published.cloneURL)

        // The lease is taken here, against the remote as it stands right now.
        await state.beginPush()
        state.pushDialog?.confirmation?.forcesWithLease = true

        // Somebody else pushes in the window between the confirmation and its button.
        let newerHead = try commitFile(
            "newer\n",
            to: "newer.txt",
            in: published.publisherURL,
            of: fixture
        )
        try fixture.git(["push", "origin", "main"], in: published.publisherURL)

        await state.confirmPush()

        guard case .pushRejectedAlert(let rejection, _, _, _) = state.repositoryFailure else {
            Issue.record("A refused lease was not reported as one")
            return
        }
        #expect(rejection == .staleLease)
        #expect(
            try fixture.git(["rev-parse", "refs/heads/main"], in: published.remoteURL) == newerHead,
            "The lease let a Force Push overwrite work it had never seen"
        )
    }

    /// The lease is the exact object the remote-tracking Ref held, so the command Colofa runs is
    /// refused by Git itself once it no longer matches — there is no spelling of force here that
    /// would not have been.
    @Test
    @MainActor
    func theLeaseNamesTheExactObjectTheRemoteMustStillHold() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        let state = await openedWorkspace(fixture, at: published.cloneURL)

        await state.beginPush()

        let confirmation = try #require(state.pushDialog?.confirmation)
        let observed = try fixture.git(
            ["rev-parse", "refs/remotes/origin/main"],
            in: published.cloneURL
        )
        #expect(confirmation.target.expectedObjectID == observed)

        var forcing = confirmation
        forcing.forcesWithLease = true
        #expect(forcing.arguments.contains("--force-with-lease=refs/heads/main:\(observed)"))
        #expect(!forcing.arguments.contains("--force"))
    }
}
