////
//  FetchCommand.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The two commands Fetch runs, kept in one place so what Colofa adds to `git fetch` can be read
/// — and tested — without reading the Store.
///
/// A Fetch of one remote adds no option at all: the remote's own refspec, tag, and prune
/// configuration decides what it downloads, which is the point. An explicit Fetch Tags is the
/// one place that configuration is overruled, because there the user asked for tags rather than
/// for whatever policy the remote carries.
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

    /// Whether these arguments are the tag Fetch rather than one remote's ordinary Fetch.
    static func isTagFetch(_ arguments: [String]) -> Bool {
        arguments.contains(tagRefspec)
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
