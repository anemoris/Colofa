////
//  PullCommand.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The two commands a Pull runs, kept in one place so what Colofa asks Git for can be read — and
/// tested — without reading the Store.
///
/// A Pull is deliberately not `git pull`. That one command decides for itself whether to merge or
/// rebase, reads `pull.rebase` and `pull.ff` to do it, and reports one exit status for two very
/// different phases. Colofa runs the phases itself instead: a Fetch that contacts the remote and
/// can be stopped, then a fast-forward that cannot. Splitting them is what lets a refusal say
/// which half refused — a remote that never answered is not a Branch that could not be advanced.
nonisolated enum PullCommand {

    /// The Fetch half, which contacts exactly the remote Git resolves for the current Branch.
    ///
    /// No remote is named on purpose. Given a Branch with an upstream, Git contacts that Branch's
    /// own remote, which is the remote a Pull is about; naming one would mean splitting a remote
    /// name back out of an upstream and getting it wrong wherever a slash appears in either half.
    /// No option is added either: the remote's configured refspec, tag, and prune behavior decide
    /// what arrives, exactly as it does for Fetch.
    static let fetch = ["fetch"]

    /// The integration half: advance the current Branch to its upstream, or refuse.
    ///
    /// Every part of this is a refusal spelled out rather than assumed. `--ff-only` is what makes
    /// divergence an error instead of a merge commit, and it overrules a configured `pull.ff` or
    /// `merge.ff`. `--no-autostash` is there because `merge.autoStash` is a configuration Colofa
    /// would otherwise inherit: with it set, Git stashes the working tree, fast-forwards, and
    /// re-applies — which can end in a conflicted tree the user never asked for. `--` keeps the
    /// revision out of Git's option parser.
    ///
    /// The revision is resolved by Git when the command runs rather than read from a snapshot
    /// that could have gone stale.
    static let fastForward = ["merge", "--ff-only", "--no-autostash", "--", upstreamRevision]

    /// Git's own name for the current Branch's upstream, which is both what the fast-forward
    /// moves to and what the read explaining a refusal compares the working tree against.
    static let upstreamRevision = "@{upstream}"
}
