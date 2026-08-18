////
//  UITestingHistory.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// The History UI tests read: deterministic Commits, long enough to page, with a merge, Ref
/// decorations, and a shallow boundary at the end.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `UITestingRepositoryService` builds these from an actor.
nonisolated enum UITestingHistory {
    /// More than one standard page, so Load More has something to append and its boundary is
    /// somewhere a test can actually reach.
    static let mainCommitCount = 250

    /// The one Commit that is only reachable through the merge's second parent, so the two walks
    /// really do answer differently.
    static let sideBranchIndex = 1

    static func page(for request: HistoryPageRequest) -> HistoryPage {
        let commits = self.commits(for: request.reference, scope: request.scope)
        guard request.offset < commits.count else {
            return HistoryPage(commits: [], hasMore: false)
        }
        let end = min(request.offset + request.pageSize, commits.count)
        return HistoryPage(
            commits: Array(commits[request.offset..<end]),
            hasMore: end < commits.count
        )
    }

    static func detail(for request: HistoryCommitDetailRequest) -> HistoryCommitDetail {
        HistoryCommitDetail(
            objectID: request.objectID,
            message: "\(summary(of: request.objectID))\n\nFixture body for the selected commit.\n",
            // Two paths whose patches differ, so selecting one really does change the Diff.
            changedFiles: [
                DiffFileSummary(
                    oldPath: nil,
                    newPath: UITestingDiffs.textPath,
                    stats: DiffStats(additions: 2, deletions: 1)
                ),
                DiffFileSummary(
                    oldPath: UITestingDiffs.originalPath,
                    newPath: UITestingDiffs.renamedPath,
                    stats: DiffStats(additions: 1, deletions: 1)
                ),
            ]
        )
    }

    static func commits(
        for reference: GitReference,
        scope: HistoryScope = .reachable
    ) -> [HistoryCommit] {
        switch reference {
        case .head, .localBranch("main"):
            (0..<mainCommitCount)
                .filter { scope == .reachable || $0 != sideBranchIndex }
                .map(mainCommit(at:))
        case .localBranch(let name):
            named(name, prefix: UITestingCommitID.branchPrefix, count: 3)
        case .remoteBranch(let name):
            named(name, prefix: UITestingCommitID.remotePrefix, count: 4)
        case .tag(let name):
            named(name, prefix: UITestingCommitID.tagPrefix, count: 5)
        }
    }

    private static func mainCommit(at index: Int) -> HistoryCommit {
        commit(
            objectID(index),
            index: index,
            summary: "Fixture commit \(index)",
            // The newest Commit is a merge, and the oldest is where this shallow clone stops.
            parents: mainParents(at: index),
            refLabels: index == 0 ? mainRefLabels : [],
            isShallowBoundary: index == mainCommitCount - 1
        )
    }

    /// The newest Commit is a merge whose first parent continues the Ref's own line and whose
    /// second parent is the side branch, so `--first-parent` reaches everything except that one
    /// Commit.
    private static func mainParents(at index: Int) -> [String] {
        switch index {
        case mainCommitCount - 1: []
        case 0: [objectID(2), objectID(sideBranchIndex)]
        case sideBranchIndex: [objectID(3)]
        default: [objectID(index + 1)]
        }
    }

    private static func named(
        _ name: String,
        prefix: String,
        count: Int
    ) -> [HistoryCommit] {
        (0..<count).map { index in
            commit(
                UITestingCommitID.objectID(prefix: prefix, index: index),
                index: index,
                summary: "\(name) commit \(index)",
                parents: [UITestingCommitID.objectID(prefix: prefix, index: index + 1)],
                refLabels: index == 0
                    ? [HistoryRefLabel(name: name, kind: .localBranch)]
                    : []
            )
        }
    }

    private static func commit(
        _ objectID: String,
        index: Int,
        summary: String,
        parents: [String],
        refLabels: [HistoryRefLabel] = [],
        isShallowBoundary: Bool = false
    ) -> HistoryCommit {
        HistoryCommit(
            objectID: objectID,
            abbreviatedObjectID: String(objectID.prefix(7)),
            parentObjectIDs: parents,
            summary: summary,
            authorName: "Colofa Fixture",
            authorEmail: "fixture@example.invalid",
            authoredDate: date(at: index),
            committerName: "Colofa Fixture",
            committerEmail: "fixture@example.invalid",
            committedDate: date(at: index),
            refLabels: refLabels,
            isShallowBoundary: isShallowBoundary
        )
    }

    /// The Commit's own Summary, so the detail pane never contradicts the row that opened it.
    private static func summary(of objectID: String) -> String {
        for reference in fixtureReferences {
            if let commit = commits(for: reference).first(where: { $0.objectID == objectID }) {
                return commit.summary
            }
        }
        return "Fixture commit"
    }

    private static func objectID(_ index: Int) -> String {
        UITestingCommitID.objectID(prefix: UITestingCommitID.mainPrefix, index: index)
    }

    private static func date(at index: Int) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000 - TimeInterval(index * 3_600))
    }

    private static let mainRefLabels = [
        HistoryRefLabel(name: "HEAD", kind: .head),
        HistoryRefLabel(name: "main", kind: .localBranch),
        HistoryRefLabel(name: "origin/main", kind: .remoteBranch),
    ]

    /// Every Ref the fixture Repository reports, which is what a Commit's message is looked up
    /// across.
    private static let fixtureReferences: [GitReference] = [
        .head,
        .localBranch("feature/真实"),
        .remoteBranch("origin/main"),
        .tag("v1.0-测试"),
    ]
}
#endif
