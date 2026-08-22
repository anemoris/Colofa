////
//  UITestingArgument.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
/// Launch arguments that switch the app into a deterministic UI-testing configuration.
///
/// This file is compiled into both the app and UI test targets, keeping both processes on the
/// same launch-argument contract.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `UITestingRepositoryService` reads these values from an actor.
nonisolated enum UITestingArgument {
    /// Enables UI-testing behavior such as skipping Repository restoration and picker presentation.
    static let enabled = "--ui-testing"

    /// Reports Git as unavailable so the unavailable-state UI can be asserted.
    static let gitUnavailable = "--ui-testing-git-unavailable"

    /// Substitutes the stubbed Repository service for the live one.
    static let repositoryService = "--ui-testing-repository-service"

    /// Makes the stubbed service refuse the selected Repository as bare.
    static let bareRepository = "--ui-testing-bare-repository"

    /// Makes every stubbed mutation fail so error presentation can be asserted.
    static let stageFailure = "--ui-testing-stage-failure"

    /// Serves a fully populated snapshot instead of an empty, unborn-branch Repository.
    static let realRepositoryState = "--ui-testing-real-repository-state"

    /// Serves a Repository that can actually be committed: Staged Changes, a configured identity,
    /// a published HEAD to amend, and no Conflict or active operation in the way.
    static let committableState = "--ui-testing-committable-state"

    /// Removes all working-tree changes so the collapsed clean-workspace Amend affordance appears.
    static let cleanCommitState = "--ui-testing-clean-commit-state"

    /// Serves a Repository with local branches, remote branches, and a tag, and no Conflict or
    /// active operation standing in the way of a Checkout.
    static let branchState = "--ui-testing-branch-state"

    /// Makes every Checkout fail the way Git refuses one that would overwrite local work.
    static let checkoutBlocked = "--ui-testing-checkout-blocked"

    /// Serves the Changes whose Diffs cover text, rename, binary, submodule, and both size limits.
    static let diffState = "--ui-testing-diff-state"

    /// Serves an unresolved Conflict without an active operation.
    static let commitConflict = "--ui-testing-commit-conflict"

    /// Removes the effective Commit identity.
    static let missingCommitIdentity = "--ui-testing-missing-commit-identity"

    /// Serves a staged first Commit on an Unborn Branch.
    static let unbornCommitState = "--ui-testing-unborn-commit-state"

    /// Makes Commit fail as though a configured Hook rejected it.
    static let commitHookFailure = "--ui-testing-commit-hook-failure"

    /// Makes Commit fail as though configured signing rejected it.
    static let commitSigningFailure = "--ui-testing-commit-signing-failure"

    /// Reports HEAD as detached rather than on a branch.
    static let detachedHead = "--ui-testing-detached-head"

    /// Serves remote branches without any configured remote.
    static let remoteBranchesOnly = "--ui-testing-remote-branches-only"

    /// Reports an in-progress rebase.
    static let rebase = "--ui-testing-rebase"

    /// Reports an in-progress `git am`.
    static let am = "--ui-testing-am"

    /// Reports an in-progress cherry-pick.
    static let cherryPick = "--ui-testing-cherry-pick"

    /// Reports an in-progress revert.
    static let revert = "--ui-testing-revert"

    /// Seeds the app's `lastRepositoryPath` default, which drives Repository restoration.
    /// Unlike the flags above this is a `UserDefaults` argument and takes a following value.
    static let lastRepositoryPath = "-lastRepositoryPath"
}
#endif
