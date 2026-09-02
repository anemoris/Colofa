////
//  FetchCommand.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The commands Fetch runs, kept in one place so what Colofa adds to `git fetch` can be read —
/// and tested — without reading the Store.
///
/// A Fetch of one remote adds no option at all: the remote's own refspec, tag, and prune
/// configuration decides what it downloads, which is the point. Fetch Tags and Fetch Remotes are
/// the two places that configuration is overruled, because there the user asked for a specific
/// kind of Ref rather than for whatever policy the remote carries.
nonisolated enum FetchCommand {

    /// Every tag, named as a refspec rather than inherited from the remote.
    ///
    /// Passing a refspec on the command line replaces the remote's configured `fetch` refspecs
    /// for this command only, so a configured `+refs/tags/*:refs/tags/*` cannot turn an explicit
    /// tag download into a force-update.
    static let tagRefspec = "refs/tags/*:refs/tags/*"

    /// One remote's Fetch, exactly as Git would run it by name.
    ///
    /// `--all` is deliberately absent. Colofa contacts the eligible remotes one at a time so a
    /// remote that fails can be named, and so the ones already refreshed stay refreshed.
    static func fetch(_ remote: String) -> [String] {
        ["fetch", "--", remote]
    }

    /// Every tag from one remote, added but never replaced and never removed.
    ///
    /// `--force` and `--prune-tags` are absent, but absence alone does not make that true: Git
    /// reads `fetch.prune` with `fetch.pruneTags` and the remote's own refspec whether or not an
    /// option was passed, and a Repository configured that way would have local-only tags pruned
    /// and same-name tags force-updated. So the refusal is spelled out rather than assumed — an
    /// explicit tag refspec without `+`, and prune refused in both of its forms. Git still
    /// refuses a same-name tag on its own, and Colofa keeps that refusal rather than overriding
    /// it.
    static func fetchTags(from remote: String) -> [String] {
        ["fetch", "--no-tags", "--no-prune", "--no-prune-tags", "--", remote, tagRefspec]
    }

    /// One remote's branches, named as a refspec rather than inherited from the remote.
    ///
    /// The destination is the conventional `refs/remotes/<remote>/*` rather than whatever the
    /// remote's own `fetch` refspecs name, and that is what makes the prune below safe to ask
    /// for: a refspec passed on the command line replaces the configured ones for this command
    /// only, so pruning can reach nothing outside this remote's own remote-tracking Branches.
    ///
    /// The cost is that a remote configured to write its branches somewhere else is reconciled
    /// here instead, and the refs its own configuration produced are left alone rather than
    /// removed. That is the safe direction to be wrong in: this command adds and removes only
    /// within the namespace it names, and it never deletes a ref it did not write.
    static func remoteBranchRefspec(of remote: String) -> String {
        "+refs/heads/*:refs/remotes/\(remote)/*"
    }

    /// One remote's branches, downloaded and reconciled: whatever the remote no longer has stops
    /// being a remote-tracking Branch here.
    ///
    /// `--prune` is the point of the command, and it is deliberately bounded rather than trusted.
    /// Git prunes within whichever refspecs are in force, so a Repository whose
    /// `remote.<name>.fetch` writes into `refs/tags/*` would have local-only tags deleted by a
    /// plain `--prune` — and `--no-prune-tags` does not stop it, because that option refuses only
    /// the tag refspec Git adds implicitly, not one the Repository configured. So the refspec is
    /// named here instead, which replaces the configured ones and leaves `refs/remotes/<remote>/*`
    /// as the only place a ref can be removed from. `--no-tags` and `--no-prune-tags` still spell
    /// out the refusal in both of its other forms rather than leaving it to be inferred from an
    /// option's absence.
    static func fetchRemotes(from remote: String) -> [String] {
        [
            "fetch", "--prune", "--no-tags", "--no-prune-tags",
            "--", remote, remoteBranchRefspec(of: remote),
        ]
    }

    /// Whether these arguments are the tag Fetch rather than one remote's ordinary Fetch.
    static func isTagFetch(_ arguments: [String]) -> Bool {
        arguments.contains(tagRefspec)
    }

    /// Whether these arguments are the Fetch Remotes rather than one remote's ordinary Fetch.
    static func isRemotesFetch(_ arguments: [String]) -> Bool {
        guard let remote = remote(of: arguments) else {
            return false
        }
        return arguments.contains(remoteBranchRefspec(of: remote))
    }

    /// The remote these arguments contact, which is the first thing after the `--` that keeps a
    /// remote name out of Git's option parser.
    static func remote(of arguments: [String]) -> String? {
        guard let separator = arguments.firstIndex(of: "--") else {
            return nil
        }
        let name = arguments.index(after: separator)
        return name < arguments.endIndex ? arguments[name] : nil
    }
}
