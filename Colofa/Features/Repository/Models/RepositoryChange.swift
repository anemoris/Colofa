////
//  RepositoryChange.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

struct RepositoryChange: Equatable, Identifiable, Sendable {
    let path: String
    let kind: RepositoryChangeKind

    /// Whether the path is a submodule, which is what `git status` reports in the `S` of its
    /// submodule field.
    ///
    /// Kept because Git treats a submodule unlike any other path: `git stash push` does not count
    /// a submodule's change — not its moved Commit, not its own dirty working tree, not even a
    /// Staged move — as something to save.
    let isSubmodule: Bool

    nonisolated init(path: String, kind: RepositoryChangeKind, isSubmodule: Bool = false) {
        self.path = path
        self.kind = kind
        self.isSubmodule = isSubmodule
    }

    var id: String { path }

    nonisolated var gitPathspecs: [String] {
        if case .renamed(let originalPath) = kind {
            [path, originalPath]
        } else {
            [path]
        }
    }

    nonisolated var isConflict: Bool {
        if case .conflict = kind {
            true
        } else {
            false
        }
    }

    /// Whether Git has never recorded this path, which is what makes removing it a Move to Trash
    /// rather than something Git could restore.
    nonisolated var isUntracked: Bool {
        if case .untracked = kind {
            true
        } else {
            false
        }
    }
}
