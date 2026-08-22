////
//  CheckoutComparison.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Which paths a Checkout would rewrite, as Git's own name-status walk reports them.
///
/// Read only after Git has already refused a Checkout, so that a refusal can name the work it
/// protected. Git decides whether the Checkout happens; this decides nothing.
nonisolated struct CheckoutComparison: Equatable, Sendable {
    /// Every path whose content differs between HEAD and the target Ref.
    let changedPaths: Set<String>

    /// The paths the target Ref holds and HEAD does not, which are the ones an untracked file of
    /// the same name stands in the way of.
    let addedPaths: Set<String>

    static let empty = Self(changedPaths: [], addedPaths: [])
}

nonisolated struct CheckoutComparisonRequest: Equatable, Sendable {
    let repositoryURL: URL

    /// What the working tree would move to.
    let revision: String

    /// Whether HEAD names a Commit. An Unborn Branch has nothing to compare against, so every
    /// path the Ref holds is one the Checkout would add.
    let hasHeadCommit: Bool
}
