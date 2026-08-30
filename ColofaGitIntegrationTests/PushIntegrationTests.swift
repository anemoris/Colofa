////
//  PushIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Publish and Push against the real Git CLI and local bare remotes, which is the only thing that
/// can prove where a Branch actually goes, that a lease actually protects the remote, and that no
/// configuration turns an ordinary Push into something else.
struct PushIntegrationTests {

    // MARK: - Publish

    /// The whole point of Publish: the Branch exists on the remote afterwards, and the local
    /// Branch tracks it.
    @Test
    @MainActor
    func publishCreatesTheRemoteBranchAndEstablishesItAsTheUpstream() async throws {
        let fixture = try GitTestRepository()
        let remoteURL = try fixture.createBareRemote()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try fixture.addRemote(remoteURL, named: "origin", to: repositoryURL)
        let state = await openedWorkspace(fixture, at: repositoryURL)
        #expect(state.isCurrentBranchUnpublished)

        await state.beginPush()

        #expect(state.repositoryFailure == nil)
        #expect(state.pushDialog == nil, "A sole remote was asked about anyway")
        #expect(state.repository?.upstream?.name == "origin/main")
        #expect(!state.isCurrentBranchUnpublished)
        #expect(
            try fixture.git(["rev-parse", "refs/heads/main"], in: remoteURL)
                == fixture.git(["rev-parse", "HEAD"], in: repositoryURL)
        )
        #expect(
            try fixture.git(["config", "branch.main.merge"], in: repositoryURL)
                == "refs/heads/main"
        )
    }

    /// Git's own configuration decides where a Branch is published, and the most specific key
    /// wins — which is what Colofa asks in order rather than reproducing.
    @Test
    @MainActor
    func publishHonorsBranchSpecificPushConfigurationOverTheDefaultOne() async throws {
        let fixture = try GitTestRepository()
        let published = try twoRemoteRepository(fixture)
        try fixture.git(["config", "remote.pushDefault", "origin"], in: published.repositoryURL)
        try fixture.git(
            ["config", "branch.main.pushRemote", "mirror"],
            in: published.repositoryURL
        )
        let state = await openedWorkspace(fixture, at: published.repositoryURL)

        await state.beginPush()

        #expect(state.repositoryFailure == nil)
        #expect(state.pushDialog == nil, "Configured push remotes were asked about anyway")
        #expect(state.repository?.upstream?.name == "mirror/main")
        #expect(try !fixture.git(["rev-parse", "refs/heads/main"], in: published.mirrorURL).isEmpty)
        #expect(
            throws: (any Error).self,
            "The Branch was published to a remote the configuration did not name"
        ) {
            try fixture.git(["rev-parse", "refs/heads/main"], in: published.originURL)
        }
    }

    /// With nothing configured for the Branch itself, the default push remote is the answer.
    @Test
    @MainActor
    func publishHonorsTheDefaultPushRemote() async throws {
        let fixture = try GitTestRepository()
        let published = try twoRemoteRepository(fixture)
        try fixture.git(["config", "remote.pushDefault", "mirror"], in: published.repositoryURL)
        let state = await openedWorkspace(fixture, at: published.repositoryURL)

        await state.beginPush()

        #expect(state.repositoryFailure == nil)
        #expect(state.repository?.upstream?.name == "mirror/main")
    }

    /// Several remotes and no configuration is the one genuinely ambiguous case, and Colofa asks
    /// rather than guessing — publishing nothing until the dialog's own button is pressed.
    @Test
    @MainActor
    func publishAsksAmongSeveralRemotesWithOriginPreselected() async throws {
        let fixture = try GitTestRepository()
        let published = try twoRemoteRepository(fixture)
        let state = await openedWorkspace(fixture, at: published.repositoryURL)

        await state.beginPush()

        #expect(state.isChoosingPublishRemote)
        #expect(state.pushDialog?.publishRemote?.selectedRemote == "origin")
        #expect(state.repository?.upstream == nil, "The dialog published on its own")

        state.pushDialog?.publishRemote?.selectedRemote = "mirror"
        await state.confirmPublishRemote()

        #expect(state.repositoryFailure == nil)
        #expect(state.repository?.upstream?.name == "mirror/main")
    }

    // MARK: - Push

    /// A Push sends the Branch to the exact upstream and leaves the two ends at the same Commit.
    @Test
    @MainActor
    func pushSendsLocalCommitsToTheUpstream() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        let head = try commitFile("local\n", to: "local.txt", in: published.cloneURL, of: fixture)
        let state = await openedWorkspace(fixture, at: published.cloneURL)
        #expect(state.repository?.upstream?.ahead == 1)

        await state.beginPush()
        #expect(state.pushDialog?.confirmation?.target.upstream == "origin/main")
        await state.confirmPush()

        #expect(state.repositoryFailure == nil)
        #expect(state.repository?.upstream?.ahead == 0)
        #expect(try fixture.git(["rev-parse", "refs/heads/main"], in: published.remoteURL) == head)
    }

    /// The confirmation shows exactly where the Push goes, read from Git rather than split out of
    /// a short name — which is what makes a remote whose name contains a slash still correct.
    @Test
    @MainActor
    func theConfirmationReportsTheRemoteAndRefGitItselfResolved() async throws {
        let fixture = try GitTestRepository()
        let remoteURL = try fixture.createBareRemote()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try fixture.addRemote(remoteURL, named: "team/mirror", to: repositoryURL)
        try fixture.git(["push", "-u", "team/mirror", "main"], in: repositoryURL)
        let state = await openedWorkspace(fixture, at: repositoryURL)

        await state.beginPush()

        let target = try #require(state.pushDialog?.confirmation?.target)
        #expect(target.remote == "team/mirror")
        #expect(target.remoteRef == "refs/heads/main")
        #expect(target.upstream == "team/mirror/main")
        #expect(target.trackingRef == "refs/remotes/team/mirror/main")
        #expect(target.expectedObjectID == (try fixture.git(["rev-parse", "HEAD"], in: repositoryURL)))
    }

    /// Colofa never creates or pushes a tag, so a Repository configured to send them along is
    /// overruled rather than inherited.
    @Test
    @MainActor
    func pushNeverSendsAtagEvenWhereGitIsConfiguredTo() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try fixture.git(["config", "push.followTags", "true"], in: published.cloneURL)
        try commitFile("local\n", to: "local.txt", in: published.cloneURL, of: fixture)
        try fixture.git(["tag", "-a", "v9.9", "-m", "Annotated"], in: published.cloneURL)
        let state = await openedWorkspace(fixture, at: published.cloneURL)

        await state.beginPush()
        await state.confirmPush()

        #expect(state.repositoryFailure == nil)
        #expect(
            try fixture.git(["tag", "--list"], in: published.remoteURL).isEmpty,
            "The Push published a tag"
        )
    }

    // MARK: - Push Rejected

    /// An upstream holding work this Branch does not is a refusal the user acts on by integrating
    /// first, and it is told apart from a connection that never got there.
    @Test
    @MainActor
    func anupstreamThatMovedOnRejectsThePushWithoutChangingTheRemote() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        let remoteHead = try commitFile(
            "upstream\n",
            to: "upstream.txt",
            in: published.publisherURL,
            of: fixture
        )
        try fixture.git(["push", "origin", "main"], in: published.publisherURL)
        try commitFile("local\n", to: "local.txt", in: published.cloneURL, of: fixture)
        let state = await openedWorkspace(fixture, at: published.cloneURL)

        await state.beginPush()
        await state.confirmPush()

        guard case .pushRejectedAlert(let rejection, _, let upstream, _) = state.repositoryFailure else {
            Issue.record("A refused Push was not reported as one")
            return
        }
        #expect(rejection == .nonFastForward)
        #expect(upstream == "origin/main")
        #expect(
            try fixture.git(["rev-parse", "refs/heads/main"], in: published.remoteURL) == remoteHead,
            "The refused Push changed the remote anyway"
        )
        let message = englishFailureMessage(state)
        #expect(message?.localizedStandardContains("force") == false)
    }

    // MARK: - Refusing before the command

    @Test
    @MainActor
    func detachedHeadCanNeitherPublishNorPush() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        let head = try fixture.git(["rev-parse", "HEAD"], in: published.cloneURL)
        try fixture.git(["checkout", "--detach", head], in: published.cloneURL)
        let state = await openedWorkspace(fixture, at: published.cloneURL)

        #expect(!state.canPush)
        #expect(state.pushUnavailabilityReason == .detachedHead)
    }

    @Test
    @MainActor
    func anunbornBranchHasNothingToPublish() async throws {
        let fixture = try GitTestRepository()
        let remoteURL = try fixture.createBareRemote()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.addRemote(remoteURL, named: "origin", to: repositoryURL)
        let state = await openedWorkspace(fixture, at: repositoryURL)

        #expect(!state.canPush)
        #expect(state.pushUnavailabilityReason == .unbornBranch)
    }

    // MARK: - Fixtures

    /// A repository with one Commit and two remotes, and nothing published to either of them.
    private func twoRemoteRepository(
        _ fixture: GitTestRepository
    ) throws -> TwoRemoteRepository {
        let originURL = try fixture.createBareRemote(named: "origin.git")
        let mirrorURL = try fixture.createBareRemote(named: "mirror.git")
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try fixture.addRemote(originURL, named: "origin", to: repositoryURL)
        try fixture.addRemote(mirrorURL, named: "mirror", to: repositoryURL)
        return TwoRemoteRepository(
            repositoryURL: repositoryURL,
            originURL: originURL,
            mirrorURL: mirrorURL
        )
    }

    /// The failure on screen, read in the language these assertions are written in rather than in
    /// whatever language the machine running them is set to.
    @MainActor
    private func englishFailureMessage(_ state: WorkspaceState) -> String? {
        guard var message = state.repositoryFailureMessage else {
            return nil
        }
        message.locale = Locale(identifier: "en")
        return String(localized: message)
    }
}

/// A working repository with two remotes it could publish to, which is what makes the destination
/// a question rather than an answer.
private struct TwoRemoteRepository {
    let repositoryURL: URL
    let originURL: URL
    let mirrorURL: URL
}
