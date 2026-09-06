////
//  ConflictVersion.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// One of the two complete versions a conflicted path can be restored to.
///
/// Named by side rather than by Git's words on purpose. "Ours" and "theirs" are positions in a
/// command, not things a user recognizes, and they invert during a Rebase; the labels the user
/// reads are real Branch or Commit names, which the Store resolves from the Repository.
///
/// Restoring a version writes the working tree and nothing else. The path stays unmerged until
/// Mark as Resolved stages it, so choosing a side is a decision the user still has to confirm.
nonisolated enum ConflictVersion: CaseIterable, Hashable, Identifiable, Sendable {
    /// What the Branch being merged into already held.
    case current

    /// What the Branch being merged in brings.
    case incoming

    var id: Self { self }

    /// Restores `change` to this version in the working tree.
    func arguments(for change: RepositoryChange) -> [String] {
        ["--literal-pathspecs", "checkout", option, "--"] + change.gitPathspecs
    }

    var accessibilityIdentifier: String {
        switch self {
        case .current: "repository.conflict.useCurrent"
        case .incoming: "repository.conflict.useIncoming"
        }
    }

    /// What this version is called, which is entirely the Ref it names.
    ///
    /// One wording for both sides on purpose: the whole distinction the user needs is the real
    /// Branch or Commit, and a verb that tried to add "current" or "incoming" would put back the
    /// positional language the labels exist to replace.
    func title(_ label: String) -> LocalizedStringResource {
        .conflictUseVersion(label)
    }

    private var option: String {
        switch self {
        case .current: "--ours"
        case .incoming: "--theirs"
        }
    }
}
