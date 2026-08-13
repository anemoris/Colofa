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
}
