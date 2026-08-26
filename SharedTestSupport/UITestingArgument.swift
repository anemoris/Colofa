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

    /// Serves a Repository with two remotes, a remote branch, and a tag, so Fetch and Fetch Tags
    /// have something real to refresh.
    static let fetchState = "--ui-testing-fetch-state"

    /// Leaves the fetch fixture with a single remote, which is the case Fetch Tags answers
    /// without asking.
    static let singleRemote = "--ui-testing-single-remote"

    /// Configures the fixture's second remote as one Git skips when fetching all of them.
    static let skipFetchAll = "--ui-testing-skip-fetch-all"

    /// Makes the fixture's second remote fail, so a partial Fetch can be asserted.
    static let fetchFailure = "--ui-testing-fetch-failure"

    /// Makes every command that contacts a remote block long enough to be cancelled, including
    /// the Fetch half of a Pull.
    static let slowFetch = "--ui-testing-slow-fetch"

    /// Makes Fetch Tags fail the way Git refuses to replace a local tag of the same name.
    static let tagConflict = "--ui-testing-tag-conflict"

    /// Serves a Repository whose current Branch is behind its upstream, so a Pull has something
    /// to fast-forward.
    static let pullState = "--ui-testing-pull-state"

    /// Leaves the pull fixture's current Branch without an upstream, which is the state Pull
    /// explains rather than attempts.
    static let pullNoUpstream = "--ui-testing-pull-no-upstream"

    /// Makes the pull fixture's Fetch reveal local commits the upstream does not have, so the
    /// fast-forward is refused the way Git refuses a divergence.
    static let pullDiverged = "--ui-testing-pull-diverged"

    /// Makes the pull fixture's fast-forward fail the way Git refuses one that would overwrite
    /// local work.
    static let pullBlocked = "--ui-testing-pull-blocked"

    /// Makes the fixture's Fetch ask for an HTTPS account name.
    static let authenticationUsername = "--ui-testing-authentication-username"

    /// Makes the fixture's Fetch ask for an HTTPS password or personal access token.
    static let authenticationPassword = "--ui-testing-authentication-password"

    /// Makes the fixture's Fetch ask for an SSH private key's passphrase.
    static let authenticationPassphrase = "--ui-testing-authentication-passphrase"

    /// Makes the fixture's Fetch ask to confirm a host OpenSSH has never seen.
    static let authenticationHostKey = "--ui-testing-authentication-host-key"

    /// Makes the fixture's Fetch meet a host whose key no longer matches the recorded one.
    static let authenticationHostKeyChanged = "--ui-testing-authentication-host-key-changed"

    /// Makes the fixture's Fetch ask something Colofa cannot classify.
    static let authenticationUnrecognized = "--ui-testing-authentication-unrecognized"

    /// Makes the fixture's Fetch ask an unclassifiable question as long as the channel carries,
    /// which is the size a question Colofa did not write may reach.
    static let authenticationLongPrompt = "--ui-testing-authentication-long-prompt"

    /// Seeds the app's `lastRepositoryPath` default, which drives Repository restoration.
    /// Unlike the flags above this is a `UserDefaults` argument and takes a following value.
    static let lastRepositoryPath = "-lastRepositoryPath"
}
#endif
