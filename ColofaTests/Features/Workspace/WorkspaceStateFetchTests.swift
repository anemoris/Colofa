////
//  WorkspaceStateFetchTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of Fetch: which commands run, what a partial or stopped Fetch leaves
/// behind, and the app-owned time only a completed one writes.
@Suite(.serialized)
final class WorkspaceStateFetchTests {
    private let defaults: UserDefaults
    private let suiteName = "com.anemoris.Colofa.WorkspaceStateFetchTests"
    private let repositoryURL = fetchRepositoryURL

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await fetchWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    // MARK: - Fetch

    @Test
    @MainActor
    func fetchesEveryConfiguredRemoteOneAtATime() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [fetchRepository()]])
        let state = await workspace(stub)

        await state.fetch()

        #expect(
            await stub.recordedNetworkMutations() == [
                ["fetch", "--", "origin"],
                ["fetch", "--", "mirror"],
            ]
        )
        #expect(state.repositoryFailure == nil)
    }

    /// Git's own `remote.<name>.skipFetchAll` decides eligibility, so a skipped remote is never
    /// contacted.
    @Test
    @MainActor
    func leavesOutTheRemotesGitExcludesFromAFetchOfAllOfThem() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository()]],
            skippedRemotes: ["mirror"]
        )
        let state = await workspace(stub)

        await state.fetch()

        #expect(await stub.recordedNetworkMutations() == [["fetch", "--", "origin"]])
    }

    @Test
    @MainActor
    func runsNoCommandWhenGitExcludesEveryRemote() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository()]],
            skippedRemotes: ["origin", "mirror"]
        )
        let state = await workspace(stub)

        await state.fetch()

        #expect(await stub.recordedNetworkMutations().isEmpty)
        #expect(state.repositoryFailureTitle == .fetchNothingEligibleTitle)
        #expect(!state.canShowRepositoryFailureDetails)
        #expect(state.lastFetchDate == nil)
    }

    /// Colofa could not even find out which remotes to contact, so it says that rather than
    /// blaming a remote it never reached.
    @Test
    @MainActor
    func reportsAConfigurationItCouldNotRead() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository()]],
            skippedRemotesError: .commandFailed(
                GitFailureDetails(command: "git config", output: "bad boolean", exitStatus: 128)
            )
        )
        let state = await workspace(stub)

        await state.fetch()

        #expect(await stub.recordedNetworkMutations().isEmpty)
        #expect(state.repositoryFailureTitle == .fetchFailed)
        #expect(state.repositoryFailureMessage == .fetchPlanFailedDescription)
        #expect(state.canShowRepositoryFailureDetails)
    }

    /// A Fetch reads Repository state back afterwards, because what arrived is Git's answer
    /// rather than something Colofa can assume.
    @Test
    @MainActor
    func reloadsTheRepositoryAfterFetching() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    fetchRepository(),
                    fetchRepository(remoteBranches: ["origin/main", "origin/feature"]),
                ],
            ]
        )
        let state = await workspace(stub)

        await state.fetch()

        #expect(state.repository?.remoteBranches == ["origin/main", "origin/feature"])
    }

    @Test
    @MainActor
    func namesTheFailingRemoteAndKeepsFetchingTheRest() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository(remotes: ["mirror", "origin"])]],
            failingRemotes: ["mirror"]
        )
        let state = await workspace(stub)

        await state.fetch()

        #expect(
            await stub.recordedNetworkMutations() == [
                ["fetch", "--", "mirror"],
                ["fetch", "--", "origin"],
            ]
        )
        let message = try #require(state.repositoryFailureMessage)
        #expect(String(localized: message).contains("mirror"))
        #expect(state.canShowRepositoryFailureDetails)
    }

    /// A remote that answered stays refreshed even though a later one failed, so the state on
    /// screen is the one Git actually left behind — and the last-Fetch time says a remote was
    /// contacted, because one was.
    @Test
    @MainActor
    func keepsTheRefsAFailedFetchAlreadyRefreshed() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    fetchRepository(),
                    fetchRepository(remoteBranches: ["origin/main", "origin/feature"]),
                ],
            ],
            failingRemotes: ["mirror"]
        )
        let state = await workspace(stub)

        await state.fetch()

        #expect(state.repository?.remoteBranches == ["origin/main", "origin/feature"])
        #expect(state.lastFetchDate != nil)
    }

    // MARK: - Last Fetch

    @Test
    @MainActor
    func recordsTheLastFetchTimeWhenARemoteAnswered() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [fetchRepository()]])
        let state = await workspace(stub)
        #expect(state.lastFetchDate == nil)

        await state.fetch()

        let recorded = try #require(state.lastFetchDate)
        #expect(recorded.timeIntervalSinceNow < 5)
    }

    /// The time belongs to one Repository, so reopening another never inherits it.
    @Test
    @MainActor
    func persistsTheLastFetchTimePerRepository() async throws {
        let otherURL = URL(filePath: "/tmp/Other Fetch Store")
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [fetchRepository()],
                otherURL: [fetchRepository(at: otherURL)],
            ]
        )
        let state = await workspace(stub)
        await state.fetch()
        let recorded = try #require(state.lastFetchDate)

        await state.handleRepositorySelection(.success(otherURL))
        #expect(state.lastFetchDate == nil)

        await state.handleRepositorySelection(.success(repositoryURL))
        let restored = try #require(state.lastFetchDate)
        #expect(abs(restored.timeIntervalSince(recorded)) < 0.001)
    }

    // MARK: - No Fetch of its own

    /// Colofa contacts a remote only when the user asks. Opening, refreshing, and reloading a
    /// Repository must never do it on their own.
    @Test
    @MainActor
    func neverFetchesWithoutBeingAsked() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [fetchRepository()]])
        let state = await workspace(stub)

        await state.start()
        await state.refresh()
        await state.refresh()

        #expect(await stub.recordedNetworkMutations().isEmpty)
    }

    @Test
    @MainActor
    func refusesToFetchWithoutARemote() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository(remotes: [])]]
        )
        let state = await workspace(stub)

        #expect(!state.canFetch)
        #expect(state.fetchUnavailabilityReason == .noRemotes)
        await state.fetch()
        await state.fetchTags()

        #expect(await stub.recordedNetworkMutations().isEmpty)
    }
}
