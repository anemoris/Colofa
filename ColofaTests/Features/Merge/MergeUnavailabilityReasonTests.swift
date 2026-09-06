////
//  MergeUnavailabilityReasonTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// What stops a Merge before any command runs, which is what a disabled control has to explain.
struct MergeUnavailabilityReasonTests {
    private let source = MergeSource(
        name: "feature",
        revision: "refs/heads/feature",
        isRemote: false
    )

    private func evaluate(
        _ repository: RepositorySnapshot?,
        source: MergeSource? = nil,
        isMutating: Bool = false
    ) -> MergeUnavailabilityReason? {
        MergeUnavailabilityReason.evaluate(
            source: source ?? self.source,
            repository: repository,
            isMutating: isMutating
        )
    }

    @Test
    func aCleanRepositoryOnAnotherBranchMayMerge() {
        #expect(evaluate(mergeRepository()) == nil)
    }

    @Test
    func noRepositoryHasNothingToMergeInto() {
        #expect(evaluate(nil) == .noRepository)
    }

    /// A tag and HEAD resolve to no source at all, which is the answer this reports.
    @Test
    func aRefThatIsNotABranchIsRefusedByName() {
        #expect(
            MergeUnavailabilityReason.evaluate(
                source: nil,
                repository: mergeRepository(),
                isMutating: false
            ) == .notBranch
        )
    }

    @Test
    func anUnbornBranchHasNoCommitToMergeInto() {
        #expect(
            evaluate(mergeRepository(head: .unbornBranch("main"))) == .unbornBranch
        )
    }

    @Test
    func theCurrentBranchCannotBeMergedIntoItself() {
        #expect(
            evaluate(mergeRepository(head: .branch("feature"))) == .currentBranch
        )
    }

    /// A Remote-tracking Branch is never the Branch HEAD is on, whatever it is called.
    @Test
    func aRemoteBranchSharingTheCurrentBranchesNameStillMerges() {
        #expect(
            evaluate(
                mergeRepository(head: .branch("origin/main")),
                source: MergeSource(
                    name: "origin/main",
                    revision: "refs/remotes/origin/main",
                    isRemote: true
                )
            ) == nil
        )
    }

    @Test
    func anUnfinishedOperationIsLeftFirst() {
        #expect(
            evaluate(mergeRepository(operation: .rebase)) == .operationInProgress
        )
    }

    @Test
    func anUnresolvedConflictIsResolvedFirst() {
        #expect(
            evaluate(
                mergeRepository(
                    unstagedChanges: [RepositoryChange(path: "a.txt", kind: .conflict)]
                )
            ) == .conflict
        )
    }

    /// Colofa neither stashes tracked work nor merges around it, so the refusal comes before the
    /// command and names the two things the user can do instead.
    @Test
    func stagedWorkBlocksTheMergeWithCommitOrStashGuidance() {
        let reason = evaluate(
            mergeRepository(
                stagedChanges: [RepositoryChange(path: "a.txt", kind: .modified)]
            )
        )

        #expect(reason == .localChanges)
        #expect(
            englishText(MergeUnavailabilityReason.localChanges.message)
                == "Commit or Stash your local changes before merging."
        )
    }

    @Test(
        arguments: [
            RepositoryChangeKind.modified,
            .added,
            .deleted,
            .typeChanged,
            .renamed(from: "old.txt"),
        ]
    )
    func anyUnstagedTrackedChangeBlocksTheMerge(kind: RepositoryChangeKind) {
        #expect(
            evaluate(
                mergeRepository(unstagedChanges: [RepositoryChange(path: "a.txt", kind: kind)])
            ) == .localChanges
        )
    }

    /// Work Git has never recorded is unrelated to what a merge writes unless it lands on the
    /// same path, and that collision is Git's answer rather than something a snapshot decides.
    @Test
    func untrackedWorkAloneDoesNotBlockTheMerge() {
        #expect(
            evaluate(
                mergeRepository(
                    unstagedChanges: [RepositoryChange(path: "notes.txt", kind: .untracked)]
                )
            ) == nil
        )
    }

    @Test
    func aRunningCommandHoldsTheRepository() {
        #expect(evaluate(mergeRepository(), isMutating: true) == .mutationInProgress)
    }
}
