////
//  HistoryPage.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// One page of reachable History, asked for by position rather than by cursor.
///
/// A cursor would have to be a Commit, and resuming a topological walk from a Commit changes
/// which side branches are still pending — the second page would silently lose them. Skipping
/// from the same starting Ref keeps every page part of one walk.
nonisolated struct HistoryPageRequest: Equatable, Sendable {
    /// How many Commits a page holds. The first read and every Load More use the same size.
    static let standardPageSize = 200

    let repositoryURL: URL
    let reference: GitReference
    /// The Commit this walk starts at, pinned when the first page resolved the Ref.
    ///
    /// A Ref is not a fixed starting point: a Fetch, a Commit, or a reset moves it while the user
    /// is paging, and `--skip` counted against a Ref that moved backwards steps straight over
    /// Commits that were never shown. `nil` on the first page, which is the read that resolves
    /// the Ref in the first place.
    let tipObjectID: String?
    /// Which walk to read. Skipping is counted in the walk being asked for, so an offset from one
    /// scope means nothing in the other.
    let scope: HistoryScope
    /// How many Commits Git already reported for this Ref, which is what it is asked to skip.
    let offset: Int
    let pageSize: Int
    /// Every remote-tracking branch the Repository reports, so a decoration such as
    /// `origin/main` is classified by what actually exists rather than by guessing at a slash.
    let remoteBranchNames: Set<String>

    init(
        repositoryURL: URL,
        reference: GitReference,
        scope: HistoryScope = .reachable,
        offset: Int = 0,
        pageSize: Int = HistoryPageRequest.standardPageSize,
        remoteBranchNames: Set<String> = [],
        tipObjectID: String? = nil
    ) {
        self.repositoryURL = repositoryURL
        self.reference = reference
        self.scope = scope
        self.offset = offset
        self.pageSize = pageSize
        self.remoteBranchNames = remoteBranchNames
        self.tipObjectID = tipObjectID
    }

    /// What Git is asked to walk from: the pinned Commit once there is one, and the Ref itself on
    /// the read that establishes it.
    var revision: String {
        tipObjectID ?? reference.revision
    }
}

nonisolated struct HistoryPage: Equatable, Sendable {
    let commits: [HistoryCommit]
    /// Whether Git reported at least one Commit past this page. Read from one extra record Git
    /// was asked for and Colofa dropped, so Load More is offered only when there is something to
    /// load.
    let hasMore: Bool
}
