////
//  StashFile.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// One path a Stash saved, and which of the Stash's two trees holds it.
///
/// The distinction is not cosmetic: a tracked change is a comparison against the Commit the Stash
/// was saved from, while an untracked file lives in a Commit of its own that has no parent at
/// all. Reading either one as the other would compare the wrong pair of objects.
nonisolated struct StashFile: Equatable, Identifiable, Sendable {
    let summary: DiffFileSummary

    /// Whether Git had never recorded this path when the Stash was saved.
    let isUntracked: Bool

    /// The side and the path together. One path can be on both sides of the same Stash — a file
    /// removed from the index with `git rm --cached` but kept and edited on disk is saved as a
    /// tracked change *and* as an untracked file — and each is a different comparison.
    var id: String {
        "\(isUntracked ? "untracked" : "tracked")\u{0}\(summary.id)"
    }
}
