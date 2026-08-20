////
//  HistoryTimeline.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The pages of History loaded so far for one Ref.
///
/// It owns what Load More has to get right — no duplicate rows, no skipped Commits, and an offset
/// that stays aligned with Git's own walk — so those rules are one testable value type rather
/// than something the view and the Store each half-implement.
nonisolated struct HistoryTimeline: Equatable, Sendable {
    private(set) var commits: [HistoryCommit] = []
    private(set) var hasMore = false

    /// How many Commits Git has reported, which is not `commits.count` when a record arrived
    /// twice. Git skips what it walked, so the next page has to be asked for from here or a
    /// Commit would be stepped over.
    private(set) var reportedCount = 0

    /// Set while the next page is being read, so Load More cannot be asked for twice.
    var isLoadingMore = false

    private var loadedObjectIDs: Set<String> = []

    init() {
    }

    init(page: HistoryPage) {
        append(page)
    }

    /// Appends what Git reported, keeping the offset aligned with Git's walk and dropping a
    /// Commit that is already on screen.
    ///
    /// A duplicate can only come from History that moved between two reads. Dropping it keeps the
    /// list truthful about what exists; counting it keeps the next page from skipping past a
    /// Commit that was never shown.
    mutating func append(_ page: HistoryPage) {
        reportedCount += page.commits.count
        hasMore = page.hasMore
        for commit in page.commits {
            guard loadedObjectIDs.insert(commit.objectID).inserted else {
                continue
            }
            commits.append(commit)
        }
    }

    func contains(_ objectID: String) -> Bool {
        loadedObjectIDs.contains(objectID)
    }

    func commit(_ objectID: String) -> HistoryCommit? {
        commits.first { $0.objectID == objectID }
    }
}
