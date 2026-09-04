////
//  WorkspaceStateSyncCountTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// The counts the Push and Pull toolbar buttons badge themselves with.
///
/// `nil` means the button shows no count at all, which is deliberately not the same as zero: a
/// Branch level with its upstream has a real answer and it is "nothing to do", while a Branch
/// whose upstream ref is gone has no answer. Both render as no badge, but only one of them could
/// have rendered a number.
@Suite(.serialized)
final class WorkspaceStateSyncCountTests {
    private let defaults: UserDefaults
    private let repositoryURL = URL(filePath: "/tmp/Colofa Sync Counts", directoryHint: .isDirectory)

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateSyncCountTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(upstream: RepositoryUpstream?) async -> WorkspaceState {
        let snapshot = repository(at: repositoryURL, upstream: upstream)
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [snapshot]])
        return await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    @Test
    @MainActor
    func aBranchAheadAndBehindBadgesBothButtons() async {
        let state = await workspace(
            upstream: RepositoryUpstream(name: "origin/main", ahead: 3, behind: 2)
        )

        #expect(state.pushAheadCount == 3)
        #expect(state.pullBehindCount == 2)
    }

    /// Each button reports only its own direction, so a Branch that is only ahead badges Push and
    /// leaves Pull bare.
    @Test
    @MainActor
    func eachButtonCountsOnlyItsOwnDirection() async {
        let state = await workspace(
            upstream: RepositoryUpstream(name: "origin/main", ahead: 4, behind: 0)
        )

        #expect(state.pushAheadCount == 4)
        #expect(state.pullBehindCount == nil)
    }

    /// `↑0` is noise: the button already says what it does, and a zero adds nothing to act on.
    @Test
    @MainActor
    func aLevelBranchBadgesNeitherButton() async {
        let state = await workspace(
            upstream: RepositoryUpstream(name: "origin/main", ahead: 0, behind: 0)
        )

        #expect(state.pushAheadCount == nil)
        #expect(state.pullBehindCount == nil)
    }

    /// Git stops counting once the ref it counted against is gone, so there is no number to show
    /// and inventing zero would claim the Branch is caught up with something absent.
    @Test
    @MainActor
    func anUpstreamThatIsGoneBadgesNeitherButton() async {
        let state = await workspace(
            upstream: RepositoryUpstream(name: "origin/main", position: .gone)
        )

        #expect(state.pushAheadCount == nil)
        #expect(state.pullBehindCount == nil)
    }

    /// An Unborn Branch has no Commit to count from.
    @Test
    @MainActor
    func anUnbornBranchBadgesNeitherButton() async {
        let state = await workspace(
            upstream: RepositoryUpstream(name: "origin/main", position: .unborn)
        )

        #expect(state.pushAheadCount == nil)
        #expect(state.pullBehindCount == nil)
    }

    /// No upstream at all is the state Push reads as Publish, and nothing has been counted.
    @Test
    @MainActor
    func aBranchWithoutAnUpstreamBadgesNeitherButton() async {
        let state = await workspace(upstream: nil)

        #expect(state.pushAheadCount == nil)
        #expect(state.pullBehindCount == nil)
    }

    /// With no Repository open there is nothing to count and nothing to read it from.
    @Test
    @MainActor
    func aClosedWorkspaceBadgesNeitherButton() {
        let state = WorkspaceState()

        #expect(state.pushAheadCount == nil)
        #expect(state.pullBehindCount == nil)
    }
}
