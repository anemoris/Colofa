////
//  GitReference.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// A Ref whose reachable History can be read.
///
/// Selecting one is inspection, not Checkout: it never moves HEAD and never touches the working
/// tree, which is why the Ref lives in workspace state rather than in the Repository snapshot.
nonisolated enum GitReference: Hashable, Sendable {
    /// Whatever HEAD points at, which is a branch, an Unborn Branch, or a Detached HEAD.
    case head
    case localBranch(String)
    case remoteBranch(String)
    case tag(String)

    /// What Git is asked to walk from.
    ///
    /// Every named Ref is spelled in full, because a short name is ambiguous the moment a branch
    /// and a tag share it and Git resolves that ambiguity by a precedence rule the user never
    /// chose.
    var revision: String {
        switch self {
        case .head: "HEAD"
        case .localBranch(let name): "refs/heads/\(name)"
        case .remoteBranch(let name): "refs/remotes/\(name)"
        case .tag(let name): "refs/tags/\(name)"
        }
    }

    /// The Ref's own name, or `nil` for HEAD, which names whatever it currently points at rather
    /// than naming itself.
    var name: String? {
        switch self {
        case .head: nil
        case .localBranch(let name), .remoteBranch(let name), .tag(let name): name
        }
    }

    /// The branch name Copy Branch Name copies, which a tag does not have.
    var branchName: String? {
        switch self {
        case .head, .tag: nil
        case .localBranch(let name), .remoteBranch(let name): name
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .head: "repository.ref.head"
        case .localBranch(let name): "repository.ref.local.\(name)"
        case .remoteBranch(let name): "repository.ref.remote.\(name)"
        case .tag(let name): "repository.ref.tag.\(name)"
        }
    }

    /// Whether `references` still reports this Ref, which is what a reload has to establish
    /// before keeping a selection that was made against the previous read.
    func exists(in references: RepositoryReferences) -> Bool {
        switch self {
        case .head: true
        case .localBranch(let name): references.localBranches.contains(name)
        case .remoteBranch(let name): references.remoteBranches.contains(name)
        case .tag(let name): references.tags.contains(name)
        }
    }
}
