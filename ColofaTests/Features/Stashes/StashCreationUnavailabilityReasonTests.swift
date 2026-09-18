////
//  StashCreationUnavailabilityReasonTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Why a Stash is refused before any command runs.
struct StashCreationUnavailabilityReasonTests {
    private let url = URL(filePath: "/tmp/Stash Reason")

    private func evaluate(
        _ snapshot: RepositorySnapshot?,
        includesUntrackedFiles: Bool = true,
        isMutating: Bool = false
    ) -> StashCreationUnavailabilityReason? {
        StashCreationUnavailabilityReason.evaluate(
            repository: snapshot,
            includesUntrackedFiles: includesUntrackedFiles,
            isMutating: isMutating
        )
    }

    private func stashable(
        staged: [RepositoryChange] = [RepositoryChange(path: "a.txt", kind: .modified)],
        unstaged: [RepositoryChange] = [],
        head: RepositoryHead = .branch("main"),
        operation: RepositoryOperation? = nil
    ) -> RepositorySnapshot {
        repository(
            at: url,
            head: head,
            operation: operation,
            stagedChanges: staged,
            unstagedChanges: unstaged
        )
    }

    @Test
    func aRepositoryWithTrackedWorkMaySaveOne() {
        #expect(evaluate(stashable()) == nil)
    }

    @Test
    func noRepositoryIsRefusedFirst() {
        #expect(evaluate(nil) == .noRepository)
    }

    /// Git answers "You do not have the initial commit yet", so the state is refused rather than
    /// attempted.
    @Test
    func anUnbornBranchHasNothingToSaveAStashAgainst() {
        #expect(
            evaluate(stashable(head: .unbornBranch("main"))) == .unbornBranch
        )
    }

    @Test(arguments: [RepositoryOperation.merge, .rebase, .cherryPick, .revert, .am])
    func anUnfinishedOperationRefusesTheStash(operation: RepositoryOperation) {
        #expect(evaluate(stashable(operation: operation)) == .operationInProgress)
    }

    /// Git refuses to save an index holding unmerged paths.
    @Test
    func anUnresolvedConflictRefusesTheStash() {
        #expect(
            evaluate(
                stashable(
                    staged: [],
                    unstaged: [RepositoryChange(path: "c.txt", kind: .conflict)]
                )
            ) == .conflict
        )
    }

    /// `git stash push` with nothing to save exits successfully having created nothing, so a
    /// clean tree is refused here rather than reported as a Stash that does not exist.
    @Test
    func aCleanRepositoryHasNothingToSave() {
        #expect(evaluate(stashable(staged: [], unstaged: [])) == .noLocalChanges)
    }

    /// Untracked work is still work, so the control that opens the sheet stays available: the
    /// sheet is where Include Untracked Files is turned on.
    @Test
    func untrackedWorkAloneStillOpensTheSheet() {
        let snapshot = stashable(
            staged: [],
            unstaged: [RepositoryChange(path: "notes.txt", kind: .untracked)]
        )

        #expect(evaluate(snapshot, includesUntrackedFiles: true) == nil)
    }

    /// With the option off, the same Repository would save nothing — and says which option to
    /// turn on rather than sitting disabled in silence.
    @Test
    func untrackedWorkAloneIsRefusedWhileTheOptionIsOff() {
        let snapshot = stashable(
            staged: [],
            unstaged: [RepositoryChange(path: "notes.txt", kind: .untracked)]
        )

        #expect(evaluate(snapshot, includesUntrackedFiles: false) == .untrackedOnly)
    }

    /// A tracked change is saved whichever way the option is set, so it is never the untracked
    /// refusal.
    @Test(arguments: [true, false])
    func trackedWorkIsSavedWhicheverWayTheOptionIsSet(includesUntrackedFiles: Bool) {
        let snapshot = stashable(
            staged: [],
            unstaged: [RepositoryChange(path: "a.txt", kind: .modified)]
        )

        #expect(evaluate(snapshot, includesUntrackedFiles: includesUntrackedFiles) == nil)
    }

    /// `git stash push` decides whether there is anything to save while ignoring submodules, so
    /// every shape of submodule change — a dirty tree inside it, a moved Commit, a Staged move —
    /// would exit successfully having saved nothing.
    @Test(
        arguments: [
            (
                [RepositoryChange](),
                [RepositoryChange(path: "sub", kind: .modified, isSubmodule: true)]
            ),
            (
                [RepositoryChange(path: "sub", kind: .modified, isSubmodule: true)],
                [RepositoryChange]()
            ),
        ]
    )
    func submoduleChangesAloneHaveNothingGitWouldSave(
        staged: [RepositoryChange],
        unstaged: [RepositoryChange]
    ) {
        #expect(
            evaluate(stashable(staged: staged, unstaged: unstaged)) == .submoduleChangesOnly
        )
    }

    /// Alongside other work the Stash does run, and Git saves the submodule's Staged move with it.
    @Test
    func aSubmoduleChangeBesideTrackedWorkMaySaveOne() {
        let snapshot = stashable(
            staged: [RepositoryChange(path: "sub", kind: .modified, isSubmodule: true)],
            unstaged: [RepositoryChange(path: "a.txt", kind: .modified)]
        )

        #expect(evaluate(snapshot) == nil)
    }

    /// Untracked files still give the Stash something to save, and the refusal is about the one
    /// option that would save them rather than about the submodule.
    @Test
    func aSubmoduleChangeBesideUntrackedWorkFollowsTheUntrackedOption() {
        let snapshot = stashable(
            staged: [],
            unstaged: [
                RepositoryChange(path: "notes.txt", kind: .untracked),
                RepositoryChange(path: "sub", kind: .modified, isSubmodule: true),
            ]
        )

        #expect(evaluate(snapshot, includesUntrackedFiles: true) == nil)
        #expect(evaluate(snapshot, includesUntrackedFiles: false) == .untrackedOnly)
    }

    @Test
    func anotherCommandHoldingTheRepositoryRefusesTheStash() {
        #expect(evaluate(stashable(), isMutating: true) == .mutationInProgress)
    }

    /// A state Colofa can name comes before the one that only says to wait, so the refusal is
    /// about the Repository rather than about timing.
    @Test
    func aNamedStateIsReportedAheadOfAnotherRunningCommand() {
        #expect(
            evaluate(stashable(staged: [], unstaged: []), isMutating: true) == .noLocalChanges
        )
    }

    @Test(
        arguments: [
            StashCreationUnavailabilityReason.noRepository,
            .unbornBranch,
            .operationInProgress,
            .conflict,
            .noLocalChanges,
            .submoduleChangesOnly,
            .untrackedOnly,
            .mutationInProgress,
        ]
    )
    func everyReasonSaysSomething(reason: StashCreationUnavailabilityReason) {
        #expect(!String(localized: reason.message).isEmpty)
    }
}
