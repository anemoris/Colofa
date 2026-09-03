////
//  FetchIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Fetch and Fetch Tags against the real Git CLI and local bare remotes, which is the only thing
/// that can prove Colofa preserves the fetch policy the user already configured.
struct FetchIntegrationTests {
    private static let gitURL = URL(filePath: "/usr/bin/git")

    private func backend(_ fixture: GitTestRepository) -> GitRepositoryService {
        GitRepositoryService(
            candidateURLs: [Self.gitURL],
            environment: fixture.environment
        )
    }

    // MARK: - Fetch

    /// The whole point of Fetch: remote-tracking refs, the ahead/behind counts read from them,
    /// and the app-owned time all move, without the working tree being touched.
    @Test
    @MainActor
    func fetchRefreshesRemoteTrackingRefsAndAheadBehindCounts() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        let state = await openedWorkspace(fixture, at: published.cloneURL)
        #expect(state.repository?.upstream?.behind == 0)

        try commitFile("later\n", to: "later.txt", in: published.publisherURL, of: fixture)
        try fixture.git(["push", "origin", "main"], in: published.publisherURL)

        await state.fetch()

        #expect(state.repository?.upstream?.behind == 1)
        #expect(state.repository?.upstream?.ahead == 0)
        #expect(state.repositoryFailure == nil)
        #expect(state.lastFetchDate != nil)
        #expect(
            !FileManager.default.fileExists(
                atPath: published.cloneURL.appending(path: "later.txt").normalizedFilePath
            ),
            "Fetch changed the working tree"
        )
    }

    /// Git's own boolean rules decide what "skip" means, so Colofa asks Git for the canonical
    /// value rather than reading the configuration file itself.
    @Test(arguments: [("true", true), ("yes", true), ("1", true), ("false", false), ("off", false)])
    func readsGitsOwnBooleanForSkipFetchAll(_ value: String, _ isSkipped: Bool) async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try fixture.git(["config", "remote.mirror.skipFetchAll", value], in: repositoryURL)

        let skipped = try await backend(fixture).loadSkippedRemotes(in: repositoryURL)

        #expect(skipped == (isSkipped ? ["mirror"] : []))
    }

    /// A key present without a value is `true` to Git, and has to be `true` to Colofa too.
    @Test
    func readsAvaluelessSkipFetchAllKeyAsSkipped() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try Data("[remote \"mirror\"]\n\tskipFetchAll\n".utf8)
            .write(to: repositoryURL.appending(path: ".git/config"))

        let skipped = try await backend(fixture).loadSkippedRemotes(in: repositoryURL)

        #expect(skipped == ["mirror"])
    }

    /// Git reads the key from every scope and obeys the last one it read, so a Repository that
    /// turns a globally skipped remote back on is a remote Git fetches — and one Colofa has to
    /// fetch too.
    @Test
    func readsARepositoryValueThatOverridesAglobalSkipFetchAll() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try fixture.git(["config", "--global", "remote.mirror.skipFetchAll", "true"])
        try fixture.git(["config", "remote.mirror.skipFetchAll", "false"], in: repositoryURL)

        let skipped = try await backend(fixture).loadSkippedRemotes(in: repositoryURL)

        #expect(
            skipped.isEmpty,
            "Colofa skipped a remote Git's own effective value says to fetch"
        )
    }

    /// And the other way round, so what Colofa follows is Git's ordering rather than a
    /// preference for one value over the other.
    @Test
    func readsARepositoryValueThatSkipsAremoteAllowedGlobally() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try fixture.git(["config", "--global", "remote.mirror.skipFetchAll", "false"])
        try fixture.git(["config", "remote.mirror.skipFetchAll", "true"], in: repositoryURL)

        #expect(try await backend(fixture).loadSkippedRemotes(in: repositoryURL) == ["mirror"])
    }

    @Test
    func readsNoSkippedRemotesFromARepositoryThatConfiguresNone() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)

        #expect(try await backend(fixture).loadSkippedRemotes(in: repositoryURL).isEmpty)
    }

    /// A remote Git excludes from a Fetch of all remotes is never contacted, so its
    /// remote-tracking refs stay exactly where they were.
    @Test
    @MainActor
    func neverContactsAremoteGitExcludesFromAFetchOfAllOfThem() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        let mirrorURL = try fixture.createBareRemote(named: "mirror.git")
        try fixture.addRemote(mirrorURL, named: "mirror", to: published.publisherURL)
        try fixture.git(["push", "mirror", "main"], in: published.publisherURL)
        try fixture.addRemote(mirrorURL, named: "mirror", to: published.cloneURL)
        try fixture.git(
            ["config", "remote.mirror.skipFetchAll", "true"],
            in: published.cloneURL
        )

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        await state.fetch()

        #expect(state.repository?.remoteBranches == ["origin/main"])
        #expect(state.repositoryFailure == nil)
    }

    /// The remote's own refspec decides which branches arrive, so a narrowed one still narrows.
    @Test
    @MainActor
    func preservesAremotesConfiguredRefspec() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try fixture.git(
            [
                "config", "remote.origin.fetch",
                "+refs/heads/main:refs/remotes/origin/main",
            ],
            in: published.cloneURL
        )
        try fixture.git(["switch", "--create", "extra"], in: published.publisherURL)
        try commitFile("extra\n", to: "extra.txt", in: published.publisherURL, of: fixture)
        try fixture.git(["push", "origin", "extra"], in: published.publisherURL)

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        await state.fetch()

        #expect(state.repository?.remoteBranches == ["origin/main"])
    }

    /// A remote configured to prune still prunes, because Colofa adds no option that would stop
    /// Git from doing what it was told to do.
    @Test
    @MainActor
    func preservesAremotesConfiguredPruneBehavior() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try fixture.git(["switch", "--create", "gone"], in: published.publisherURL)
        try commitFile("gone\n", to: "gone.txt", in: published.publisherURL, of: fixture)
        try fixture.git(["push", "origin", "gone"], in: published.publisherURL)
        try fixture.git(["fetch", "origin"], in: published.cloneURL)
        try fixture.git(["config", "remote.origin.prune", "true"], in: published.cloneURL)
        try fixture.git(["push", "origin", "--delete", "gone"], in: published.publisherURL)

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        #expect(state.repository?.remoteBranches.contains("origin/gone") == true)

        await state.fetch()

        #expect(state.repository?.remoteBranches == ["origin/main"])
    }

    /// A remote configured to bring no tags still brings none, so an ordinary Fetch never turns
    /// into the explicit tag download Fetch Tags is.
    @Test
    @MainActor
    func preservesAremotesConfiguredTagBehavior() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try fixture.git(["config", "remote.origin.tagOpt", "--no-tags"], in: published.cloneURL)
        try fixture.git(["tag", "v1.0"], in: published.publisherURL)
        try fixture.git(["push", "origin", "v1.0"], in: published.publisherURL)

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        await state.fetch()

        #expect(state.repository?.tags.isEmpty == true)
    }

    /// A hook the Repository configures still runs, because Colofa adds no option that would
    /// bypass one.
    @Test
    @MainActor
    func preservesTheHooksTheRepositoryConfigures() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        let evidenceURL = fixture.rootURL.appending(path: "hook-ran")
        try writeHook(
            "reference-transaction",
            in: published.cloneURL,
            script: "echo ran >> \"\(evidenceURL.normalizedFilePath)\""
        )
        try commitFile("later\n", to: "later.txt", in: published.publisherURL, of: fixture)
        try fixture.git(["push", "origin", "main"], in: published.publisherURL)

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        await state.fetch()

        #expect(state.repositoryFailure == nil)
        #expect(
            FileManager.default.fileExists(atPath: evidenceURL.normalizedFilePath),
            "The Repository's own hook did not run during the Fetch"
        )
    }

    /// One remote failing says nothing about the next: the failing one is named, the one that
    /// answered stays refreshed, and the last-Fetch time records that a remote was contacted.
    @Test
    @MainActor
    func namesTheFailingRemoteAndKeepsTheRefsTheOtherOneRefreshed() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        // Sorted before `origin`, so the Fetch has to carry on after it fails.
        try fixture.addRemote(
            fixture.rootURL.appending(path: "missing.git", directoryHint: .isDirectory),
            named: "broken",
            to: published.cloneURL
        )
        try commitFile("later\n", to: "later.txt", in: published.publisherURL, of: fixture)
        try fixture.git(["push", "origin", "main"], in: published.publisherURL)

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        await state.fetch()

        let message = String(localized: try #require(state.repositoryFailureMessage))
        #expect(message.contains("broken"))
        #expect(state.repository?.upstream?.behind == 1)
        #expect(state.lastFetchDate != nil)
    }

    // MARK: - Cancellation

    /// Cancelling a Fetch has to end Git rather than let a network command run to completion with
    /// nobody waiting for it.
    ///
    /// The command is a controlled blocking one rather than real Git: it reports that it is
    /// running and then blocks, so cancellation arrives at a command known to be running and how
    /// long the answer takes is a fact about cancellation rather than about the network.
    @Test
    func cancellingAFetchEndsGitInsteadOfWaitingItOut() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        let blockingGitURL = fixture.rootURL.appending(path: "blocking-git")
        let readyURL = fixture.rootURL.appending(path: "blocking-git-ready")
        // Far longer than the assertion below allows, so waiting it out cannot pass.
        try fixture.createBlockingGit(at: blockingGitURL, seconds: 30, readyURL: readyURL)

        let backend = GitRepositoryService(
            candidateURLs: [blockingGitURL],
            environment: fixture.environment
        )
        let fetching = Task {
            try await backend.runNetworkMutation(
                FetchCommand.fetch("origin"),
                in: repositoryURL,
                responder: .refusing
            )
        }
        try await fixture.waitForReadySignal(at: readyURL)
        fetching.cancel()

        let started = ContinuousClock.now
        let result = await fetching.result
        let elapsed = started.duration(to: .now)

        #expect(throws: CancellationError.self) { try result.get() }
        #expect(elapsed < .seconds(5), "A cancelled Fetch took \(elapsed) to come back")
    }
}
