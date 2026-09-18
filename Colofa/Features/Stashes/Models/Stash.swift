////
//  Stash.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// One entry Git holds in the Stash reflog.
///
/// A Stash is a real Commit, and Git records the state it was saved from as that Commit's
/// parents: the Commit the working tree was on, the index at the time, and — only when untracked
/// files were included — a Commit holding those. Colofa carries all three rather than re-deriving
/// them from `stash@{n}^1`, so a Diff read after the list moved still compares the objects the
/// row was built from.
nonisolated struct Stash: Equatable, Identifiable, Sendable {
    /// How Git addresses this entry: `stash@{0}`, `stash@{1}`, and so on.
    ///
    /// A position in the reflog rather than a name. Creating or dropping a Stash renumbers every
    /// entry after it, which is why the object IDs travel with the row.
    let selector: String

    let objectID: String

    /// The short form Git itself chose. Colofa never abbreviates a SHA on its own.
    let abbreviatedObjectID: String

    /// The Commit the working tree was on when the Stash was saved, which is what its content is
    /// compared against.
    let baseObjectID: String

    /// The Commit holding the untracked files this Stash saved, or `nil` when it saved none.
    ///
    /// Git keeps them outside the Stash's own tree, so a Stash created with Include Untracked
    /// Files is the only one that has a third parent at all — which is also how Colofa knows one
    /// was created that way.
    let untrackedObjectID: String?

    /// Git's own description of the entry, such as `On main: fixing the parser`, or the
    /// `WIP on main: 8b238e6 Initial commit` it writes when no message was given.
    ///
    /// Shown as Git wrote it. The branch prefix is Git's, not decoration Colofa added, and
    /// trimming it would claim the entry says something it does not.
    let message: String

    let authorName: String
    let authorEmail: String
    let authoredDate: Date

    var id: String { selector }

    /// Whether this Stash saved files Git was not tracking at the time.
    var includesUntrackedFiles: Bool { untrackedObjectID != nil }

    /// Which comparison one of this Stash's saved paths is read as.
    ///
    /// A tracked change is compared against the Commit the Stash was saved on. An untracked file
    /// lives in a Commit of its own with no parent, so it is read the way a root Commit is:
    /// everything that Commit introduced, narrowed to the one path.
    ///
    /// `nil` for an untracked file on a Stash that saved none, which is a pairing that cannot
    /// come from one read.
    func diffSource(of file: StashFile) -> DiffSource? {
        guard file.isUntracked else {
            return .commit(
                objectID: objectID,
                parentObjectID: baseObjectID,
                paths: file.summary.gitPathspecs
            )
        }
        guard let untrackedObjectID else {
            return nil
        }
        return .commit(
            objectID: untrackedObjectID,
            parentObjectID: nil,
            paths: file.summary.gitPathspecs
        )
    }

    func detailRequest(in repositoryURL: URL) -> StashDetailRequest {
        StashDetailRequest(
            repositoryURL: repositoryURL,
            objectID: objectID,
            baseObjectID: baseObjectID,
            untrackedObjectID: untrackedObjectID
        )
    }
}
