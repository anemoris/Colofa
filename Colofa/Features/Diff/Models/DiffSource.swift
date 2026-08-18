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
    /// What one Commit changed, compared against `parentObjectID`.
    ///
    /// The parent is carried rather than spelled `^`: a root Commit has none, and so does the
    /// boundary Commit of a shallow Repository, where Git reports no parent because it does not
    /// have the one that exists.
    ///
    /// `paths` narrows the comparison to one file the way a Change does, so reading a Commit
    /// costs one file rather than all of them and a size limit is reached by a file rather than
    /// by a Commit. Empty means the whole Commit, which is what counting its changed files needs.
    case commit(objectID: String, parentObjectID: String?, paths: [String] = [])

    /// The path the comparison is about, or `nil` when it is about more than one. A rename lists
    /// its old path too, but the change is still about where the file now is.
    var path: String? {
        switch self {
        case .index(let paths), .workingTree(let paths), .commit(_, _, let paths): paths.first
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
