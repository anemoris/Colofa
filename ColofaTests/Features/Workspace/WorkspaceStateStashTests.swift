////
//  WorkspaceStateStashTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of saving a Stash: what the sheet runs, and what a refusal leaves
/// behind.
@Suite(.serialized)
final class WorkspaceStateStashTests {
    private let defaults: UserDefaults
    private let repositoryURL = stashRepositoryURL

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateStashTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    private func stub(
        _ snapshots: [RepositorySnapshot] = [stashRepository()],
        stashLists: [[Stash]] = [[]],
        stashesError: RepositoryOpenError? = nil,
        stashDetails: [String: StashDetail] = [:],
        stashDetailError: RepositoryOpenError? = nil,
        mutationError: RepositoryOpenError? = nil,
        mutationDelay: Duration? = nil
    ) -> RepositoryServiceStub {
        RepositoryServiceStub(
            snapshots: [repositoryURL: snapshots],
            mutationError: mutationError,
            mutationDelay: mutationDelay,
            stashLists: stashLists,
            stashesError: stashesError,
            stashDetails: stashDetails,
            stashDetailError: stashDetailError
        )
    }

    private var refusal: RepositoryOpenError {
        .commandFailed(
            GitFailureDetails(
                command: "git stash push",
                output: "error: unable to write new index file",
                exitStatus: 1
            )
        )
    }

    // MARK: - Opening the sheet

    @Test
    @MainActor
    func theSheetOpensWithBothOptionsOff() async throws {
        let state = await workspace(stub())

        state.beginCreatingStash()

        let draft = try #require(state.stashCreation)
        #expect(!draft.keepsStagedChanges)
        #expect(!draft.includesUntrackedFiles)
        #expect(draft.message.isEmpty)
        #expect(state.isCreatingStash)
    }

    /// Nothing has run by the time the sheet is dismissed, so every route out of it is a cancel.
    @Test
    @MainActor
    func dismissingTheSheetRunsNothing() async throws {
        let backend = stub()
        let state = await workspace(backend)

        state.beginCreatingStash()
        state.isCreatingStash = false

        #expect(state.stashCreation == nil)
        #expect(await backend.recordedArguments().isEmpty)
    }

    @Test
    @MainActor
    func aCleanRepositoryCannotOpenTheSheet() async {
        let state = await workspace(
            stub([stashRepository(stagedChanges: [], unstagedChanges: [])])
        )

        #expect(!state.canBeginCreatingStash)
        #expect(state.stashCreationUnavailabilityReason == .noLocalChanges)

        state.beginCreatingStash()
        #expect(state.stashCreation == nil)
    }

    /// The sheet is where Include Untracked Files is turned on, so a Repository whose only work
    /// is untracked still opens it — and the sheet's own button is what says the option is what
    /// stands in the way.
    @Test
    @MainActor
    func untrackedWorkAloneOpensTheSheetAndIsRefusedInsideIt() async {
        let state = await workspace(
            stub(
                [
                    stashRepository(
                        stagedChanges: [],
                        unstagedChanges: [RepositoryChange(path: "notes.txt", kind: .untracked)]
                    ),
                ]
            )
        )

        #expect(state.canBeginCreatingStash)
        state.beginCreatingStash()

        #expect(!state.canCreateStash)
        #expect(state.stashCreationRefusal == .untrackedOnly)

        state.stashCreation?.includesUntrackedFiles = true
        #expect(state.canCreateStash)
        #expect(state.stashCreationRefusal == nil)
    }

    // MARK: - Saving one

    @Test
    @MainActor
    func theDefaultOptionsSaveWithNeitherFlag() async throws {
        let backend = stub()
        let state = await workspace(backend)

        state.beginCreatingStash()
        await state.createStash()

        #expect(await backend.recordedArguments() == [["stash", "push"]])
        #expect(state.stashCreation == nil)
    }

