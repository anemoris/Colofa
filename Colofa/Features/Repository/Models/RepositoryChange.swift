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
