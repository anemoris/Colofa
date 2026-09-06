////
//  UITestingRepositorySnapshots.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// The Repository states UI tests select with launch arguments.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `UITestingRepositoryService` builds these from an actor.
nonisolated enum UITestingRepositorySnapshots {
    static func initial(at url: URL, arguments: [String]) -> RepositorySnapshot {
        if arguments.contains(UITestingArgument.diffState) {
            return diffState(at: url)
        }
        if arguments.contains(UITestingArgument.committableState) {
            return committable(at: url, arguments: arguments)
        }
        if arguments.contains(UITestingArgument.branchState) {
            return branchState(at: url)
        }
        if arguments.contains(UITestingArgument.mergeState) {
            return mergeState(at: url, arguments: arguments)
        }
        if arguments.contains(UITestingArgument.fetchState) {
            return fetchState(at: url, arguments: arguments)
        }
        if arguments.contains(UITestingArgument.pullState) {
            return pullState(at: url, arguments: arguments)
        }
        if arguments.contains(UITestingArgument.pushState) {
            return pushState(at: url, arguments: arguments)
        }
        if arguments.contains(UITestingArgument.realRepositoryState) {
            return realState(at: url, arguments: arguments)
        }
        return RepositorySnapshot(
            name: url.lastPathComponent,
            rootURL: url,
            gitDirectoryURL: url.appending(path: ".git"),
            head: .unbornBranch("main")
        )
    }

    private static func realState(at url: URL, arguments: [String]) -> RepositorySnapshot {
        let partial = RepositoryChange(path: "partial 文件.txt", kind: .modified)
        return RepositorySnapshot(
            name: url.lastPathComponent,
            rootURL: url,
            gitDirectoryURL: url.appending(path: ".git"),
            head: arguments.contains(UITestingArgument.detachedHead)
                ? .detached("0123456789abcdef")
                : .branch("main"),
            headCommit: RepositoryHeadCommit(
                objectID: "ui-fixture-head",
                summary: "Fixture commit",
                body: "Fixture body"
            ),
            upstream: RepositoryUpstream(name: "origin/main", ahead: 3, behind: 2),
            remotes: arguments.contains(UITestingArgument.remoteBranchesOnly)
                ? []
                : [RepositoryRemote(name: "origin", url: "ssh://example.invalid/Colofa.git")],
            localBranches: ["feature/真实", "main"],
            remoteBranches: ["origin/main"],
            tags: ["v1.0-测试"],
            stagedChanges: [
                RepositoryChange(path: "added.swift", kind: .added),
                partial,
                RepositoryChange(path: "renamed 名称.txt", kind: .renamed(from: "old name.txt")),
            ],
            unstagedChanges: [
                RepositoryChange(path: "conflict.txt", kind: .conflict),
                RepositoryChange(path: "Link", kind: .typeChanged),
                RepositoryChange(path: "deleted.swift", kind: .deleted),
                RepositoryChange(path: "notes.txt", kind: .untracked),
                partial,
            ],
            operation: operation(arguments: arguments),
            totalCommitCount: 12,
            gitObjectSize: 4_096,
            configuration: configuration(at: url)
        )
    }

    /// A Repository that can actually be committed: Staged Changes, a configured identity, and a
    /// published HEAD whose Amend must be warned about.
    private static func committable(at url: URL, arguments: [String]) -> RepositorySnapshot {
        let isUnborn = arguments.contains(UITestingArgument.unbornCommitState)
        let isClean = arguments.contains(UITestingArgument.cleanCommitState)
        let head: RepositoryHead
        if isUnborn {
            head = .unbornBranch("main")
        } else if arguments.contains(UITestingArgument.detachedHead) {
            head = .detached("0123456789abcdef")
        } else {
            head = .branch("main")
        }
        return RepositorySnapshot(
            name: url.lastPathComponent,
            rootURL: url,
            gitDirectoryURL: url.appending(path: ".git"),
            head: head,
            headCommit: isUnborn ? nil : RepositoryHeadCommit(
                objectID: "ui-published-head",
                summary: "Published summary",
                body: "Published body",
                isPublished: true
            ),
            upstream: isUnborn
                ? nil
                : RepositoryUpstream(name: "origin/main", ahead: 0, behind: 0),
            remotes: [RepositoryRemote(name: "origin", url: "ssh://example.invalid/Colofa.git")],
            localBranches: ["main"],
            remoteBranches: ["origin/main"],
            stagedChanges: isClean
                ? []
                : [RepositoryChange(path: "staged.swift", kind: .modified)],
            unstagedChanges: isClean || isUnborn
                ? []
                : [
                    RepositoryChange(
                        path: arguments.contains(UITestingArgument.commitConflict)
                            ? "conflict.txt"
                            : "notes.txt",
                        kind: arguments.contains(UITestingArgument.commitConflict)
                            ? .conflict
                            : .untracked
                    ),
                ],
            operation: activeOperation(arguments: arguments),
            totalCommitCount: isUnborn ? 0 : 12,
            gitObjectSize: 4_096,
            configuration: arguments.contains(UITestingArgument.missingCommitIdentity)
                ? .empty
                : configuration(at: url)
        )
    }

    /// A Repository whose Refs can actually be checked out: local branches, a remote branch with
    /// no local counterpart yet, a tag, and neither a Conflict nor an active operation in the way.
    private static func branchState(at url: URL) -> RepositorySnapshot {
        RepositorySnapshot(
            name: url.lastPathComponent,
            rootURL: url,
            gitDirectoryURL: url.appending(path: ".git"),
            head: .branch("main"),
            headCommit: RepositoryHeadCommit(
                objectID: "ui-branch-head",
                summary: "Fixture commit"
            ),
            remotes: [RepositoryRemote(name: "origin", url: "ssh://example.invalid/Colofa.git")],
            localBranches: ["feature/真实", "main"],
            remoteBranches: ["origin/feature", "origin/main"],
            tags: ["v1.0-测试"],
            unstagedChanges: [
                RepositoryChange(path: UITestingBranches.blockedUntrackedPath, kind: .untracked),
                RepositoryChange(path: UITestingBranches.blockedModifiedPath, kind: .modified),
            ],
            totalCommitCount: 12,
            gitObjectSize: 4_096,
            configuration: configuration(at: url)
        )
    }

    /// A Repository with remotes worth fetching: a remote branch a Fetch can add to, a stale one
    /// only a Fetch Remotes removes, a tag a Fetch Tags can add to, and no Conflict or active
    /// operation in the way.
    private static func fetchState(at url: URL, arguments: [String]) -> RepositorySnapshot {
        RepositorySnapshot(
            name: url.lastPathComponent,
            rootURL: url,
            gitDirectoryURL: url.appending(path: ".git"),
            head: .branch("main"),
            headCommit: RepositoryHeadCommit(
                objectID: "ui-fetch-head",
                summary: "Fixture commit"
            ),
            upstream: RepositoryUpstream(name: "origin/main", ahead: 1, behind: 0),
            remotes: UITestingFetch.remotes(arguments: arguments),
            localBranches: ["main"],
            remoteBranches: ["origin/main", UITestingFetch.staleRemoteBranch],
            tags: [UITestingFetch.conflictingTag],
            totalCommitCount: 12,
            gitObjectSize: 4_096,
            configuration: configuration(at: url)
        )
    }

    /// One Change per Diff case the pane has to handle, so a single launch can walk all of them.
    private static func diffState(at url: URL) -> RepositorySnapshot {
        RepositorySnapshot(
            name: url.lastPathComponent,
            rootURL: url,
            gitDirectoryURL: url.appending(path: ".git"),
            head: .branch("main"),
            headCommit: RepositoryHeadCommit(
                objectID: "ui-diff-head",
                summary: "Fixture commit",
                body: ""
            ),
            localBranches: ["main"],
            stagedChanges: [
                RepositoryChange(
                    path: UITestingDiffs.renamedPath,
                    kind: .renamed(from: UITestingDiffs.originalPath)
                ),
            ],
            unstagedChanges: [
                RepositoryChange(path: UITestingDiffs.binaryPath, kind: .modified),
                RepositoryChange(path: UITestingDiffs.textPath, kind: .modified),
                RepositoryChange(path: UITestingDiffs.beyondLimitPath, kind: .modified),
                RepositoryChange(path: UITestingDiffs.deletedBeyondLimitPath, kind: .deleted),
                RepositoryChange(path: UITestingDiffs.confirmationPath, kind: .modified),
                RepositoryChange(path: UITestingDiffs.slowPath, kind: .modified),
                RepositoryChange(path: UITestingDiffs.submodulePath, kind: .modified),
            ],
            totalCommitCount: 12,
            gitObjectSize: 4_096,
            configuration: configuration(at: url)
        )
    }

    private static func operation(arguments: [String]) -> RepositoryOperation {
        if arguments.contains(UITestingArgument.rebase) {
            .rebase
        } else if arguments.contains(UITestingArgument.am) {
            .am
        } else if arguments.contains(UITestingArgument.cherryPick) {
            .cherryPick
        } else if arguments.contains(UITestingArgument.revert) {
            .revert
        } else {
            .merge
        }
    }

    private static func activeOperation(arguments: [String]) -> RepositoryOperation? {
        let operationArguments = [
            UITestingArgument.rebase,
            UITestingArgument.am,
            UITestingArgument.cherryPick,
            UITestingArgument.revert,
        ]
        guard operationArguments.contains(where: { arguments.contains($0) }) else {
            return nil
        }
        return operation(arguments: arguments)
    }
}
#endif