    @Test
    @MainActor
    func everyOptionTheSheetHoldsTravelsWithTheCommand() async throws {
        let backend = stub()
        let state = await workspace(backend)

        state.beginCreatingStash()
        state.stashCreation?.message = "parser rewrite"
        state.stashCreation?.keepsStagedChanges = true
        state.stashCreation?.includesUntrackedFiles = true
        await state.createStash()

        #expect(
            await backend.recordedArguments() == [
                ["stash", "push", "--keep-index", "--include-untracked", "-m", "parser rewrite"],
            ]
        )
    }

    /// Success is not the command returning: it is the Repository read back afterwards.
    @Test
    @MainActor
    func aSavedStashIsFollowedByAnAuthoritativeRead() async throws {
        let saved = stashRepository(stagedChanges: [], unstagedChanges: [])
        let state = await workspace(stub([stashRepository(), saved]))

        state.beginCreatingStash()
        await state.createStash()

        #expect(state.repository?.stagedChanges.isEmpty == true)
        #expect(state.repository?.unstagedChanges.isEmpty == true)
    }

    /// The message and the options are what the user would change, so an alert must not take them
    /// away to say Git refused.
    @Test
    @MainActor
    func aRefusalKeepsTheSheetWithGitsOwnWords() async throws {
        let state = await workspace(stub(mutationError: refusal))

        state.beginCreatingStash()
        state.stashCreation?.message = "parser rewrite"
        await state.createStash()

        let draft = try #require(state.stashCreation)
        #expect(draft.message == "parser rewrite")
        #expect(draft.failure?.output == "error: unable to write new index file")
        #expect(state.repositoryFailure == nil)
    }

    /// A failure is followed by the same authoritative read a success is: what a refused command
    /// left behind is read back rather than assumed to be what was there before it ran.
    @Test
    @MainActor
    func aRefusalStillReadsTheRepositoryBack() async throws {
        let afterRefusal = stashRepository(
            stagedChanges: [],
            unstagedChanges: [RepositoryChange(path: "diff.txt", kind: .modified)]
        )
        let state = await workspace(
            stub([stashRepository(), afterRefusal], mutationError: refusal)
        )

        state.beginCreatingStash()
        await state.createStash()

        #expect(state.repository?.stagedChanges.isEmpty == true)
        #expect(state.repository?.unstagedChanges.map(\.path) == ["diff.txt"])
        #expect(state.stashCreation?.failure != nil)
    }

    /// Once Stash is pressed the command is Git's, and it runs to the end whatever the sheet
    /// does. Letting the sheet go meanwhile would leave a refusal with nowhere to be written, so
    /// no route out of it — Cancel, Escape, or clicking away — may close it until Git answers.
    @Test
    @MainActor
    func theSheetCannotBeDismissedWhileItsStashRuns() async throws {
        let backend = stub(mutationError: refusal, mutationDelay: .milliseconds(200))
        let state = await workspace(backend)

        state.beginCreatingStash()
        state.stashCreation?.message = "parser rewrite"
        let creating = Task { await state.createStash() }
        // The fixture records the command before it blocks, so this is the Stash in flight.
        try await waitForFetch(
            { await backend.recordedMutations().count == 1 },
            "The Stash never reached Git"
        )

        state.cancelStashCreation()
        state.isCreatingStash = false
        #expect(state.isCreatingStash)

        await creating.value

        let draft = try #require(state.stashCreation)
        #expect(draft.message == "parser rewrite")
        #expect(draft.failure?.output == "error: unable to write new index file")
    }

    @Test
    @MainActor
    func nothingRunsWhileAnotherCommandHoldsTheRepository() async throws {
        let backend = stub()
        let state = await workspace(backend)

        state.beginCreatingStash()
        state.isPerformingMutation = true
        await state.createStash()

        #expect(await backend.recordedArguments().isEmpty)
        // Nothing ran, so the sheet stays for the user to press again.
        #expect(state.stashCreation != nil)
    }
}
