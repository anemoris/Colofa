////
//  MergeDraft.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The open Merge confirmation: which Branch comes in, what it comes into, and under which of
/// Git's three policies.
///
/// Both names are captured when the dialog opens, so the confirmation always says the direction
/// the user agreed to rather than re-deriving it from a Repository that may have been read again
/// underneath it.
nonisolated struct MergeDraft: Equatable, Sendable {
    let source: MergeSource

    /// What the merge lands on: the current Branch's name, or the Commit a Detached HEAD is at.
    let target: String

    var strategy = MergeStrategy.preselected

    var arguments: [String] {
        strategy.arguments(merging: source)
    }
}
