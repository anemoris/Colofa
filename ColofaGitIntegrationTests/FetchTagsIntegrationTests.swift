////
//  FetchTagsIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Fetch Tags against the real Git CLI and a local bare remote, which is the only thing that can
/// prove an explicit tag download adds tags without replacing or removing one.
struct FetchTagsIntegrationTests {
    private static let gitURL = URL(filePath: "/usr/bin/git")

    private func backend(_ fixture: GitTestRepository) -> GitRepositoryService {
        GitRepositoryService(
            candidateURLs: [Self.gitURL],
            environment: fixture.environment
        )
    }

    /// Every tag arrives, and a local tag of the same name is neither replaced nor removed.
    @Test
    @MainActor
    func fetchTagsAddsTagsWithoutReplacingOrPruningLocalOnes() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        let localOnly = try fixture.git(["rev-parse", "HEAD"], in: published.cloneURL)
        try fixture.git(["tag", "shared"], in: published.cloneURL)
        try fixture.git(["tag", "local-only"], in: published.cloneURL)
        try commitFile("later\n", to: "later.txt", in: published.publisherURL, of: fixture)
        try fixture.git(["tag", "shared"], in: published.publisherURL)
        try fixture.git(["tag", "remote-only"], in: published.publisherURL)
        try fixture.git(["push", "origin", "main", "--tags"], in: published.publisherURL)

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        await state.fetchTags()

        #expect(state.repository?.tags == ["local-only", "remote-only", "shared"])
        #expect(
            try fixture.git(["rev-parse", "shared"], in: published.cloneURL) == localOnly,
            "Fetch Tags replaced a local tag"
        )
        let message = String(localized: try #require(state.repositoryFailureMessage))
        #expect(message.contains("shared"))
    }

    /// The refusal names the tags Git kept, which Colofa reads from Git rather than from Git's
    /// message text.
    @Test
    func readsWhichLocalTagsARemoteDisagreesAbout() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try fixture.git(["tag", "shared"], in: published.cloneURL)
        try fixture.git(["tag", "local-only"], in: published.cloneURL)
        try commitFile("later\n", to: "later.txt", in: published.publisherURL, of: fixture)
        try fixture.git(["tag", "shared"], in: published.publisherURL)
        try fixture.git(["tag", "agreed"], in: published.publisherURL)
        try fixture.git(["push", "origin", "main", "--tags"], in: published.publisherURL)

        let conflict = try await backend(fixture).loadTagConflicts(
            TagConflictRequest(repositoryURL: published.cloneURL, remote: "origin")
        )

        #expect(conflict.tags == ["shared"])
    }

    /// An annotated tag is compared as the tag object it is, so agreeing sides are not read as a
    /// conflict just because one side is annotated.
    @Test
    func readsAnAnnotatedTagBothSidesAgreeAboutAsNoConflict() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try fixture.git(
            ["tag", "--annotate", "--message", "release", "v1.0"],
            in: published.publisherURL
        )
        try fixture.git(["push", "origin", "v1.0"], in: published.publisherURL)
        try fixture.git(["fetch", "origin", "--tags"], in: published.cloneURL)

        let conflict = try await backend(fixture).loadTagConflicts(
            TagConflictRequest(repositoryURL: published.cloneURL, remote: "origin")
        )

        #expect(conflict.isEmpty)
    }

    /// A Repository configured to prune tags would have had its local-only tag deleted by a
    /// plain `git fetch --tags`. Fetch Tags may add tags and nothing else, so the configuration
    /// is refused rather than inherited.
    @Test
    @MainActor
    func fetchTagsKeepsAlocalOnlyTagInArepositoryConfiguredToPruneTags() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try fixture.git(["config", "fetch.prune", "true"], in: published.cloneURL)
        try fixture.git(["config", "fetch.pruneTags", "true"], in: published.cloneURL)
        try fixture.git(["tag", "local-only"], in: published.cloneURL)
        try fixture.git(["tag", "remote-only"], in: published.publisherURL)
        try fixture.git(["push", "origin", "remote-only"], in: published.publisherURL)

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        await state.fetchTags()

        #expect(
            state.repository?.tags == ["local-only", "remote-only"],
            "Fetch Tags pruned a local tag"
        )
        #expect(state.repositoryFailure == nil)
    }

    /// A remote whose own refspec force-updates tags would have replaced a local tag through a
    /// plain `git fetch --tags`. Naming the refspec on the command line is what stops it.
    @Test
    @MainActor
    func fetchTagsKeepsAlocalTagInArepositoryWhoseRefspecForcesTags() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try fixture.git(
            ["config", "--add", "remote.origin.fetch", "+refs/tags/*:refs/tags/*"],
            in: published.cloneURL
        )
        try fixture.git(["tag", "shared"], in: published.cloneURL)
        let kept = try fixture.git(["rev-parse", "shared"], in: published.cloneURL)
        try commitFile("later\n", to: "later.txt", in: published.publisherURL, of: fixture)
        try fixture.git(["tag", "shared"], in: published.publisherURL)
        try fixture.git(["push", "origin", "main", "--tags"], in: published.publisherURL)

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        await state.fetchTags()

        #expect(
            try fixture.git(["rev-parse", "shared"], in: published.cloneURL) == kept,
            "A configured force refspec replaced a local tag"
        )
        let message = String(localized: try #require(state.repositoryFailureMessage))
        #expect(message.contains("shared"))
    }

    @Test
    @MainActor
    func fetchTagsSucceedsQuietlyWhenNothingConflicts() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try fixture.git(["tag", "v1.0"], in: published.publisherURL)
        try fixture.git(["push", "origin", "v1.0"], in: published.publisherURL)

        let state = await openedWorkspace(fixture, at: published.cloneURL)
        await state.fetchTags()

        #expect(state.repository?.tags == ["v1.0"])
        #expect(state.repositoryFailure == nil)
        #expect(state.lastFetchDate != nil)
    }
}
