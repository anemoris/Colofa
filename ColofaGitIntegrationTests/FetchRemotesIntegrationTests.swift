////
//  FetchRemotesIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Fetch Remotes against the real Git CLI and local bare remotes, which is the only thing that
/// can prove what it removes and — far more importantly — what it does not.
struct FetchRemotesIntegrationTests {

    // MARK: - What it reconciles

    /// The whole point: a Branch deleted on the remote stops being a remote-tracking Branch here,
    /// and the Repository is read back rather than assumed.
    @Test
    @MainActor
    func removesTheRemoteTrackingBranchesTheRemoteNoLongerHas() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try publishBranch("gone", in: published, of: fixture)
        try fixture.git(["fetch", "origin"], in: published.cloneURL)
        try fixture.git(["push", "origin", "--delete", "gone"], in: published.publisherURL)

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        #expect(state.repository?.remoteBranches.contains("origin/gone") == true)

        await state.fetchRemotes()

        #expect(state.repository?.remoteBranches == ["origin/main"])
        #expect(state.repositoryFailure == nil)
        #expect(state.lastFetchDate != nil)
    }

    /// It is a Fetch as well as a reconciliation, so what the remote gained arrives in the same
    /// command that removes what it lost.
    @Test
    @MainActor
    func downloadsWhatTheRemoteGained() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try commitFile("later\n", to: "later.txt", in: published.publisherURL, of: fixture)
        try fixture.git(["push", "origin", "main"], in: published.publisherURL)

        let state = await openedWorkspace(fixture, at: published.cloneURL)

        await state.fetchRemotes()

        #expect(state.repository?.upstream?.behind == 1)
        #expect(
            !FileManager.default.fileExists(
                atPath: published.cloneURL.appending(path: "later.txt").normalizedFilePath
            ),
            "Fetch Remotes changed the working tree"
        )
    }

    // MARK: - What it must never remove

    /// `--prune` removes whatever the refspecs in force cover, so a Repository that maps the
    /// remote's tags into `refs/tags/*` would lose local tags to a plain `--prune` — and
    /// `--no-prune-tags` does not stop that, because it refuses only the refspec Git adds
    /// implicitly. Naming the branch refspec on the command line is what bounds the removal, and
    /// this is the test that proves it under exactly that configuration.
    @Test
    @MainActor
    func keepsLocalTagsUnderARepositoryConfiguredToPruneThem() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try publishBranch("gone", in: published, of: fixture)
        try fixture.git(["tag", "shared"], in: published.publisherURL)
        try fixture.git(["push", "origin", "shared"], in: published.publisherURL)
        try fixture.git(["fetch", "origin"], in: published.cloneURL)
        try fixture.git(["tag", "local-only"], in: published.cloneURL)
        try fixture.git(
            ["config", "--add", "remote.origin.fetch", "+refs/tags/*:refs/tags/*"],
            in: published.cloneURL
        )
        for key in ["fetch.prune", "fetch.pruneTags", "remote.origin.pruneTags"] {
            try fixture.git(["config", key, "true"], in: published.cloneURL)
        }
        try fixture.git(["push", "origin", "--delete", "gone"], in: published.publisherURL)
        try fixture.git(["push", "origin", "--delete", "shared"], in: published.publisherURL)

        let state = await openedWorkspace(fixture, at: published.cloneURL)

        await state.fetchRemotes()

        #expect(state.repository?.remoteBranches == ["origin/main"])
        #expect(state.repository?.tags == ["local-only", "shared"])
    }

    /// A tag the remote has moved is not force-updated either. No tag refspec is in force, so
    /// there is nothing that could write one, and the local object stays where it was.
    @Test
    @MainActor
    func forceUpdatesNoLocalTag() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try fixture.git(["tag", "v1.0"], in: published.publisherURL)
        try fixture.git(["push", "origin", "v1.0"], in: published.publisherURL)
        try fixture.git(["fetch", "origin", "--tags"], in: published.cloneURL)
        let original = try fixture.git(["rev-parse", "v1.0^{}"], in: published.cloneURL)
        try commitFile("moved\n", to: "moved.txt", in: published.publisherURL, of: fixture)
        try fixture.git(["tag", "--force", "v1.0"], in: published.publisherURL)
        try fixture.git(["push", "origin", "--force", "v1.0"], in: published.publisherURL)
        try fixture.git(
            ["config", "--add", "remote.origin.fetch", "+refs/tags/*:refs/tags/*"],
            in: published.cloneURL
        )

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        await state.fetchRemotes()

        #expect(state.repository?.tags == ["v1.0"])
        #expect(try fixture.git(["rev-parse", "v1.0^{}"], in: published.cloneURL) == original)
    }

    /// Nothing here reaches the remote's own refs. Deleting a Branch on a server is not what this
    /// command is, and no configuration turns it into that.
    @Test
    @MainActor
    func deletesNoBranchOnTheRemote() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try publishBranch("kept", in: published, of: fixture)

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        await state.fetchRemotes()

        let heads = try fixture.git(["ls-remote", "--heads", "origin"], in: published.cloneURL)
        #expect(heads.contains("refs/heads/kept"))
        #expect(heads.contains("refs/heads/main"))
    }

    /// A local Branch is the user's, and losing the ref it tracked is no reason to touch it: the
    /// Branch stays, and so does the upstream configuration that names where it belonged.
    @Test
    @MainActor
    func deletesNoLocalBranchAndKeepsItsUpstreamConfiguration() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try publishBranch("feature", in: published, of: fixture)
        try fixture.git(["fetch", "origin"], in: published.cloneURL)
        try fixture.git(["switch", "feature"], in: published.cloneURL)
        try fixture.git(["push", "origin", "--delete", "feature"], in: published.publisherURL)

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        await state.fetchRemotes()

        #expect(state.repository?.localBranches.contains("feature") == true)
        #expect(
            try fixture.git(["config", "--get", "branch.feature.merge"], in: published.cloneURL)
                == "refs/heads/feature"
        )
    }

    // MARK: - A Branch whose upstream is gone

    /// Git stops counting once the ref it counted against is gone. Colofa has to report that as
    /// what it is rather than as a Branch level with something that no longer exists.
    @Test
    @MainActor
    func reportsAbranchWhoseUpstreamWasPrunedAsGoneRatherThanLevel() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try publishBranch("feature", in: published, of: fixture)
        try fixture.git(["fetch", "origin"], in: published.cloneURL)
        try fixture.git(["switch", "feature"], in: published.cloneURL)
        try fixture.git(["push", "origin", "--delete", "feature"], in: published.publisherURL)

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        #expect(state.repository?.upstream?.position == .counted(ahead: 0, behind: 0))

        await state.fetchRemotes()

        let upstream = try #require(state.repository?.upstream)
        #expect(upstream.name == "origin/feature")
        #expect(upstream.position == .gone)
        #expect(upstream.ahead == nil)
        #expect(upstream.behind == nil)
    }

    // MARK: - The ordinary Fetch is untouched

    /// This action adds a way to ask; it does not change what Fetch does. A Repository that never
    /// asked Git to prune still keeps its stale refs after an ordinary Fetch.
    @Test
    @MainActor
    func leavesTheOrdinaryFetchKeepingStaleRefs() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try publishBranch("gone", in: published, of: fixture)
        try fixture.git(["fetch", "origin"], in: published.cloneURL)
        try fixture.git(["push", "origin", "--delete", "gone"], in: published.publisherURL)

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        await state.fetch()

        #expect(state.repository?.remoteBranches.contains("origin/gone") == true)
    }

    // MARK: - Partial failure

    /// One remote failing says nothing about the next: the failing one is named, and the refs the
    /// other one already reconciled stay reconciled.
    @Test
    @MainActor
    func namesTheFailingRemoteAndKeepsWhatTheOthersReconciled() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try publishBranch("gone", in: published, of: fixture)
        try fixture.git(["fetch", "origin"], in: published.cloneURL)
        try fixture.git(["push", "origin", "--delete", "gone"], in: published.publisherURL)
        // Sorted after `origin`, so the reconciliation origin achieved has to survive it.
        try fixture.addRemote(
            fixture.rootURL.appending(path: "missing.git", directoryHint: .isDirectory),
            named: "zz-broken",
            to: published.cloneURL
        )

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        await state.fetchRemotes()

        let message = String(localized: try #require(state.repositoryFailureMessage))
        #expect(message.contains("zz-broken"))
        #expect(state.repository?.remoteBranches == ["origin/main"])
        #expect(state.lastFetchDate == nil)
    }

    // MARK: - Fixture

    /// Publishes one Branch of its own to the shared remote and returns the publisher to `main`,
    /// which is the state every case here starts from.
    private func publishBranch(
        _ name: String,
        in published: PublishedRepository,
        of fixture: GitTestRepository
    ) throws {
        try fixture.git(["switch", "--create", name], in: published.publisherURL)
        try commitFile("\(name)\n", to: "\(name).txt", in: published.publisherURL, of: fixture)
        try fixture.git(["push", "origin", name], in: published.publisherURL)
        try fixture.git(["switch", "main"], in: published.publisherURL)
    }
}
