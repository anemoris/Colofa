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

    /// The Commit the first page started at, which every later page is skipped from.
    ///
    /// The offset alone is not enough to keep the pages one walk. It is counted against whatever
    /// the Ref points at when the next page is asked for, so a Ref that moved backwards makes
    /// `--skip` step over Commits that were never shown — and dropping duplicates cannot put back
    /// something that was never reported. Pinning the starting Commit is what makes every page
    /// part of the walk the first one began. A reload builds a new timeline and pins again, so a
    /// moved Ref is picked up by refreshing rather than in the middle of paging.
    private(set) var tipObjectID: String?

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
        // The first record Git reported for this walk is the Commit it started at. Taken from the
        // page rather than read separately: it is the same resolution the page itself used, so
        // the two cannot disagree.
        if tipObjectID == nil {
            tipObjectID = page.commits.first?.objectID
        }
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
