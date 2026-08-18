////
//  HistoryCommit.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// One Commit in a page of History, holding everything a row shows and everything a detail needs
/// before it reads anything further.
///
/// The full message and the changed files are deliberately absent: a page carries 200 of these,
/// and a Commit body has no upper bound. `HistoryCommitDetail` reads those for the one Commit the
/// user selected.
nonisolated struct HistoryCommit: Equatable, Identifiable, Sendable {
    let objectID: String
    /// The short form Git itself chose, which is unique in this Repository at the time it was
    /// read. Colofa never abbreviates a SHA on its own.
    let abbreviatedObjectID: String
    /// Every parent Git reports. Empty for a root Commit, and empty for a Commit at the boundary
    /// of a shallow Repository, where Git deliberately hides the parents it does not have.
    let parentObjectIDs: [String]
    let summary: String
    let authorName: String
    let authorEmail: String
    let authoredDate: Date
    let committerName: String
    let committerEmail: String
    let committedDate: Date
    let refLabels: [HistoryRefLabel]
    /// Whether Git reported this Commit as grafted, which is how a shallow Repository says that
    /// real parents exist but are not present.
    let isShallowBoundary: Bool

    var id: String { objectID }

    var isMerge: Bool { parentObjectIDs.count > 1 }

    /// A Commit with no parent Git will compare against: either the first Commit of the
    /// Repository, or the point a shallow clone stops at.
    var isRoot: Bool { parentObjectIDs.isEmpty && !isShallowBoundary }

    /// What a Diff for this Commit is compared against. `nil` means Git has nothing to compare
    /// with, so the comparison is against an empty tree.
    ///
    /// A merge is compared against its first parent, which is the parent History walked through.
    /// Git's combined Diff of every side is not a comparison a reviewer can act on.
    var comparisonParentObjectID: String? { parentObjectIDs.first }

    var diffSource: DiffSource {
        .commit(objectID: objectID, parentObjectID: comparisonParentObjectID)
    }

    func detailRequest(in repositoryURL: URL) -> HistoryCommitDetailRequest {
        HistoryCommitDetailRequest(
            repositoryURL: repositoryURL,
            objectID: objectID,
            parentObjectID: comparisonParentObjectID
        )
    }
}
