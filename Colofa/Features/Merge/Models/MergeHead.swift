////
//  MergeHead.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What an unfinished Merge is bringing in, read from Git's own `MERGE_HEAD`.
///
/// It is Repository state rather than something the Merge that started it remembers: a Conflict
/// outlives the command, the window, and the app, and a user who opens Colofa onto a Repository
/// somebody else left mid-merge has to see the same labels as one who started it here.
nonisolated struct MergeHead: Equatable, Sendable {
    /// The Branch that points at the merged Commit, or `nil` when no Branch does.
    let branch: String?

    /// The abbreviated object ID, which labels the merge when no Branch names it.
    let objectID: String

    /// The real name this side of a Conflict is offered under: a Branch when Git has one, and
    /// otherwise the Commit itself. Never "theirs".
    var label: String { branch ?? objectID }
}
