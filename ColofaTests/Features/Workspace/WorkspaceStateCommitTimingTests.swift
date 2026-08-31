////
//  WorkspaceStateCommitTimingTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What the composer is allowed to do while a Commit it started is still running.
///
/// A Commit hands Git the message that existed when the command began and clears the composer
/// once the reload after it lands. Everything typed between those two moments would be dropped by
/// both, which is why the window is closed rather than left open and then discarded.
@Suite(.serialized)
final class WorkspaceStateCommitTimingTests {
    private let defaults: UserDefaults
    private let suiteName = "com.anemoris.Colofa.WorkspaceStateCommitTimingTests"
    private let repositoryURL = URL(filePath: "/tmp/Commit Timing Store")

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    /// A Commit blocked in a Hook or in signing is the ordinary slow case, and it is exactly the
    /// window in which the composer must refuse text.
    @Test
    @MainActor
    func theComposerIsClosedForTheWholeCommitAndOpensAgainAfterwards() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [committableRepository(at: repositoryURL)]],
            mutationDelay: .milliseconds(200)
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
        state.commitDraft.summary = "Add the composer"

        #expect(!state.isCommitting)
        let committing = Task { await state.commit() }
        // The fixture records the command before it blocks, so this is the Commit in flight.
        try await waitForFetch(
            { await stub.recordedMutations().count == 1 },
            "The Commit never reached Git"
        )

        #expect(state.isCommitting)

        await committing.value

        // Only now, with the authoritative reload landed and the composer cleared, may it accept
        // text again — the clear is the last thing that could have thrown it away.
        #expect(!state.isCommitting)
        #expect(state.commitDraft == CommitMessageDraft())
    }

    /// A Commit that failed leaves the message the user still has to act on, so the composer has
    /// to be usable again the moment the failure is on screen.
    @Test
    @MainActor
    func afailedCommitOpensTheComposerWithTheMessageStillInIt() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [committableRepository(at: repositoryURL)]],
            mutationError: .commandFailed(
                GitFailureDetails(command: "git commit", output: "hook refused")
            )
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
        state.commitDraft.summary = "Add the composer"
        state.commitDraft.body = "Why it exists."

        await state.commit()

        #expect(!state.isCommitting)
        #expect(state.commitDraft.summary == "Add the composer")
        #expect(state.commitDraft.body == "Why it exists.")
    }

    /// Writing a Commit message while Changes are being staged is ordinary work: staging never
    /// reads the message and never clears it. The composer closes for a Commit, not for every
    /// command that happens to hold the Repository.
    @Test
    @MainActor
    func stagingLeavesTheComposerOpen() async throws {
        let unstaged = RepositoryChange(path: "notes.txt", kind: .untracked)
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    committableRepository(at: repositoryURL, unstagedChanges: [unstaged]),
                ],
            ],
            mutationDelay: .milliseconds(200)
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)

        let staging = Task { await state.stageAll() }
        try await waitForFetch(
            { await stub.recordedMutations().count == 1 },
            "The staging command never reached Git"
        )

        #expect(!state.canMutateRepository)
        #expect(!state.isCommitting)

        await staging.value
    }
}
