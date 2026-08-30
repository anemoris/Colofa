////
//  PushDestinationIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Where a Push actually lands, against the real Git CLI.
///
/// A remote name is not a destination: Git resolves it when the command runs, out of configuration
/// no confirmation shows. Only real Git can establish what these configurations do, and each one
/// here does something a confirmation reading `origin/main` would have described wrongly.
struct PushDestinationIntegrationTests {

    // MARK: - A remote with more than one push address

    /// The configuration this whole check exists for. One `git push` writes to every configured
    /// push address in turn, so a confirmation naming one destination would name a fraction of
    /// what happens.
    @Test
    @MainActor
    func aremoteWithTwoPushAddressesIsRefusedAndWritesToNeither() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        let mirrorURL = try fixture.createBareRemote(named: "mirror.git")
        try fixture.git(
            ["config", "remote.origin.pushurl", published.remoteURL.path()],
            in: published.cloneURL
        )
        try fixture.git(
            ["config", "--add", "remote.origin.pushurl", mirrorURL.path()],
            in: published.cloneURL
        )
        try commitFile("work", to: "work.txt", in: published.cloneURL, of: fixture)
        let remoteHead = try fixture.git(["rev-parse", "refs/heads/main"], in: published.remoteURL)
        let state = await openedWorkspace(fixture, at: published.cloneURL)

        await state.beginPush()

        #expect(state.pushDialog == nil, "A destination Colofa cannot describe was confirmed")
        #expect(refusal(state) == .severalDestinations(
            remote: "origin",
            [PushDestination(published.remoteURL.path()), PushDestination(mirrorURL.path())]
        ))
        #expect(
            try fixture.git(["rev-parse", "refs/heads/main"], in: published.remoteURL)
                == remoteHead,
            "The refused Push wrote to the first address anyway"
        )
        #expect(
            throws: (any Error).self,
            "The refused Push wrote to the second address anyway"
        ) {
            try fixture.git(["rev-parse", "refs/heads/main"], in: mirrorURL)
        }
    }

    /// The check is about how many addresses there are, not about pushing being unusual: a remote
    /// with one push address that differs from its fetch address still pushes.
    @Test
    @MainActor
    func aremoteWithOnepushAddressStillPushesToThatAddress() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        let mirrorURL = try fixture.createBareRemote(named: "mirror.git")
        try fixture.git(["push", mirrorURL.path(), "main"], in: published.publisherURL)
        try fixture.git(
            ["config", "remote.origin.pushurl", mirrorURL.path()],
            in: published.cloneURL
        )
        let head = try commitFile("work", to: "work.txt", in: published.cloneURL, of: fixture)
        let state = await openedWorkspace(fixture, at: published.cloneURL)

        await state.beginPush()
        #expect(state.pushDialog?.confirmation?.destination == PushDestination(mirrorURL.path()))
        await state.confirmPush()

        #expect(state.repositoryFailure == nil)
        #expect(try fixture.git(["rev-parse", "refs/heads/main"], in: mirrorURL) == head)
    }

    // MARK: - The remote that is this repository

    /// `git branch --track` against a local Branch is an ordinary command, and it configures the
    /// `.` remote. Git then reports that local Branch as this Branch's upstream, so Colofa reaches
    /// Push rather than Publish — and a Push to `.` rewrites a local Branch.
    @Test
    @MainActor
    func abranchTrackingAlocalBranchIsRefusedRatherThanPushedIntoThisRepository() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        let remoteURL = try fixture.createBareRemote()
        try fixture.addRemote(remoteURL, named: "origin", to: repositoryURL)
        try fixture.git(["branch", "localbase"], in: repositoryURL)
        try fixture.git(["checkout", "-b", "feature"], in: repositoryURL)
        try fixture.git(["branch", "--set-upstream-to", "localbase", "feature"], in: repositoryURL)
        let base = try fixture.git(["rev-parse", "refs/heads/localbase"], in: repositoryURL)
        try commitFile("work", to: "work.txt", in: repositoryURL, of: fixture)
        let state = await openedWorkspace(fixture, at: repositoryURL)

        // Git reports the local Branch as an upstream like any other, which is what makes this a
        // Push rather than a Publish.
        #expect(!state.isCurrentBranchUnpublished)
        await state.beginPush()

        #expect(state.pushDialog == nil, "A Push into this repository was confirmed")
        #expect(refusal(state) == .localRepository(remote: "."))
        #expect(
            try fixture.git(["rev-parse", "refs/heads/localbase"], in: repositoryURL) == base,
            "The refused Push rewrote a local branch"
        )
    }

    /// A remote may be called anything and still point at `.`. The name is not what makes the
    /// destination this Repository — the address is — so the check has to be on the address too.
    @Test
    @MainActor
    func aremoteWhoseAddressIsThisRepositoryIsRefusedWhateverItIsCalled() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try fixture.git(["branch", "victim"], in: repositoryURL)
        try fixture.git(["remote", "add", "self", "."], in: repositoryURL)
        try fixture.git(["config", "branch.main.pushRemote", "self"], in: repositoryURL)
        try fixture.git(["config", "branch.main.remote", "self"], in: repositoryURL)
        try fixture.git(["config", "branch.main.merge", "refs/heads/victim"], in: repositoryURL)
        let victim = try fixture.git(["rev-parse", "refs/heads/victim"], in: repositoryURL)
        try commitFile("work", to: "work.txt", in: repositoryURL, of: fixture)
        let state = await openedWorkspace(fixture, at: repositoryURL)

        await state.beginPush()

        #expect(state.pushDialog == nil, "A Push into this repository was confirmed")
        #expect(refusal(state) == .localRepository(remote: "self"))
        #expect(
            try fixture.git(["rev-parse", "refs/heads/victim"], in: repositoryURL) == victim,
            "The refused Push rewrote a local branch"
        )
    }

    // MARK: - The remote moving under an open confirmation

    /// A remote's address is configuration, and configuration can be edited while a dialog is
    /// open. The address is read again immediately before the command runs, so the Ref goes to the
    /// address that was confirmed or to nowhere at all.
    @Test
    @MainActor
    func aremoteReboundWhileTheConfirmationWasOpenSendsNothing() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        let elsewhereURL = try fixture.createBareRemote(named: "elsewhere.git")
        try commitFile("work", to: "work.txt", in: published.cloneURL, of: fixture)
        let state = await openedWorkspace(fixture, at: published.cloneURL)

        await state.beginPush()
        #expect(state.isConfirmingPush)
        // What another process — or the user in a terminal — can do while the sheet is up.
        try fixture.git(
            ["remote", "set-url", "--push", "origin", elsewhereURL.path()],
            in: published.cloneURL
        )
        await state.confirmPush()

        #expect(state.pushDialog == nil)
        #expect(refusal(state) == .changed(remote: "origin"))
        #expect(
            throws: (any Error).self,
            "The Push reached an address the confirmation never showed"
        ) {
            try fixture.git(["rev-parse", "refs/heads/main"], in: elsewhereURL)
        }
    }

    // MARK: - Fixtures

    /// The destination Colofa refused, or `nil` when it refused nothing.
    @MainActor
    private func refusal(_ state: WorkspaceState) -> PushDestinationRefusal? {
        guard case .pushDestinationAlert(let refusal) = state.repositoryFailure else {
            return nil
        }
        return refusal
    }
}
