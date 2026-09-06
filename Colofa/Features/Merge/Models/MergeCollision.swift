////
//  MergeCollision.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The untracked files a Merge would have written over.
///
/// Git refuses such a Merge on its own and Colofa never overrides that: there is no automatic
/// Stash and nothing that moves a file out of the way. What this adds is the list of paths, so
/// the refusal says which work was protected.
///
/// Only untracked paths appear. Tracked work is refused before the command runs, with Commit or
/// Stash guidance, so listing it here would explain the wrong refusal.
nonisolated struct MergeCollision: Equatable, Sendable {
    let paths: [String]

    /// How many paths a refusal lists before summarizing the rest, matching the limit a refused
    /// Checkout uses: an alert that lists hundreds of paths stops being readable.
    static let listedPathLimit = CheckoutObstruction.listedPathLimit

    var isEmpty: Bool { paths.isEmpty }

    /// Where the paths `comparison` says the merge would add and the Repository's own untracked
    /// files overlap.
    static func evaluate(
        comparison: CheckoutComparison,
        in repository: RepositorySnapshot
    ) -> Self {
        let untrackedPaths = Set(
            repository.unstagedChanges.filter(\.isUntracked).map(\.path)
        )
        return Self(paths: untrackedPaths.intersection(comparison.addedPaths).sorted())
    }

    var message: LocalizedStringResource {
        .mergeBlockedByUntrackedFiles(pathList)
    }

    /// The listed paths, one per line, ending with a count of whatever did not fit.
    var pathList: String {
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
