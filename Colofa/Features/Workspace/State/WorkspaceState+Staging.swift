////
//  WorkspaceState+Staging.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

extension WorkspaceState {
    func stage(_ change: RepositoryChange) async {
        guard canStage(change) else {
            return
        }
        await performMutation(
            ["--literal-pathspecs", "add", "--"] + change.gitPathspecs,
            failureTitle: .stageFileFailed
        )
    }

    func unstage(_ change: RepositoryChange) async {
        guard canUnstage(change), let repository else {
            return
        }
        await performMutation(
            unstageArguments(change.gitPathspecs, head: repository.head),
            failureTitle: .unstageFileFailed
        )
    }

    func stageAll() async {
        guard let repository else {
            return
        }
        let paths = uniquePathspecs(for: repository.unstagedChanges.filter { !$0.isConflict })
        guard !paths.isEmpty else {
            return
        }
        await performMutation(
            ["--literal-pathspecs", "add", "--"] + paths,
            failureTitle: .stageFilesFailed
        )
    }

    func unstageAll() async {
        guard let repository else {
            return
        }
        let paths = uniquePathspecs(for: repository.stagedChanges)
        guard !paths.isEmpty else {
            return
        }
        await performMutation(
            unstageArguments(paths, head: repository.head),
            failureTitle: .unstageFilesFailed
        )
    }

    func canStage(_ change: RepositoryChange) -> Bool {
        canMutateRepository
            && !change.isConflict
            && repository?.unstagedChanges.contains(change) == true
    }

    func canUnstage(_ change: RepositoryChange) -> Bool {
        canMutateRepository && repository?.stagedChanges.contains(change) == true
    }

    var canStageAll: Bool {
        canMutateRepository
            && repository?.unstagedChanges.contains(where: { !$0.isConflict }) == true
    }

    var canUnstageAll: Bool {
        canMutateRepository && repository?.stagedChanges.isEmpty == false
    }

    private func uniquePathspecs(for changes: [RepositoryChange]) -> [String] {
        var seen = Set<String>()
        return changes.flatMap(\.gitPathspecs).filter { seen.insert($0).inserted }
    }

    private func unstageArguments(_ paths: [String], head: RepositoryHead) -> [String] {
        if case .unbornBranch = head {
            ["--literal-pathspecs", "rm", "--cached", "-f", "--"] + paths
        } else {
            ["--literal-pathspecs", "restore", "--staged", "--"] + paths
        }
    }
}
