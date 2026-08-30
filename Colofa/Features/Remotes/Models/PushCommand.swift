////
//  PushCommand.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Everything Colofa asks Git in order to publish or push one Branch, kept in one place so what
/// leaves for a remote can be read — and tested — without reading the Store.
///
/// Two things are spelled out rather than assumed. The refspec is always explicit, so `push.default`
/// cannot decide for itself which Ref travels or where it lands: what the confirmation showed is
/// what is pushed. And force exists here in exactly one form — a lease naming an exact expected
/// object — because there is no argument in this file that produces a naked `--force`.
nonisolated enum PushCommand {

    /// Options every Push carries, whatever it is for.
    ///
    /// `--porcelain` is what makes a refusal readable: Git reports each Ref's fate in a fixed,
    /// untranslated line, so Push Rejected can be told apart from a remote that refused for its
    /// own reasons without scraping a localized hint. `--no-follow-tags` refuses a `push.followTags`
    /// the Repository may carry: Colofa never creates or pushes a tag, and a Push that quietly
    /// published one would be doing something the user never asked for.
    ///
    /// `--recurse-submodules=no` refuses the same kind of quiet expansion one level down. A
    /// `push.recurseSubmodules` of `on-demand` or `only` sends each changed submodule to a second
    /// remote the confirmation never named, which is one more external write than the user agreed
    /// to. Saying `no` also declines the `check` setting's refusal to push a superproject Commit
    /// whose submodule Commit is not on its own remote — deliberately, because Colofa's promise is
    /// that exactly the shown Ref travels to exactly the shown remote, not that it manages
    /// somebody's submodules.
    static let sharedOptions = ["--porcelain", "--no-follow-tags", "--recurse-submodules=no"]

    /// Creates the Branch on `remote` for the first time and records it as the Branch's upstream.
    ///
    /// `--set-upstream` is what makes the next Pull and Push ordinary operations, and it is applied
    /// by Git only once the remote has actually accepted the Ref — so a Publish the remote refused
    /// leaves no upstream pointing at a Branch that does not exist.
    static func publish(_ branch: String, to remote: String) -> [String] {
        ["push"] + sharedOptions + ["--set-upstream", "--", remote, refspec(branch, to: headRef(branch))]
    }

    /// Sends the Branch to the exact upstream `target` names.
    ///
    /// - Parameter lease: The object the remote must still hold, or `nil` for an ordinary Push.
    ///   It is the only way this file can produce a force at all, which is what makes a naked
    ///   force impossible rather than merely unusual.
    static func push(_ branch: String, to target: PushTarget, lease: String?) -> [String] {
        var arguments = ["push"] + sharedOptions
        if let lease {
            arguments.append("--force-with-lease=\(target.remoteRef):\(lease)")
        }
        arguments += ["--", target.remote, refspec(branch, to: target.remoteRef)]
        return arguments
    }

    /// Git's own name for the Repository a command is already running in.
    ///
    /// A perfectly ordinary configuration produces it — `git branch --track <new> <local>` sets
    /// `branch.<new>.remote` to this — and Git then reports the local Branch it names as that
    /// Branch's upstream. Named here so the one place that resolves a destination can recognize
    /// it rather than pushing into the Repository the user is looking at.
    static let localRemote = "."

    /// Reads every address one Push to `remote` would write to.
    ///
    /// `--push` asks the question a Push actually asks, because `remote.<name>.pushurl` overrides
    /// the fetch URL, and `--all` is what makes several of them visible: Git writes to every one
    /// of them in turn, and a question that reported only the first would hide the rest.
    ///
    /// `--` keeps the remote name out of Git's option parser, the same way every other command
    /// here does.
    static func destinationQuery(for remote: String) -> [String] {
        ["remote", "get-url", "--push", "--all", "--", remote]
    }

    /// The keys Git reads to decide where a Branch is pushed, in the order Git overrules them.
    ///
    /// `branch.<name>.pushRemote` overrides `remote.pushDefault`, which in turn overrides
    /// `branch.<name>.remote`. Colofa asks for each in that order and stops at the first answer
    /// rather than reproducing the rule; Git's own fallback to `origin` is deliberately not part
    /// of this, because choosing among the Repository's actual remotes is what Publish does next.
    static func remoteKeys(for branch: String) -> [String] {
        ["branch.\(branch).pushRemote", "remote.pushDefault", "branch.\(branch).remote"]
    }

    /// Reads one configured value, reporting nothing rather than failing when the key is unset.
    static func remoteQuery(_ key: String) -> [String] {
        ["config", "--null", "--get", key]
    }

    /// Reads where a Push of `branch` would go, from the Branch's own upstream configuration.
    ///
    /// The pattern is a literal Ref name, but `for-each-ref` also matches whatever lies below it,
    /// so the caller still has to pick the record whose Ref is exactly this Branch.
    static func upstreamQuery(for branch: String) -> [String] {
        [
            "for-each-ref",
            "--format=%(refname)%00%(upstream:remotename)%00%(upstream:remoteref)"
                + "%00%(upstream:short)%00%(upstream)",
            headRef(branch),
        ]
    }

    /// Reads what one Ref points at, reporting nothing rather than failing when there is no such
    /// Ref — which is how an upstream nobody has fetched yet answers.
    ///
    /// The Ref is one Git itself reported and always begins with `refs/`, so it can never be read
    /// back as an option; `--` is deliberately absent, because `rev-parse` reads everything after
    /// one as a path rather than as a Ref.
    static func objectIDQuery(of ref: String) -> [String] {
        ["rev-parse", "--verify", "--quiet", ref]
    }

    /// A Branch's own full Ref, which is what keeps a Push about a Branch rather than about a tag
    /// that happens to share its name.
    static func headRef(_ branch: String) -> String {
        "refs/heads/\(branch)"
    }

    private static func refspec(_ branch: String, to remoteRef: String) -> String {
        // No leading `+`, which is the refspec's own spelling of force. Force travels as a lease
        // or not at all.
        "\(headRef(branch)):\(remoteRef)"
    }
}
