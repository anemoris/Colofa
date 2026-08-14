////
//  DiffFile.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Everything one patch says about one path.
///
/// The content is a closed set of the things Git actually reports, so a view never has to infer
/// what it is looking at from display text: a binary change carries no lines to fabricate, and a
/// submodule change carries the two Commits it moved between rather than the sentence Git prints
/// about them.
nonisolated struct DiffFile: Equatable, Identifiable, Sendable {
    enum Content: Equatable, Sendable {
        case text([DiffHunk])
        case binary
        case submodule(oldCommitID: String?, newCommitID: String?)
    }

    /// The path before the change, absent when the file was added.
    let oldPath: String?
    /// The path after the change, absent when the file was deleted.
    let newPath: String?
    /// Git's file modes, kept verbatim because `160000` is what identifies a submodule and
    /// `100755` versus `100644` is a real change with no lines to show for it.
    let oldMode: String?
    let newMode: String?
    let content: Content
    let stats: DiffStats

    init(
        oldPath: String?,
        newPath: String?,
        oldMode: String? = nil,
        newMode: String? = nil,
        content: Content
    ) {
        self.oldPath = oldPath
        self.newPath = newPath
        self.oldMode = oldMode
        self.newMode = newMode
        self.content = content
        stats = switch content {
        case .text(let hunks):
            hunks.reduce(.zero) { $0 + $1.stats }
        case .binary, .submodule:
            .zero
        }
    }

    var id: String { "\(oldPath ?? "")\u{0}\(newPath ?? "")" }

    /// The path to show as the file's own, preferring where it now is.
    var displayPath: String { newPath ?? oldPath ?? "" }

    var isRenamed: Bool {
        guard let oldPath, let newPath else {
            return false
        }
        return oldPath != newPath
    }

    /// A mode change Git reports on its own, such as a file becoming executable. Excluded when
    /// the file was added or deleted, where a single mode is a fact rather than a change.
    var changedMode: (old: String, new: String)? {
        guard oldPath != nil, newPath != nil,
              let oldMode, let newMode, oldMode != newMode else {
            return nil
        }
        return (oldMode, newMode)
    }

    var hunks: [DiffHunk] {
        if case .text(let hunks) = content {
            hunks
        } else {
            []
        }
    }
}
