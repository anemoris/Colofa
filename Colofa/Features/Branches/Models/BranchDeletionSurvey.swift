////
//  BranchDeletionSurvey.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What Git says about one local Branch a Delete would remove.
///
/// Read from Git rather than from a Repository snapshot, because a snapshot carries the Branch's
/// name and nothing about what only that Branch holds. Both values are read again immediately
/// before the Branch is removed: a confirmation describes a Ref at one moment, and a Ref that
/// moved since is no longer the Ref the user agreed to delete.
nonisolated struct BranchDeletionSurvey: Equatable, Sendable {
    /// The Commit the Branch points at.
    let objectID: String

    /// How many Commits are reachable from this Branch and from no other Ref.
    ///
    /// This is exactly what a forced Delete would leave unreachable, which is why it is the
    /// number the confirmation shows. A Commit that another Branch, a tag, or a Remote-tracking
    /// Branch also holds is not lost by removing this one, so it is not counted here.
    let uniqueCommitCount: Int

    /// Whether removing the Branch would leave History nothing else reaches.
    ///
    /// Git's own safe deletion asks a narrower question — whether the Branch is merged into HEAD
    /// or into its upstream — so a Branch it refuses can still be one this reports as holding
    /// nothing unique. Both answers are used: this one decides what the confirmation says before
    /// anything runs, and Git's decides whether the safe command succeeds.
    var holdsUniqueCommits: Bool { uniqueCommitCount > 0 }
}

nonisolated struct BranchDeletionRequest: Equatable, Sendable {
    let repositoryURL: URL

    /// The local Branch's own name, without `refs/heads/`.
    let name: String
}
