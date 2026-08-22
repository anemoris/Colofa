////
//  CheckoutObstruction.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The uncommitted work a Checkout would have overwritten.
///
/// Git refuses such a Checkout on its own and Colofa never overrides that: there is no Force
/// Checkout, no Smart Checkout, and no automatic Stash. What this adds is the list of paths, so
/// the refusal says which work was protected and what to do with it.
nonisolated struct CheckoutObstruction: Equatable, Sendable {
    /// Tracked paths with local changes that the target Ref also changes.
    let modifiedPaths: [String]

    /// Untracked paths the target Ref would write over.
    let untrackedPaths: [String]

    /// How many paths a refusal lists before summarizing the rest. A Checkout can be blocked by
    /// hundreds of paths, and an alert that lists all of them stops being readable.
    static let listedPathLimit = 10

    var isEmpty: Bool {
        modifiedPaths.isEmpty && untrackedPaths.isEmpty
    }

    /// Every affected path, with the tracked ones first: they are the work Git protected, and an
    /// untracked file merely sitting in the way is the easier one to move.
    var paths: [String] {
        modifiedPaths + untrackedPaths
    }

    /// Where `comparison` and the Repository's own Changes overlap.
    ///
    /// A Conflict is deliberately absent: an unmerged path is refused before a Checkout is ever
    /// attempted, so listing it here would explain the wrong refusal.
    static func evaluate(
        comparison: CheckoutComparison,
        in repository: RepositorySnapshot
    ) -> Self {
        var trackedPaths = Set(repository.stagedChanges.flatMap(\.gitPathspecs))
        var untrackedPaths: Set<String> = []
        for change in repository.unstagedChanges where !change.isConflict {
            if case .untracked = change.kind {
                untrackedPaths.insert(change.path)
            } else {
                trackedPaths.formUnion(change.gitPathspecs)
            }
        }

        return Self(
            modifiedPaths: trackedPaths.intersection(comparison.changedPaths).sorted(),
            untrackedPaths: untrackedPaths.intersection(comparison.addedPaths).sorted()
        )
    }

    /// Which paths the Checkout would have overwritten, and what to do with them.
    ///
    /// The guidance differs by what is in the way: committing an untracked file is not what Git
    /// asks for, and stashing one is not what Colofa does on its own.
    var message: LocalizedStringResource {
        if untrackedPaths.isEmpty {
            return .checkoutBlockedByLocalChanges(pathList)
        }
        if modifiedPaths.isEmpty {
            return .checkoutBlockedByUntrackedFiles(pathList)
        }
        return .checkoutBlockedByLocalWork(pathList)
    }

    /// The listed paths, one per line, ending with a count of whatever did not fit.
    var pathList: String {
        let paths = paths
        let listed = paths.prefix(Self.listedPathLimit).joined(separator: "\n")
        guard paths.count > Self.listedPathLimit else {
            return listed
        }
        let remaining = String(
            localized: .checkoutBlockedMorePaths(
                (paths.count - Self.listedPathLimit).formatted(.number)
            )
        )
        return "\(listed)\n\(remaining)"
    }
}
