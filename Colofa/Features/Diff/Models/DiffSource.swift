////
//  DiffSource.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Which comparison a patch is asked for.
///
/// A rename carries both of its paths, because Git only pairs them when both are in the pathspec.
nonisolated enum DiffSource: Hashable, Sendable {
    /// Staged content, compared against HEAD.
    case index(paths: [String])
    /// Working-tree content, compared against the index.
    case workingTree(paths: [String])
    /// A path Git does not track yet, compared against nothing.
    case untracked(path: String)

    /// The path the comparison is about. A rename lists its old path too, but the change is
    /// still about where the file now is.
    var path: String {
        switch self {
        case .index(let paths), .workingTree(let paths): paths.first ?? ""
        case .untracked(let path): path
        }
    }

    init(change: RepositoryChange, isStaged: Bool) {
        if case .untracked = change.kind {
            self = .untracked(path: change.path)
        } else if isStaged {
            self = .index(paths: change.gitPathspecs)
        } else {
            self = .workingTree(paths: change.gitPathspecs)
        }
    }
}
