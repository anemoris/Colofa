////
//  CheckoutTarget.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// One explicit Checkout: which Ref the user chose, and the exact command Git is asked to run.
///
/// No command it builds carries `--force`, `--merge`, or a Stash: Colofa refuses a Checkout that
/// would overwrite local work rather than offering a way to overwrite it.
nonisolated struct CheckoutTarget: Equatable, Sendable {
    /// What a refusal names, which is the Ref the working tree would move to.
    let displayName: String

    /// The revision the working tree would move to, which a refusal is measured against.
    let revision: String

    /// The local branch HEAD ends up on, or `nil` when the Checkout detaches HEAD instead.
    let localBranchName: String?

    let arguments: [String]

    /// Whether this Checkout leaves HEAD detached rather than on a branch.
    var detachesHead: Bool { localBranchName == nil }

    /// The command for `reference`, or `nil` for HEAD, which is already checked out.
    static func resolve(
        _ reference: GitReference,
        in repository: RepositorySnapshot
    ) -> Self? {
        switch reference {
        case .head:
            nil
        case .localBranch(let name):
            localBranch(name)
        case .remoteBranch(let name):
            remoteBranch(name, in: repository)
        case .tag(let name):
            Self(
                displayName: name,
                revision: reference.revision,
                localBranchName: nil,
                arguments: ["switch", "--detach", reference.revision]
            )
        }
    }

    private static func localBranch(_ name: String) -> Self {
        Self(
            displayName: name,
            revision: "refs/heads/\(name)",
            localBranchName: name,
            // `--no-guess` keeps Checkout from quietly creating a branch from a remote when the
            // local one named here has since disappeared.
            arguments: ["switch", "--no-guess", "--", name]
        )
    }

    /// A remote branch is checked out as a same-name local tracking branch, so later Pull and
    /// Push have an upstream.
    ///
    /// When that local branch already exists, Checkout switches to it rather than recreating it
    /// from the remote: recreating would move it back and drop whatever it holds that the remote
    /// does not.
    private static func remoteBranch(
        _ name: String,
        in repository: RepositorySnapshot
    ) -> Self {
        let localName = trackingBranchName(for: name, remotes: repository.remotes.map(\.name))
        guard !repository.localBranches.contains(localName) else {
            return localBranch(localName)
        }
        return Self(
            displayName: name,
            revision: "refs/remotes/\(name)",
            localBranchName: localName,
            arguments: [
                "switch", "--track", "--create", localName, "refs/remotes/\(name)",
            ]
        )
    }

    /// The branch name a remote-tracking Ref carries, which is its name without the remote's.
    ///
    /// The configured remotes decide where that name starts: a remote may be named with a slash
    /// in it, so the first path component is only the fallback for a Ref no remote claims.
    static func trackingBranchName(for remoteBranch: String, remotes: [String]) -> String {
        let owner = remotes
            .filter { remoteBranch.hasPrefix("\($0)/") }
            .max { $0.count < $1.count }
        guard let owner else {
            let components = remoteBranch.split(separator: "/", maxSplits: 1)
            return components.count == 2 ? String(components[1]) : remoteBranch
        }
        return String(remoteBranch.dropFirst(owner.count + 1))
    }
}
