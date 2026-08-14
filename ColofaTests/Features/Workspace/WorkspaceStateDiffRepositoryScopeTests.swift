////
//  WorkspaceStateDiffRepositoryScopeTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What the Diff pane may carry from one Repository into another: nothing.
///
/// Two Repositories can report a Change of the same path, kind, and side. Neither the patch on
/// screen nor a confirmation the user gave for it describes the other one's file.
@Suite(.serialized)
struct WorkspaceStateDiffRepositoryScopeTests {
    /// A confirmation is given for one file in one Repository. Another Repository reporting a
    /// path of the same name is another file, and the user has said nothing about it.
    @Test
    @MainActor
    func openingAnotherRepositoryWithdrawsTheConfirmationGivenInTheFirst() async throws {
        let stub = Self.stub()
        let state = await diffWorkspace(stub)
        state.selectedChange = RepositoryChangeSelection(path: "large.txt", isStaged: false)
        await state.loadDiff()
        await state.loadDiffAnyway()

        await state.handleRepositorySelection(.success(otherDiffRepositoryURL))
        await state.loadDiff()

        let requests = await stub.recordedDiffRequests()
        #expect(requests.map(\.isConfirmed) == [false, true, false])
        #expect(
            requests.map(\.repositoryURL)
                == [diffRepositoryURL, diffRepositoryURL, otherDiffRepositoryURL]
        )
    }

    /// The patch on screen belongs to the Repository it was read from. Another Repository with a
    /// file of the same name gets the loading state, not the previous Repository's content.
    @Test
    @MainActor
    func openingAnotherRepositoryClearsThePatchTheFirstOneLeft() async throws {
        let state = await diffWorkspace(Self.stub(diffDelay: .milliseconds(200)))
        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: false)
        await state.loadDiff()
        guard case .loaded = state.diff else {
            Issue.record("Expected a rendered Diff, got \(String(describing: state.diff))")
            return
        }

        await state.handleRepositorySelection(.success(otherDiffRepositoryURL))
        let load = Task { await state.loadDiff() }
        try await waitForDiffLoadingState(of: state)
        await load.value

        guard case .loaded = state.diff else {
            Issue.record("Expected the second Diff, got \(String(describing: state.diff))")
            return
        }
    }

    /// An offer belongs to the Repository it was made for, so the Repository moving on takes the
    /// offer with it rather than letting a click confirm another file.
    @Test
    @MainActor
    func loadAnywayIsIgnoredOnceTheWorkspaceMovedToAnotherRepository() async throws {
        let stub = Self.stub()
        let state = await diffWorkspace(stub)
        state.selectedChange = RepositoryChangeSelection(path: "large.txt", isStaged: false)
        await state.loadDiff()

        await state.handleRepositorySelection(.success(otherDiffRepositoryURL))
        await state.loadDiffAnyway()

        let requests = await stub.recordedDiffRequests()
        #expect(requests.map(\.isConfirmed) == [false])
    }

    private static func stub(diffDelay: Duration? = nil) -> RepositoryServiceStub {
        diffRepositoryStub(
            at: [diffRepositoryURL, otherDiffRepositoryURL],
            diffDelay: diffDelay
        )
    }
}
