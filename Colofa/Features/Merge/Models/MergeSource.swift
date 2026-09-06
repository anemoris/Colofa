////
//  MergeSource.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The Branch one Merge brings in: what the confirmation names, and what Git is asked to merge.
///
/// Only a named Branch resolves to one. A tag deliberately does not: merging a tag is not the
/// everyday workflow this app is about. HEAD does not either, because HEAD is a position rather
/// than a name — the Store resolves it to the Branch it is on, so that merging that Branch into
/// itself is refused under the name the user is looking at.
nonisolated struct MergeSource: Equatable, Sendable {
    /// The Ref's own name, which is what the confirmation and the Conflict labels show.
    let name: String

    /// What Git is asked to merge, spelled in full.
    ///
    /// A short name is ambiguous the moment a tag shares it — Git resolves `feature` to
    /// `refs/tags/feature` before `refs/heads/feature` — and merging a tag the user never chose
    /// is exactly the mistake `CheckoutTarget` spells refs in full to avoid.
    let revision: String

    /// Whether this is a Remote-tracking Branch, which only the Commit message distinguishes.
    let isRemote: Bool

    /// The message the merge Commit carries.
    ///
    /// Written here rather than left to Git because the revision handed over is a full refname,
    /// and Git would record that verbatim: `Merge branch 'refs/heads/feature'`. This is Git's own
    /// wording with the name the user actually chose in it. It is Repository content rather than
    /// interface copy, so it is not localized — a Commit message reads the same in every clone.
    var commitMessage: String {
        isRemote ? "Merge remote-tracking branch '\(name)'" : "Merge branch '\(name)'"
    }

    /// The Branch `reference` names, or `nil` for a Ref that is not one Colofa merges.
    static func resolve(_ reference: GitReference) -> Self? {
        switch reference {
        case .head, .tag:
            nil
        case .localBranch(let name):
            Self(name: name, revision: reference.revision, isRemote: false)
        case .remoteBranch(let name):
            Self(name: name, revision: reference.revision, isRemote: true)
        }
    }
}
