////
//  PullDivergence.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// A current Branch and its upstream that have each moved on, which is the one thing a
/// fast-forward can never resolve.
///
/// Read only after the Fetch half of a Pull has already answered and the fast-forward has already
/// been refused, from the counts Git reported in the reload that followed. So it explains a
/// refusal rather than deciding one, and the numbers it quotes are the ones the status bar is
/// showing at that moment rather than ones scraped out of a translated message.
nonisolated struct PullDivergence: Equatable, Sendable {
    let branch: String
    let upstream: String

    /// Commits the Branch has and its upstream does not.
    let ahead: Int

    /// Commits the upstream has and the Branch does not.
    let behind: Int

    /// The divergence `repository` reports, or `nil` when its Branch and upstream still share one
    /// line of History.
    ///
    /// Both counts have to be non-zero. A Branch that is only behind is one a fast-forward
    /// handles, and a Branch that is only ahead has nothing to pull; neither is what stopped this
    /// Pull, and saying so would explain the wrong refusal.
    static func evaluate(in repository: RepositorySnapshot) -> Self? {
        guard case .branch(let branch) = repository.head,
              let upstream = repository.upstream,
              upstream.ahead > 0, upstream.behind > 0 else {
            return nil
        }
        return Self(
            branch: branch,
            upstream: upstream.name,
            ahead: upstream.ahead,
            behind: upstream.behind
        )
    }

    var title: LocalizedStringResource {
        .pullDivergedTitle(branch, upstream)
    }

    /// What happened, in the counts the user can already see, and what to do about it.
    ///
    /// Merge and Rebase are named rather than offered: which one to use is the integration policy
    /// this Pull deliberately refused to choose on the user's behalf.
    var message: LocalizedStringResource {
        .pullDivergedDescription(
            branch,
            ahead.formatted(.number),
            upstream,
            behind.formatted(.number)
        )
    }
}
