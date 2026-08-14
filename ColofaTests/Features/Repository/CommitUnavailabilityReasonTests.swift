////
//  CommitUnavailabilityReasonTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Every reason Commit or Amend can refuse to run, and the order they are reported in.
struct CommitUnavailabilityReasonTests {
    private let repositoryURL = URL(filePath: "/tmp/Commit Availability")

    @Test
    func stagedChangesWithAnIdentityAndASummaryAreCommittable() {
        #expect(reason(for: committableRepository()) == nil)
    }

    @Test
    func noRepositoryIsReportedBeforeAnythingElse() {
        #expect(
            CommitUnavailabilityReason.evaluate(
                repository: nil,
                hasSummary: false,
                isAmending: false,
                isMutating: true
            ) == .noRepository
        )
    }

    @Test
    func detachedHeadRefusesACommitThatWouldBecomeUnreachable() {
        let detached = repository(
            at: repositoryURL,
            head: .detached("0123456789abcdef"),
            headCommit: RepositoryHeadCommit(objectID: "fixture-head", summary: "Previous"),
            stagedChanges: [RepositoryChange(path: "staged.txt", kind: .modified)],
            configuration: identityConfiguration()
        )

        #expect(reason(for: detached) == .detachedHead)
        #expect(reason(for: detached, isAmending: true) == .detachedHead)
    }

    @Test
    func anActiveOperationIsReportedBeforeItsConflicts() {
        let merging = repository(
            at: repositoryURL,
            headCommit: RepositoryHeadCommit(objectID: "fixture-head", summary: "Previous"),
            operation: .merge,
            stagedChanges: [RepositoryChange(path: "staged.txt", kind: .modified)],
            unstagedChanges: [RepositoryChange(path: "conflict.txt", kind: .conflict)],
            configuration: identityConfiguration()
        )

        #expect(reason(for: merging) == .operationInProgress)
    }

    @Test
    func anUnmergedPathRefusesACommitEvenWithoutAnActiveOperation() {
        let conflicted = repository(
            at: repositoryURL,
            headCommit: RepositoryHeadCommit(objectID: "fixture-head", summary: "Previous"),
            stagedChanges: [RepositoryChange(path: "staged.txt", kind: .modified)],
            unstagedChanges: [RepositoryChange(path: "conflict.txt", kind: .conflict)],
            configuration: identityConfiguration()
        )

        #expect(reason(for: conflicted) == .conflict)
    }

    @Test
    func anEmptyIndexRefusesACommitButNotAnAmend() {
        let clean = repository(
            at: repositoryURL,
            headCommit: RepositoryHeadCommit(objectID: "fixture-head", summary: "Previous"),
            configuration: identityConfiguration()
        )

        #expect(reason(for: clean) == .noStagedChanges)
        #expect(reason(for: clean, isAmending: true) == nil)
    }

    @Test
    func anUnbornBranchCommitsButHasNothingToAmend() {
        let unborn = repository(
            at: repositoryURL,
            head: .unbornBranch("main"),
            stagedChanges: [RepositoryChange(path: "first.txt", kind: .added)],
            configuration: identityConfiguration()
        )

        #expect(reason(for: unborn) == nil)
        #expect(reason(for: unborn, isAmending: true) == .nothingToAmend)
    }

    /// Identity is checked after the index deliberately: a Repository nothing is staged in should
    /// not open by demanding a name and an email.
    @Test
    func missingIdentityIsReportedOnlyOnceSomethingIsStaged() {
        let withoutIdentity = repository(
            at: repositoryURL,
            headCommit: RepositoryHeadCommit(objectID: "fixture-head", summary: "Previous"),
            stagedChanges: [RepositoryChange(path: "staged.txt", kind: .modified)]
        )
        let nothingStaged = repository(
            at: repositoryURL,
            headCommit: RepositoryHeadCommit(objectID: "fixture-head", summary: "Previous")
        )

        #expect(reason(for: withoutIdentity) == .missingIdentity)
        #expect(reason(for: nothingStaged) == .noStagedChanges)
    }

    @Test
    func anEmptySummaryIsReportedLastAmongTheFixableReasons() {
        #expect(reason(for: committableRepository(), hasSummary: false) == .emptySummary)
    }

    /// A running command must not replace a standing explanation, so it is only reported when
    /// nothing else applies.
    @Test
    func aRunningCommandIsReportedOnlyWhenEverythingElseIsSatisfied() {
        let clean = repository(
            at: repositoryURL,
            headCommit: RepositoryHeadCommit(objectID: "fixture-head", summary: "Previous"),
            configuration: identityConfiguration()
        )

        #expect(reason(for: committableRepository(), isMutating: true) == .mutationInProgress)
        #expect(reason(for: clean, isMutating: true) == .noStagedChanges)
    }

    private func committableRepository() -> RepositorySnapshot {
        repository(
            at: repositoryURL,
            headCommit: RepositoryHeadCommit(objectID: "fixture-head", summary: "Previous"),
            stagedChanges: [RepositoryChange(path: "staged.txt", kind: .modified)],
            unstagedChanges: [RepositoryChange(path: "notes.txt", kind: .untracked)],
            configuration: identityConfiguration()
        )
    }

    private func reason(
        for repository: RepositorySnapshot,
        hasSummary: Bool = true,
        isAmending: Bool = false,
        isMutating: Bool = false
    ) -> CommitUnavailabilityReason? {
        CommitUnavailabilityReason.evaluate(
            repository: repository,
            hasSummary: hasSummary,
            isAmending: isAmending,
            isMutating: isMutating
        )
    }
}
