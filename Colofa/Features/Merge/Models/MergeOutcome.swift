////
//  MergeOutcome.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What one Merge actually did.
///
/// A Conflict is its own answer rather than a failure. Git ends a conflicted merge with a
/// non-zero status, but nothing went wrong: the Repository is in the state the user now works
/// in, and reporting it as an error would put an alert over the very list they have to act on.
nonisolated enum MergeOutcome: Equatable, Sendable {
    /// Git integrated the Branch, whether by fast-forward or by a merge Commit.
    case merged

    /// Git left an unfinished merge with unmerged paths in it.
    case conflicted

    /// Nothing ran: there is no Repository, or another command already holds it.
    case unavailable

    case failed(RepositoryOpenError)
}
